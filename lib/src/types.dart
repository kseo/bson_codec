// Copyright (c) 2016, Kwang Yul Seo. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bson_objectid/bson_objectid.dart';
import 'package:collection/collection.dart';

import './bson_reader.dart';
import './bson_writer.dart';
import './hex.dart';

const _bsonTypeNumber = 0x01;
const _bsonTypeString = 0x02;
const _bsonTypeObject = 0x03;
const _bsonTypeArray = 0x04;
const _bsonTypeBinary = 0x05;
const _bsonTypeUndefined = 0x06; // Deprecated
const _bsonTypeObjectId = 0x07;
const _bsonTypeBoolean = 0x08;
const _bsonTypeDateTime = 0x09;
const _bsonTypeNull = 0x0A;
const _bsonTypeRegExp = 0x0B;
const _bsonTypeDbPointer = 0x0C; // Deprecated
const _bsonTypeJavaScript = 0x0D;
const _bsonTypeSymbol = 0x0E;
const _bsonTypeJavaScriptWithScope = 0x0F;
const _bsonTypeInt32 = 0x10;
const _bsonTypeTimestamp = 0x11;
const _bsonTypeInt64 = 0x12;
const _bsonTypeDecimal128 = 0x13;
const _bsonTypeMinKey = 0xff;
const _bsonTypeMaxKey = 0x7f;

const bsonSubTypeGeneric = 0x00;
const bsonSubTypeFunction = 0x01;
const bsonSubTypeOldBinary = 0x02;
const bsonSubTypeOldUuid = 0x03;
const bsonSubTypeUuid = 0x04;
const bsonSubTypeMd5 = 0x05;
const bsonSubTypeUserDefined = 0x80;

Map<int, BsonCodec> _codecs = {
  _bsonTypeNumber: new BsonDoubleCodec(),
  _bsonTypeString: new BsonStringCodec(),
  _bsonTypeObject: new BsonObjectCodec(),
  _bsonTypeArray: new BsonArrayCodec(),
  _bsonTypeBinary: new BsonBinaryCodec(),
  _bsonTypeUndefined: new BsonUndefinedCodec(),
  _bsonTypeObjectId: new BsonObjectIdCodec(),
  _bsonTypeBoolean: new BsonBooleanCodec(),
  _bsonTypeDateTime: new BsonDateTimeCodec(),
  _bsonTypeNull: new BsonNullCodec(),
  _bsonTypeRegExp: new BsonRegExpCodec(),
  _bsonTypeDbPointer: new BsonDbPointerCodec(),
  _bsonTypeJavaScript: new BsonJavaScriptCodec(),
  _bsonTypeSymbol: new BsonStringCodec(),
  _bsonTypeJavaScriptWithScope: new BsonJavaScriptWithScopeCodec(),
  _bsonTypeInt32: new BsonInt32Codec(),
  _bsonTypeTimestamp: new BsonTimestampCodec(),
  _bsonTypeInt64: new BsonInt64Codec(),
  _bsonTypeDecimal128: new BsonDecimal128Codec(),
  _bsonTypeMinKey: new BsonMinKeyCodec(),
  _bsonTypeMaxKey: new BsonMaxKeyCodec()
};

List<int> bsonEncode(BsonValue value) {
  final writer = new BsonWriter(_byteLength(value));
  _codecs[value.typeByte].encode(writer, value);
  return writer.bytes;
}

BsonValue bsonDecode(List<int> bytes) {
  try {
    final reader = new BsonReader.from(bytes);
    return _codecs[_bsonTypeObject].decode(reader);
  } catch (e) {
    throw new FormatException('Invalid BSON');
  }
}

/// Base class for any BSON type.
abstract class BsonValue<T> {
  int get typeByte;

  T get value;
}

abstract class BsonCodec<T extends BsonValue> {
  T decode(BsonReader reader);

  void encode(BsonWriter writer, T value);

  int byteLength(T value);
}

class BsonArray implements BsonValue<List<BsonValue>> {
  @override
  int get typeByte => _bsonTypeArray;

  @override
  final List<BsonValue> value;

