// Copyright (c) 2016, Kwang Yul Seo. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:bson_codec/bson_codec.dart';
import 'package:test/test.dart';

class TestInt {
  final int value;

  TestInt(this.value);

  int toBson() => value;
}

class TestDouble {
  final double value;

  TestDouble(this.value);
}

class TestItem {
  final dynamic object;
  final List<int> data;

  TestItem(this.object, String data) : data = data.codeUnits;
}

List<TestItem> sampleItems = [
  new TestItem({'hello': 'world'},
      '\x16\x00\x00\x00\x02hello\x00\x06\x00\x00\x00world\x00\x00'),
  new TestItem(
      {
        'BSON': ['awesome', 5.05, 1986]
      },
      '1\x00\x00\x00\x04BSON\x00&\x00\x00\x00\x020\x00\x08\x00\x00\x00'
      'awesome\x00\x011\x00333333\x14@\x102\x00\xc2\x07\x00\x00\x00\x00')
];

const Matcher isBsonUnsupportedObjectError =
    const _BsonUnsupportedObjectError();

class _BsonUnsupportedObjectError extends TypeMatcher {
  const _BsonUnsupportedObjectError() : super("BsonUnsupportedObjectError");
  bool matches(item, Map matchState) => item is BsonUnsupportedObjectError;
}

const Matcher throwsBsonUnsupportedObjectError =
    const Throws(isBsonUnsupportedObjectError);

encodeExpect(o, String s) => expect(BSON.encode(o), s.codeUnits);
encodeThrows(o) =>
    expect(() => BSON.encode(o), throwsBsonUnsupportedObjectError);

decodeExpect(String s, o) => expect(BSON.decode(s.codeUnits), o);
decodeThrows(String s) =>
    expect(() => BSON.decode(s.codeUnits), throwsFormatException);

