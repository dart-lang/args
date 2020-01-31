// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:args/args.dart';
import 'package:test/test.dart';

void main() {
  group('ArgParser.parse()', () {
    test('is fast', () {
      var parser = ArgParser()..addFlag('flag');

      var baseSize = 10000;
      var baseList = List<String>.generate(baseSize, (_) => '--flag');

      var multiplier = 10;
      var largeList =
          List<String>.generate(baseSize * multiplier, (_) => '--flag');
      var baseTime = _time(() => parser.parse(baseList));
      var largeTime = _time(() => parser.parse(largeList));
      expect(largeTime, lessThan(baseTime * multiplier * 3),
          reason:
              'Comparing large data set time ${largeTime}ms to small data set time '
              '${baseTime}ms. Data set increased ${multiplier}x, time is allowed to '
              'increase up to ${multiplier * 3}x, but it increased '
              '${largeTime ~/ baseTime}x.');
    });
  });
}

int _time(void Function() function) {
  var stopwatch = Stopwatch()..start();
  function();
  return stopwatch.elapsedMilliseconds;
}