  BsonArray(List<BsonValue> value) : value = new List.unmodifiable(value);

  @override
  String toString() => value.toString();
}

class BsonArrayCodec implements BsonCodec<BsonArray> {
  @override
  void encode(BsonWriter writer, BsonArray array) {
    writer.writeInt32(byteLength(array));
    for (var i = 0; i < array.value.length; i++) {
      _packElement(i.toString(), array.value[i], writer);
    }
    writer.writeByte(0);
  }

  @override
  BsonArray decode(BsonReader reader) {
    List<BsonValue> list = [];
    int offset = reader.offset;
    int length = reader.readInt32();
    if (length < 5) {
      throw new FormatException('Invalid BSON', reader, reader.offset);
    }
    int typeByte = reader.readByte();
    int actualLength = 5;
    while (typeByte != 0 && actualLength < length) {
      final pair = _unpackElement(typeByte, reader);
      list.add(pair.value);
      typeByte = reader.readByte();
      actualLength = reader.offset - offset;
    }
    if (typeByte != 0 || actualLength != length) {
      throw new FormatException('Invalid BSON');
    }
    return new BsonArray(list);
  }

  @override
  int byteLength(BsonArray array) {
    int length = 0;
    for (var i = 0; i < array.value.length; i++) {
      length += _elementSize(i.toString(), array.value[i]);
    }
    return length + 1 + 4;
  }
}

class BsonObject implements BsonValue<Map<String, BsonValue>> {
  @override
  int get typeByte => _bsonTypeObject;

  @override
  final Map<String, BsonValue> value;

  BsonObject(Map<String, BsonValue> value)
      : value = new Map.unmodifiable(value);
}

class BsonObjectCodec implements BsonCodec<BsonObject> {
  @override
  void encode(BsonWriter writer, BsonObject object) {
    writer.writeInt32(byteLength(object));
    object.value.forEach((String key, BsonValue value) {
      _packElement(key, value, writer);
    });
    writer.writeByte(0);
  }

  @override
  BsonObject decode(BsonReader reader) {
    Map<String, BsonValue> map = {};
    int offset = reader.offset;
    int length = reader.readInt32();
    if (length < 5) {
      throw new FormatException('Invalid BSON', reader, reader.offset);
    }
    int typeByte = reader.readByte();
    int actualLength = 5;
    while (typeByte != 0 && actualLength < length) {
      final pair = _unpackElement(typeByte, reader);
      map[pair.name] = pair.value;
      typeByte = reader.readByte();
      actualLength = reader.offset - offset;
    }
    if (typeByte != 0 || actualLength != length) {
      throw new FormatException('Invalid BSON');
    }
    return new BsonObject(map);
  }

  @override
  int byteLength(BsonObject object) {
    int length = 0;
    object.value.forEach((String key, BsonValue value) {
      length += _elementSize(key, value);
    });
    return length + 1 + 4;
  }
}

/// A representation of the BSON Binary type.
///
/// Note that for performance reasons instances of this class are not immutable,
/// so care should be taken to only modify the underlying byte list if you know
/// what you're doing, or else make a defensive copy.
class BsonBinary implements BsonValue<BsonBinary> {
  @override
  int get typeByte => _bsonTypeBinary;

  @override
  BsonBinary get value => this;

  final int subType;

  final List<int> data;

  BsonBinary.from(this.data, [this.subType = bsonSubTypeGeneric]);

  @override
  bool operator ==(other) =>
      other is BsonBinary &&
      subType == other.subType &&
      new DeepCollectionEquality().equals(data, other.data);

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'BsonBinary(\'${toHexString(data)}\')';
}

class BsonBinaryCodec implements BsonCodec<BsonBinary> {
  @override
  void encode(BsonWriter writer, BsonBinary value) {
    int totalLength = value.data.length;

    bool isOldBinary = value.subType == bsonSubTypeOldBinary;
    if (isOldBinary) {
      totalLength += 4;
    }

    writer
      ..writeInt32(totalLength)
      ..writeByte(value.subType);
    // The structure of the binary data (the byte* array in the binary
    // non-terminal) must be an int32 followed by a (byte*).
    if (isOldBinary) {
      writer.writeInt32(totalLength - 4);
    }
    writer.writeFrom(value.data);
  }

