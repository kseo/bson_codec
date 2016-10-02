# bson_codec

This package offers Dart programs a flexible serializer and deserializer
for BSON documents.

## Highlights

* Standard `Codec`/`Encoder`/`Decoder` interface, as established by the
  standard 'dart:convert' package.
* Best effort type mapping when serializing/deserializing values.

## Examples

```
import 'package:bson_codec/bson_codec.dart';

main() {
  final doc = {
    '_id': 5,
    'a': [2, 3, 5]
  };
  List<int> bytes = BSON.encode(doc);
  final root = BSON.decode(bytes);
  print(doc['a'][2]); // 5
}
```

### TODO

`JavaScript code w/ scope` and `decimal128` are not supported yet.

