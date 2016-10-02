// Copyright (c) 2016, Kwang Yul Seo. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:bson_objectid/bson_objectid.dart';

abstract class BsonWriter {
  void writeDouble(double value);
  void writeByte(int value);
  void writeInt32(int value);
  void writeInt64(int value);
  void writeFrom(List<int> buffer);
  void writeString(String string);
  void writeObjectId(ObjectId id);

  factory BsonWriter(int length) => new _BsonWriter(new Uint8List(length));
}

class _BsonWriter implements BsonWriter {
  final Uint8List _list;

  final ByteData _data;

  int _offset;

  Uint8List get bytes => _list;

  _BsonWriter(Uint8List list)
      : _list = list,
        _data = new ByteData.view(list.buffer),
        _offset = 0;

  @override
  void writeFrom(List<int> buffer) {
    _list.setRange(_offset, _offset + buffer.length, buffer);
    _offset += buffer.length;
  }

  @override
  void writeDouble(double value) {
    _data.setFloat64(_offset, value, Endianness.LITTLE_ENDIAN);
    _offset += 8;
  }

  @override
  void writeByte(int value) {
    _list[_offset] = value;
    _offset++;
  }

  @override
  void writeInt32(int value) => _writeInt(value, 4);

  @override
  void writeInt64(int value) => _writeInt(value, 8);

  void _writeInt(int value, int numOfBytes) {
    switch (numOfBytes) {
      case 1:
        _data.setInt8(_offset, value);
        break;
      case 4:
        _data.setInt32(_offset, value, Endianness.LITTLE_ENDIAN);
        break;
      case 8:
        _data.setInt64(_offset, value, Endianness.LITTLE_ENDIAN);
        break;
      default:
        throw new UnsupportedError('writeInt(value, $numOfBytes)');
    }
    _offset += numOfBytes;
  }

  void writeString(String string) {
    List<int> utf8 = UTF8.encode(string);
    writeInt32(utf8.length + 1);
    writeFrom(utf8);
    writeByte(0);
  }

  @override
  void writeObjectId(ObjectId id) => writeFrom(id.toBytes());
}