  @override
  BsonBinary decode(BsonReader reader) {
    int totalLength = reader.readInt32();
    int subType = reader.readByte();
    int length = totalLength;
    if (subType == bsonSubTypeOldBinary) {
      length = reader.readInt32();
      if (length != totalLength - 4) {
        throw new FormatException('Binary length mismatch');
      }
    }
    Uint8List data = new Uint8List(length);
    reader.readInto(data);
    return new BsonBinary.from(data, subType);
  }

  @override
  int byteLength(BsonBinary value) {
    int length = value.data.length;
    if (value.subType == bsonSubTypeOldBinary) {
      length += 4;
    }
    return length + 4 + 1;
  }
}

class BsonBoolean implements BsonValue<bool> {
  @override
  int get typeByte => _bsonTypeBoolean;

  @override
  final bool value;

  BsonBoolean(this.value);
}

class BsonBooleanCodec implements BsonCodec<BsonBoolean> {
  @override
  void encode(BsonWriter writer, BsonBoolean value) {
    writer.writeByte(value.value ? 1 : 0);
  }

  @override
  BsonBoolean decode(BsonReader reader) {
    final byte = reader.readByte();
    return new BsonBoolean(byte == 1 ? true : false);
  }

  @override
  int byteLength(BsonBoolean value) => 1;
}

/// Represents the value associated with the BSON Undefined type.
/// All values of this type are identical. Note that this type has been
/// deprecated in the BSON specification.
@deprecated
class BsonUndefined implements BsonValue<BsonUndefined> {
  static BsonUndefined _instance = new BsonUndefined._();

  @override
  int get typeByte => _bsonTypeUndefined;

  @override
  BsonUndefined get value => this;

  factory BsonUndefined.singleton() => _instance;

  BsonUndefined._();

  @override
  String toString() => 'BsonUndefined';
}

class BsonUndefinedCodec implements BsonCodec<BsonUndefined> {
  @override
  void encode(BsonWriter writer, BsonUndefined value) {
    // no-op
  }

  @override
  BsonUndefined decode(BsonReader reader) => new BsonUndefined.singleton();

  @override
  int byteLength(BsonUndefined value) => 0;
}

/// A representation of the BSON Null type.
class BsonNull implements BsonValue<Null> {
  static BsonNull _instance = new BsonNull._();

  @override
  int get typeByte => _bsonTypeNull;

  @override
  Null get value => null;

  factory BsonNull.singleton() => _instance;

  BsonNull._();
}

class BsonNullCodec implements BsonCodec<BsonNull> {
  @override
  void encode(BsonWriter writer, BsonNull value) {
    // no-op
  }

  @override
  BsonNull decode(BsonReader reader) => new BsonNull.singleton();

  @override
  int byteLength(BsonNull value) => 0;
}

/// Represent the minimum key value regardless of the key's type.
class BsonMinKey implements BsonValue<BsonMinKey> {
  static BsonMinKey _instance = new BsonMinKey._();

  @override
  int get typeByte => _bsonTypeMinKey;

  @override
  BsonMinKey get value => this;

  factory BsonMinKey.singleton() => _instance;

  BsonMinKey._();

  @override
  String toString() => 'BsonMinKey';
}

class BsonMinKeyCodec implements BsonCodec<BsonMinKey> {
  @override
  void encode(BsonWriter writer, BsonMinKey value) {
    // no-op
  }

  @override
  BsonMinKey decode(BsonReader reader) => new BsonMinKey.singleton();

  @override
  int byteLength(BsonMinKey value) => 0;
}

/// Represent the maximum key value regardless of the key's type.
class BsonMaxKey implements BsonValue<BsonMaxKey> {
  static BsonMaxKey _instance = new BsonMaxKey._();

  @override
  int get typeByte => _bsonTypeMaxKey;

  @override
  BsonMaxKey get value => this;

  factory BsonMaxKey.singleton() => _instance;

  BsonMaxKey._();

  @override
  String toString() => 'BsonMaxKey';
}

