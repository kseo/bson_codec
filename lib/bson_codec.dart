// Copyright (c) 2016, Kwang Yul Seo. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// A BSON codec.
library bson_codec;

export 'package:bson_objectid/bson_objectid.dart' show ObjectId;

export 'src/codec.dart';
// Export types who don't have the matching Dart types.
// FIXME: Export BsonDecimal128 and BsonJavaScriptWithScope
// once they are implemented.
export 'src/types.dart'
    show
        BsonValue,
        BsonMaxKey,
        BsonMinKey,
        BsonUndefined,
        BsonBinary,
        BsonRegExp,
        BsonTimestamp,
        BsonDbPointer,
        BsonJavaScript,
        bsonSubTypeGeneric,
        bsonSubTypeFunction,
        bsonSubTypeOldBinary,
        bsonSubTypeOldUuid,
        bsonSubTypeUuid,
        bsonSubTypeMd5,
        bsonSubTypeUserDefined;
