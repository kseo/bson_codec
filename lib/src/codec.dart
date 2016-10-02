// Copyright (c) 2016, Kwang Yul Seo. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:bson_objectid/bson_objectid.dart';

import './types.dart';

/// An instance of the default implementation of the [BsonCodec].
///
/// This instance provides a convenient access to the most common BSON use cases.
const BSON = const BsonCodec();

typedef _ToEncodable(var o);
typedef _Reviver(var key, var value);

/// A [BsonCodec] encodes BSON objects to bytes and decodes bytes to
/// BSON objects.
class BsonCodec extends Codec<Object, List<int>> {
  final _Reviver _reviver;
  final _ToEncodable _toEncodable;

  /// Creates a `BsonCodec` with the given reviver and encoding function.
  ///
  /// The [reviver] function is called during decoding. It is invoked once for
  /// each object or list property that has been parsed.
  /// The `key` argument is either the integer list index for a list property,
  /// the string map key for object properties, or `null` for the final result.
  ///
  /// If [reviver] is omitted, it defaults to returning the value argument.
  ///
  /// The [toEncodable] function is used during encoding. It is invoked for
  /// values that are not directly encodable to a string (a value that is not a
  /// number, boolean, string, null, list or a map with string keys). The
  /// function must return an object that is directly encodable. The elements of
  /// a returned list and values of a returned map do not need to be directly
  /// encodable, and if they aren't, `toEncodable` will be used on them as well.
  /// Please notice that it is possible to cause an infinite recursive regress
  /// in this way, by effectively creating an infinite data structure through
  /// repeated call to `toEncodable`.
  ///
  /// If [toEncodable] is omitted, it defaults to a function that returns the
  /// result of calling `.toBson()` on the unencodable object.
  const BsonCodec({reviver(var key, var value), toEncodable(var object)})
      : _reviver = reviver,
        _toEncodable = toEncodable;

  /// Creates a `BsonCodec` with the given reviver.
  ///
  /// The [reviver] function is called once for each object or list property
  /// that has been parsed during decoding. The `key` argument is either the
  /// integer list index for a list property, the string map key for object
  ///properties, or `null` for the final result.
  BsonCodec.withReviver(reviver(var key, var value)) : this(reviver: reviver);

  /**
   * Parses the string and returns the resulting Bson object.
   *
   * The optional [reviver] function is called once for each object or list
   * property that has been parsed during decoding. The `key` argument is either
   * the integer list index for a list property, the string map key for object
   * properties, or `null` for the final result.
   *
   * The default [reviver] (when not provided) is the identity function.
   */
  dynamic decode(List<int> source, {reviver(var key, var value)}) {
    if (reviver == null) reviver = _reviver;
    if (reviver == null) return decoder.convert(source);
    return new BsonDecoder(reviver).convert(source);
  }

  /**
   * Converts [value] to a JSON string.
   *
   * If value contains objects that are not directly encodable to a JSON
   * string (a value that is not a number, boolean, string, null, list or a map
   * with string keys), the [toEncodable] function is used to convert it to an
   * object that must be directly encodable.
   *
   * If [toEncodable] is omitted, it defaults to a function that returns the
   * result of calling `.toBson()` on the unencodable object.
   */
  List<int> encode(Object value, {toEncodable(object)}) {
    if (toEncodable == null) toEncodable = _toEncodable;
    if (toEncodable == null) return encoder.convert(value);
    return new BsonEncoder(toEncodable).convert(value);
  }

  BsonEncoder get encoder {
    if (_toEncodable == null) return const BsonEncoder();
    return new BsonEncoder(_toEncodable);
  }

  BsonDecoder get decoder {
    if (_reviver == null) return const BsonDecoder();
    return new BsonDecoder(_reviver);
  }
}

/// This class converts BSON objects to bytes.
class BsonEncoder extends Converter<Object, List<int>> {
  /// Function called on non-encodable objects to return a replacement
  /// encodable object that will be encoded in the orignal's place.
  final _ToEncodable _toEncodable;

  /// Creates a BSON encoder.
  ///
  /// The BSON encoder handles numbers, strings, booleans, null, lists and
  /// maps directly.
  ///
  /// Any other object is attempted converted by [toEncodable] to an
  /// object that is of one of the convertible types.
  ///
  /// If [toEncodable] is omitted, it defaults to calling `.toBson()` on
  /// the object.
  const BsonEncoder([toEncodable(nonSerializable)])
      : this._toEncodable = toEncodable;

