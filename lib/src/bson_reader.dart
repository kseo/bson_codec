// Copyright (c) 2016, Kwang Yul Seo. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:bson_objectid/bson_objectid.dart';

abstract class BsonReader {
  int get offset;

  int readByte();
  int readInt32();
  int readInt64();
  double readDouble();
  void readInto(List<int> buffer);
  String readString();
  ObjectId readObjectId();

  factory BsonReader.from(List<int> from) =>
      new _BsonReader(new Uint8List.fromList(from));
}

class _BsonReader implements BsonReader {
  final Uint8List _list;

  final ByteData _data;

  int _offset;

  @override
  int get offset => _offset;

  Uint8List get bytes => _list;

  _BsonReader(Uint8List list)
      : _list = list,
        _data = new ByteData.view(list.buffer),
        _offset = 0;

  @override
  int readByte() => _list[_offset++];

  @override
  int readInt32() => _readInt(4);

  @override
  int readInt64() => _readInt(8);

  @override
  double readDouble() {
    final value = _data.getFloat64(_offset, Endianness.LITTLE_ENDIAN);
    _offset += 8;
    return value;
  }

  @override
  void readInto(List<int> buffer) {
    buffer.setRange(0, buffer.length, _list, _offset);
    _offset += buffer.length;
  }

  int _readInt(int numOfBytes) {
    var value;
    switch (numOfBytes) {
      case 4:
        value = _data.getInt32(_offset, Endianness.LITTLE_ENDIAN);
        break;
      case 8:
        value = _data.getInt64(_offset, Endianness.LITTLE_ENDIAN);
        break;
      default:
        throw new UnsupportedError('readInt($numOfBytes)');
    }
    _offset += numOfBytes;
    return value;
  }

  @override
  String readString() {
    int length = readInt32() - 1;
    Uint8List codeUnits = new Uint8List(length);
    readInto(codeUnits);
    int terminator = readByte();
    if (terminator != 0) {
      throw new FormatException('Invalid BSON', this, _offset);
    }
    return UTF8.decode(codeUnits);
  }

  @override
  ObjectId readObjectId() {
    List<int> bytes = new List<int>(12);
    readInto(bytes);
    return new ObjectId.fromBytes(bytes);
  }

}