class BsonMaxKeyCodec implements BsonCodec<BsonMaxKey> {
  @override
  void encode(BsonWriter writer, BsonMaxKey value) {
    // no-op
  }

  @override
  BsonMaxKey decode(BsonReader reader) => new BsonMaxKey.singleton();

  @override
  int byteLength(BsonMaxKey value) => 0;
}

class BsonInt32 implements BsonValue<int> {
  @override
  int get typeByte => _bsonTypeInt32;

  @override
  final int value;

  BsonInt32(this.value);
}

class BsonInt32Codec implements BsonCodec<BsonInt32> {
  @override
  void encode(BsonWriter writer, BsonInt32 value) {
    writer.writeInt32(value.value);
  }

  @override
  BsonInt32 decode(BsonReader reader) => new BsonInt32(reader.readInt32());

  @override
  int byteLength(BsonInt32 value) => 4;
}

class BsonInt64 implements BsonValue<int> {
  @override
  int get typeByte => _bsonTypeInt64;

  @override
  final int value;

  BsonInt64(this.value);
}

class BsonInt64Codec implements BsonCodec<BsonInt64> {
  @override
  void encode(BsonWriter writer, BsonInt64 value) {
    writer.writeInt64(value.value);
  }

  @override
  BsonInt64 decode(BsonReader reader) => new BsonInt64(reader.readInt64());

  @override
  int byteLength(BsonInt64 value) => 8;
}

class BsonDouble implements BsonValue<double> {
  @override
  int get typeByte => _bsonTypeNumber;

  @override
  final double value;

  BsonDouble(this.value);
}

class BsonDoubleCodec implements BsonCodec<BsonDouble> {
  @override
  void encode(BsonWriter writer, BsonDouble value) {
    writer.writeDouble(value.value);
  }

  @override
  BsonDouble decode(BsonReader reader) => new BsonDouble(reader.readDouble());

  @override
  int byteLength(BsonDouble value) => 8;
}

class BsonString implements BsonValue<String> {
  @override
  int get typeByte => _bsonTypeString;

  @override
  final String value;

  BsonString(String value) : value = value;
}

class BsonStringCodec implements BsonCodec<BsonString> {
  @override
  void encode(BsonWriter writer, BsonString string) =>
      writer.writeString(string.value);

  @override
  BsonString decode(BsonReader reader) => new BsonString(reader.readString());

  @override
  int byteLength(BsonString string) {
    List<int> utf8 = UTF8.encode(string.value);
    return utf8.length + 4 + 1;
  }
}

/// A representation of the BSON DateTime type.
class BsonDateTime implements BsonValue<DateTime> {
  @override
  int get typeByte => _bsonTypeDateTime;

  @override
  final DateTime value;

  BsonDateTime(this.value);
}

class BsonDateTimeCodec implements BsonCodec<BsonDateTime> {
  @override
  void encode(BsonWriter writer, BsonDateTime dateTime) {
    writer.writeInt64(dateTime.value.millisecondsSinceEpoch);
  }

  @override
  BsonDateTime decode(BsonReader reader) {
    int millisecondsSinceEpoch = reader.readInt64();
    return new BsonDateTime(new DateTime.fromMillisecondsSinceEpoch(
        millisecondsSinceEpoch,
        isUtc: true));
  }

  @override
  int byteLength(BsonDateTime value) => 8;
}

/// A value representing the BSON timestamp type.
class BsonTimestamp implements BsonValue<BsonTimestamp> {
  static int _currentIncrement = new Random.secure().nextInt(0xFFFFFFFF);
  static int _nextIncrement() => _currentIncrement++;

  @override
  int get typeByte => _bsonTypeTimestamp;

  @override
  BsonTimestamp get value => this;

  final int seconds;

  final int increment;

  BsonTimestamp([int seconds, int increment])
      : seconds = seconds ??
            (new DateTime.now().millisecondsSinceEpoch ~/ 1000).toInt(),
        increment = increment ?? _nextIncrement();

  @override
  int get hashCode {
    int result = seconds;
    result = 31 * result + increment;
    return result;
  }

