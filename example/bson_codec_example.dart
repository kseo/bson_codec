// Copyright (c) 2016, Kwang Yul Seo. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:bson_codec/bson_codec.dart';

main() {
  new File('sample.bson').openRead().transform(new BsonDecoder()).listen(print);
}
