// Copyright (c) 2016, Kwang Yul Seo. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

List<String> _hexChars = [
  '0',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  'a',
  'b',
  'c',
  'd',
  'e',
  'f'
];

String toHexString(List<int> bytes) {
  List<String> charCodes = new List<String>(bytes.length * 2);
  int i = 0;
  for (final b in bytes) {
    charCodes[i++] = _hexChars[b >> 4 & 0xF];
    charCodes[i++] = _hexChars[b & 0xF];
  }
  return charCodes.join('');
}