  @override
  bool operator ==(other) =>
      other is BsonTimestamp &&
      seconds == other.seconds &&
      increment == other.increment;

  @override
  String toString() => 'BsonTimestamp($seconds, $increment)';
}

class BsonTimestampCodec implements BsonCodec<BsonTimestamp> {
  @override
  void encode(BsonWriter writer, BsonTimestamp timestamp) {
    writer..writeInt32(timestamp.increment)..writeInt32(timestamp.seconds);
  }

  @override
  BsonTimestamp decode(BsonReader reader) {
    int increment = reader.readInt32();
    int seconds = reader.readInt32();
    return new BsonTimestamp(seconds, increment);
  }

  @override
  int byteLength(BsonTimestamp value) => 8;
}

/// A representation of the BSON ObjectId type.
class BsonObjectId implements BsonValue<ObjectId> {
  @override
  int get typeByte => _bsonTypeObjectId;

  @override
  final ObjectId value;

  /// Creates a new object id.
  BsonObjectId([ObjectId id]) : value = id == null ? new ObjectId() : id;
}

class BsonObjectIdCodec implements BsonCodec<BsonObjectId> {
  @override
  void encode(BsonWriter writer, BsonObjectId id) =>
      writer.writeObjectId(id.value);

  @override
  BsonObjectId decode(BsonReader reader) =>
      new BsonObjectId(reader.readObjectId());

  @override
  int byteLength(BsonObjectId value) => 12;
}

/// A holder class for a BSON regular expression, so that we can delay
/// compiling into a Pattern until necessary.
class BsonRegExp implements BsonValue<BsonRegExp> {
  @override
  int get typeByte => _bsonTypeRegExp;

  /// The regex pattern.
  final String pattern;

  /// The options for the regular expression.
  final String options;

  @override
  BsonRegExp get value => this;

  BsonRegExp(this.pattern, this.options);

  @override
  int get hashCode {
    int result = pattern.hashCode;
    result = 31 * result + options.hashCode;
    return result;
  }

  @override
  bool operator ==(other) =>
      other is BsonRegExp &&
      pattern == other.pattern &&
      options == other.options;
}

class BsonRegExpCodec implements BsonCodec<BsonRegExp> {
  @override
  void encode(BsonWriter writer, BsonRegExp value) {
    new _CString(value.pattern).pack(writer);
    new _CString(value.options).pack(writer);
  }

  @override
  BsonRegExp decode(BsonReader reader) {
    final pattern = new _CString.unpack(reader);
    final options = new _CString.unpack(reader);
    return new BsonRegExp(pattern.value, options.value);
  }

  @override
  int byteLength(BsonRegExp value) {
    final pattern = new _CString(value.pattern);
    final options = new _CString(value.options);
    return pattern.byteLength + options.byteLength;
  }
}

/// For using the JavaScript Code type.
class BsonJavaScript implements BsonValue<BsonJavaScript> {
  final String code;

  @override
  int get typeByte => _bsonTypeJavaScript;

  @override
  BsonJavaScript get value => this;

  BsonJavaScript(this.code);

  @override
  int get hashCode => code.hashCode;

  @override
  bool operator ==(other) => other is BsonJavaScript && code == other.code;

  @override
  String toString() => 'BsonJavaScript(\'$code\')';
}

class BsonJavaScriptCodec implements BsonCodec<BsonJavaScript> {
  @override
  void encode(BsonWriter writer, BsonJavaScript javaScript) {
    writer.writeString(javaScript.code);
  }

  @override
  BsonJavaScript decode(BsonReader reader) {
    final code = reader.readString();
    return new BsonJavaScript(code);
  }

  @override
  int byteLength(BsonJavaScript javaScript) =>
      _byteLength(new BsonString(javaScript.code));
}

/// A representation of the JavaScript Code with Scope BSON type.
class BsonJavaScriptWithScope implements BsonValue<BsonJavaScriptWithScope> {
  @override
  int get typeByte => _bsonTypeJavaScriptWithScope;

  @override
  BsonJavaScriptWithScope get value => this;
}