  /// Converts [object] to a BSON bytes.
  ///
  /// Directly serializable values are [int], [double], [String], [DateTime],
  /// [ObjectId], [bool], and [Null], as well as some [List] and [Map] values.
  /// For [List], the elements must all be serializable. For [Map], the keys
  /// must be [String] and the values must be serializable.
  ///
  /// If a value of any other type is attempted to be serialized, the
  /// `toEncodable` function provided in the constructor is called with the value
  /// as argument. The result, which must be a directly serializable value, is
  /// serialized instead of the original value.
  ///
  /// If the conversion throws, or returns a value that is not directly
  /// serializable, a [BsonUnsupportedObjectError] exception is thrown.
  /// If the call throws, the error is caught and stored in the
  /// [BsonUnsupportedObjectError]'s [:cause:] field.
  ///
  /// If a [List] or [Map] contains a reference to itself, directly or through
  /// other lists or maps, it cannot be serialized and a [BsonCyclicError] is
  /// thrown.
  ///
  /// [object] should not change during serialization.
  ///
  /// If an object is serialized more than once, [convert] may cache the text
  /// for it. In other words, if the content of an object changes after it is
  /// first serialized, the new values may not be reflected in the result.
  @override
  List<int> convert(Object input) {
    BsonValue value = new _ToBson(_toEncodable).convertObject(input);
    if (value is! BsonObject) {
      throw new BsonUnsupportedObjectError(input);
    }
    return bsonEncode(value);
  }
}

/// This class parses BSON bytes and builds the corresponding objects.
class BsonDecoder extends Converter<List<int>, Object> {
  final _Reviver _reviver;

  /// Constructs a new BsonDecoder.
  ///
  /// The [reviver] may be `null`.
  const BsonDecoder([reviver(var key, var value)]) : this._reviver = reviver;

  /// Converts the given BSON-bytes [input] to its corresponding object.
  ///
  /// Parsed BSON values are of the types [bool], [Null],  [int], [double],
  /// [String], [DateTime], [ObjectId], [BsonUndefined], [BsonBinary],
  /// [BsonDbPointer], [BsonDecimal128], [BsonJavaScript], [BsonJavaScriptWithScope],
  /// [BsonMinKey], [BsonMaxKey], [BsonTimestamp], [List]s of parsed BSON values
  /// or [Map]s from [String] to parsed BSON values.
  ///
  /// If `this` was initialized with a reviver, then the parsing operation
  /// invokes the reviver on every object or list property that has been parsed.
  /// The arguments are the property name ([String]) or list index ([int]), and
  /// the value is the parsed value. The return value of the reviver is used as
  /// the value of that property instead the parsed value.
  ///
  /// Throws [FormatException] if the input is not valid BSON binary.
  dynamic convert(List<int> input) {
    final bsonObject = bsonDecode(input);
    return new _FromBson(_reviver).convertValue(bsonObject);
  }
}

// Implementation of encoder/serializer.
dynamic _defaultToEncodable(dynamic object) => object.toBson();

class _ToBson {
  /// List of objects currently being traversed. Used to detect cycles.
  final List _seen = new List();

  /// Function called for each un-encodable object encountered.
  final _ToEncodable _toEncodable;

  _ToBson(toEncodable(o)) : _toEncodable = toEncodable ?? _defaultToEncodable;

  /// Check if an encountered object is already being traversed.
  ///
  /// Records the object if it isn't already seen. Should have a matching call to
  /// [_removeSeen] when the object is no longer being traversed.
  void _checkCycle(object) {
    for (int i = 0; i < _seen.length; i++) {
      if (identical(object, _seen[i])) {
        throw new BsonCyclicError(object);
      }
    }
    _seen.add(object);
  }

  /// Remove [object] from the list of currently traversed objects.
  ///
  /// Should be called in the opposite order of the matching [_checkCycle]
  /// calls.
  void _removeSeen(object) {
    assert(!_seen.isEmpty);
    assert(identical(_seen.last, object));
    _seen.removeLast();
  }