void main() {
  group('BSON', () {
    test('should invoke toEncodable if the value is not serializable', () {
      final map = {'a': new TestDouble(5.0)};
      final bytes = BSON.encode(map, toEncodable: (d) => d.value);
      expect(BSON.decode(bytes)['a'], 5.0);
    });

    test('should invoke .toBson() if toEncodable is not provided', () {
      final map = {'a': new TestInt(5)};
      final bytes = BSON.encode(map);
      expect(BSON.decode(bytes)['a'], 5);
    });

    test('should throw an error otherwise', () {
      final map = {'a': new Object()};
      expect(() => BSON.encode(map), throws);
    });

    test('should throw an error if there is a cycle', () {
      final list = [new Object(), 2, 3];
      final map = {'a': list};
      expect(() => BSON.encode(map, toEncodable: (d) => list), throws);
    });

    test('should invoke reviver on every object or list property', () {
      final map = {'a': 1, 'b': 2};
      final root = BSON.decode(BSON.encode(map),
          reviver: (key, value) => key == 'b' ? value + 1 : value);
      expect(root['a'], 1);
      expect(root['b'], 3);
    });

    // Samples from bsonspec.org
    test('should encode and decode sample items correctly', () {
      for (final item in sampleItems) {
        expect(BSON.encode(item.object), item.data);
        expect(BSON.decode(item.data), item.object);
      }
    });

    test('should encode and decode', () {
      encodeAndDecode(o) {
        expect(BSON.decode(BSON.encode(o)), o);
      }

      encodeAndDecode({});
      encodeAndDecode({'null': null});
      encodeAndDecode({'boolean': true});
      encodeAndDecode({'boolean': false});
      encodeAndDecode({'int32': 10});
      encodeAndDecode({'int64': 9223372036854775807});
      encodeAndDecode({'double': 0.0013109});
      encodeAndDecode({'double': 10000000000.0});
      encodeAndDecode({'string': 'hello'});
      encodeAndDecode({
        "array": [1, true, 3.8, 'world']
      });
      encodeAndDecode({
        'object': {'test': 'something'}
      });
      encodeAndDecode({'binary': new BsonBinary.from(UTF8.encode('test'), 2)});
      encodeAndDecode(
          {'binary': new BsonBinary.from(UTF8.encode('test'), 100)});
      encodeAndDecode({'timestamp': new BsonTimestamp(1, 2)});
      encodeAndDecode({'minkey': new BsonMinKey.singleton()});
      encodeAndDecode({'maxkey': new BsonMaxKey.singleton()});
      encodeAndDecode({'undefined': new BsonUndefined.singleton()});
      encodeAndDecode(
          {'javascript': new BsonJavaScript('function() { return true; }')});
    });

    test('should decode', () {
      decodeExpect(
          '\x1B\x00\x00\x00\x0E\x74\x65\x73\x74\x00\x0C'
          '\x00\x00\x00\x68\x65\x6C\x6C\x6F\x20\x77\x6F'
          '\x72\x6C\x64\x00\x00',
          {'test': 'hello world'});
    });

    test('should throw an error if int is too large', () {
      const longMaxValue = 9223372036854775807;
      const longMinValue = -9223372036854775808;
      encodeThrows({'int': longMaxValue + 1});
      encodeThrows({'int': longMinValue - 1});
    });

    test('should throw an error if data is invalid', () {
      // Invalid object size (not enough bytes in document for even
      // an object size of first object.
      decodeThrows('\x1B');

      // An object size that's too small to even include the object size,
      // but is correctly encoded, along with a correct EOO (and no data).
      decodeThrows('\x01\x00\x00\x00\x00');

      // One object, but with object size listed smaller than it is in the
      // data.
      decodeThrows('\x1A\x00\x00\x00\x0E\x74\x65\x73\x74'
          '\x00\x0C\x00\x00\x00\x68\x65\x6C\x6C'
          '\x6f\x20\x77\x6F\x72\x6C\x64\x00');

      // One object, missing the EOO at the end.
      decodeThrows('\x1B\x00\x00\x00\x0E\x74\x65\x73\x74'
          '\x00\x0C\x00\x00\x00\x68\x65\x6C\x6C'
          '\x6f\x20\x77\x6F\x72\x6C\x64\x00');

      // One object, sized correctly, with a spot for an EOO, but the EOO
      // isn't 0x00.
      decodeThrows('\x1B\x00\x00\x00\x0E\x74\x65\x73\x74'
          '\x00\x0C\x00\x00\x00\x68\x65\x6C\x6C'
          '\x6f\x20\x77\x6F\x72\x6C\x64\x00\xFF');
    });

    test('should decode timestamp', () {
      decodeExpect(
          '\x13\x00\x00\x00\x11\x74\x65\x73\x74\x00\x14'
          '\x00\x00\x00\x04\x00\x00\x00\x00',
          {'test': new BsonTimestamp(4, 20)});
    });

    test('should encode', () {
      encodeThrows(100);
      encodeThrows('hello');
      encodeThrows(null);
      encodeThrows([]);

      encodeExpect({}, '\x05\x00\x00\x00\x00');
      encodeExpect(
          {'test': 'hello world'},
          '\x1B\x00\x00\x00\x02\x74\x65\x73\x74\x00\x0C\x00'
          '\x00\x00\x68\x65\x6C\x6C\x6F\x20\x77\x6F\x72\x6C'
          '\x64\x00\x00');
      encodeExpect(
          {'mike': 100},
          '\x0F\x00\x00\x00\x10\x6D\x69\x6B\x65\x00\x64\x00'
          '\x00\x00\x00');
      encodeExpect(
          {'hello': 1.5},
          '\x14\x00\x00\x00\x01\x68\x65\x6C\x6C\x6F\x00\x00'
          '\x00\x00\x00\x00\x00\xF8\x3F\x00');
      encodeExpect(
          {'true': true}, '\x0C\x00\x00\x00\x08\x74\x72\x75\x65\x00\x01\x00');
      encodeExpect(
          {'false': false},
          '\x0D\x00\x00\x00\x08\x66\x61\x6C\x73\x65\x00\x00'
          '\x00');
      encodeExpect(
          {'empty': []},
          '\x11\x00\x00\x00\x04\x65\x6D\x70\x74\x79\x00\x05'
          '\x00\x00\x00\x00\x00');
      encodeExpect(
          {'none': {}},
          '\x10\x00\x00\x00\x03\x6E\x6F\x6E\x65\x00\x05\x00'
          '\x00\x00\x00\x00');
      encodeExpect(
          {
            'test': new BsonBinary.from(UTF8.encode('test'), bsonSubTypeGeneric)
          },
          '\x14\x00\x00\x00\x05\x74\x65\x73\x74\x00\x04\x00'
          '\x00\x00\x00\x74\x65\x73\x74\x00');
      encodeExpect(
          {
            'test':
                new BsonBinary.from(UTF8.encode('test'), bsonSubTypeOldBinary)
          },
          '\x18\x00\x00\x00\x05\x74\x65\x73\x74\x00\x08\x00'
          '\x00\x00\x02\x04\x00\x00\x00\x74\x65\x73\x74\x00');
      encodeExpect(
          {
            'test': new BsonBinary.from(
                UTF8.encode('test'), bsonSubTypeUserDefined)
          },
          '\x14\x00\x00\x00\x05\x74\x65\x73\x74\x00\x04\x00'
          '\x00\x00\x80\x74\x65\x73\x74\x00');
      encodeExpect(
          {'test': null}, '\x0B\x00\x00\x00\x0A\x74\x65\x73\x74\x00\x00');
      encodeExpect(
          {'date': new DateTime.utc(2007, 1, 8, 0, 30, 11)},
          '\x13\x00\x00\x00\x09\x64\x61\x74\x65\x00\x38\xBE'
          '\x1C\xFF\x0F\x01\x00\x00\x00');
      encodeExpect(
          {'regex': new BsonRegExp(r'a*b', 'i')},
          '\x12\x00\x00\x00\x0B\x72\x65\x67\x65\x78\x00\x61'
          '\x2A\x62\x00\x69\x00\x00');
      encodeExpect(
          {'\$where': new BsonJavaScript('test')},
          '\x16\x00\x00\x00\r\$where\x00\x05\x00\x00\x00test'
          '\x00\x00');
      final a = new ObjectId.fromHexString('000102030405060708090A0B');
      encodeExpect(
          {'oid': a},
          '\x16\x00\x00\x00\x07\x6F\x69\x64\x00\x00\x01\x02'
          '\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x00');
    });
  });
}