class BsonJavaScriptWithScopeCodec
    implements BsonCodec<BsonJavaScriptWithScope> {
  @override
  void encode(BsonWriter writer, BsonJavaScriptWithScope value) {
    throw new UnimplementedError();
  }

  @override
  BsonJavaScriptWithScope decode(BsonReader reader) {
    throw new UnimplementedError();
  }

  @override
  int byteLength(BsonJavaScriptWithScope value) {
    throw new UnimplementedError();
  }
}

/// Holder for a BSON type DBPointer(0x0c).
/// It's deprecated in BSON Specification and present here because of
/// compatibility reasons.
@deprecated
class BsonDbPointer implements BsonValue<BsonDbPointer> {
  final String namespace;

  final ObjectId id;

  @override
  int get typeByte => _bsonTypeDbPointer;

  @override
  BsonDbPointer get value => this;

  BsonDbPointer(this.namespace, this.id);

  @override
  int get hashCode {
    int result = namespace.hashCode;
    result = 31 * result + id.hashCode;
    return result;
  }

  @override
  bool operator ==(other) =>
      other is BsonDbPointer && namespace == other.namespace && id == other.id;

  @override
  String toString() => 'BsonDbPointer($namespace, $id)';
}

class BsonDbPointerCodec implements BsonCodec<BsonDbPointer> {
  @override
  void encode(BsonWriter writer, BsonDbPointer dbPointer) {
    writer.writeString(dbPointer.namespace);
    writer.writeObjectId(dbPointer.id);
  }

  @override
  BsonDbPointer decode(BsonReader reader) {
    final namespace = reader.readString();
    final id = reader.readObjectId();
    return new BsonDbPointer(namespace, id);
  }

  @override
  int byteLength(BsonDbPointer dbPointer) {
    final namespace = new BsonString(dbPointer.namespace);
    return _byteLength(namespace) + 12;
  }
}

/// A representation of a 128-bit decimal.
class BsonDecimal128 implements BsonValue<BsonDecimal128> {
  @override
  int get typeByte => _bsonTypeDecimal128;

  @override
  BsonDecimal128 get value => this;
}

class BsonDecimal128Codec implements BsonCodec<BsonDecimal128> {
  @override
  void encode(BsonWriter writer, BsonDecimal128 value) {
    throw new UnimplementedError();
  }

  @override
  BsonDecimal128 decode(BsonReader reader) {
    throw new UnimplementedError();
  }

  @override
  int byteLength(BsonDecimal128 value) {
    throw new UnimplementedError();
  }
}

int _byteLength(BsonValue value) => _codecs[value.typeByte].byteLength(value);

int _elementSize(String name, BsonValue value) {
  final cstring = new _CString(name);
  return 1 + cstring.byteLength + _byteLength(value);
}

void _packElement(String name, BsonValue value, BsonWriter writer) {
  writer.writeByte(value.typeByte);

  final cstring = new _CString(name);
  cstring.pack(writer);

  _codecs[value.typeByte].encode(writer, value);
}

class _ElementPair {
  final String name;
  final BsonValue value;

  _ElementPair(this.name, this.value);
}

_ElementPair _unpackElement(int typeByte, BsonReader reader) {
  final name = new _CString.unpack(reader).value;
  if (typeByte == 0) throw new Error();

  BsonValue value = _codecs[typeByte].decode(reader);
  return new _ElementPair(name, value);
}

class _CString {
  final List<int> _utf8Data;

  int get byteLength => _utf8Data.length + 1;

  final String value;

  _CString(String value)
      : _utf8Data = UTF8.encode(value),
        value = value;

  _CString.fromCharCodes(List<int> codeUnits)
      : _utf8Data = codeUnits,
        value = UTF8.decode(codeUnits);

  factory _CString.unpack(BsonReader reader) {
    List<int> codeUnits = [];
    var byte = reader.readByte();
    while (byte != 0) {
      codeUnits.add(byte);
      byte = reader.readByte();
    }
    return new _CString.fromCharCodes(codeUnits);
  }

  void pack(BsonWriter writer) {
    writer
      ..writeFrom(_utf8Data)
      ..writeByte(0);
  }
}