  BsonValue convertObject(object) {
    // Tries converting object directly. If it's not a simple value, List or
    // Map, call toBson() to get a custom representation and try serializing
    // that.
    var value = _convertBsonValue(object);
    if (value != null) {
      return value;
    }
    _checkCycle(object);
    try {
      var customBson = _toEncodable(object);
      value = _convertBsonValue(customBson);
      if (value == null) {
        throw new BsonUnsupportedObjectError(object);
      }
      _removeSeen(object);
      return value;
    } catch (e) {
      throw new BsonUnsupportedObjectError(object, cause: e);
    }
  }

  BsonValue _convertBsonValue(object) {
    if (object is BsonValue) {
      return object;
    } else if (object is int) {
      if (object.bitLength < 32) {
        return new BsonInt32(object);
      } else if (object.bitLength < 64) {
        return new BsonInt64(object);
      }
      throw new BsonOverflowError(object);
    } else if (object is num) {
      return new BsonDouble(object);
    } else if (object is bool) {
      return new BsonBoolean(object);
    } else if (object == null) {
      return new BsonNull.singleton();
    } else if (object is String) {
      return new BsonString(object);
    } else if (object is DateTime) {
      return new BsonDateTime(object);
    } else if (object is ObjectId) {
      return new BsonObjectId(object);
    } else if (object is List) {
      _checkCycle(object);
      final value = _convertList(object);
      _removeSeen(object);
      return value;
    } else if (object is Map) {
      _checkCycle(object);
      // writeMap can fail if keys are not all strings.
      final value = _convertMap(object);
      _removeSeen(object);
      return value;
    } else {
      return null;
    }
  }

  BsonArray _convertList(List list) =>
      new BsonArray(list.map(convertObject).toList(growable: false));

  BsonObject _convertMap(Map map) {
    bool allStringKeys = true;
    Map<String, BsonValue> object = {};
    map.forEach((key, value) {
      if (key is! String) {
        allStringKeys = false;
      }
      object[key] = convertObject(value);
    });
    if (!allStringKeys) return null;
    return new BsonObject(object);
  }
}

class _FromBson {
  final _Reviver _reviver;

  _FromBson([reviver(var key, var value)]) : this._reviver = reviver;

  dynamic convertValue(BsonValue value) {
    var object = _convertBsonValue(value);
    if (_reviver != null) {
      object = _reviver(null, object);
    }
    return object;
  }

  dynamic _convertBsonValue(BsonValue value) {
    if (value is BsonArray) {
      return _convertArray(value);
    } else if (value is BsonObject) {
      return _convertObject(value);
    } else {
      return value.value;
    }
  }

  dynamic _convertArray(BsonArray array) {
    List list = [];
    for (var i = 0; i < array.value.length; i++) {
      var value = _convertBsonValue(array.value[i]);
      if (_reviver != null) {
        value = _reviver(i, value);
      }
      list.add(value);
    }
    return list;
  }

  dynamic _convertObject(BsonObject object) {
    Map map = {};
    object.value.forEach((key, value) {
      value = _convertBsonValue(value);
      if (_reviver != null) {
        value = _reviver(key, value);
      }
      map[key] = value;
    });
    return map;
  }
}

/// Error thrown by BSON serialization if an object cannot be serialized.
///
/// The [unsupportedObject] field holds that object that failed to be serialized.
///
/// If an object isn't directly serializable, the serializer calls the `toBson`
/// method on the object. If that call fails, the error will be stored in the
/// [cause] field. If the call returns an object that isn't directly
/// serializable, the [cause] is null.
class BsonUnsupportedObjectError extends Error {
  /// The object that could not be serialized.
  final unsupportedObject;

  /// The exception thrown when trying to convert the object.
  final cause;

  BsonUnsupportedObjectError(this.unsupportedObject, {this.cause});

  String toString() {
    if (cause != null) {
      return "Converting object to an encodable object failed.";
    } else {
      return "Converting object did not return an encodable object.";
    }
  }
}

/// Reports that an object could not be serialized due to cyclic references.
///
/// An object that references itself cannot be serialized by [serialize].
/// When the cycle is detected, a [BsonCyclicError] is thrown.
class BsonCyclicError extends BsonUnsupportedObjectError {
  /** The first object that was detected as part of a cycle. */
  BsonCyclicError(Object object) : super(object);
  String toString() => "Cyclic error in JSON stringify";
}

/// Reports that an int could not be serialized due to overflow error.
class BsonOverflowError extends BsonUnsupportedObjectError {
  BsonOverflowError(Object object) : super(object);
  String toString() => "Overflow error";
}
