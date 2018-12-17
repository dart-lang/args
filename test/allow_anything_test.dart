// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:args/args.dart';
import 'package:test/test.dart';

void main() {
  group('new ArgParser.allowAnything()', () {
    ArgParser parser;
    setUp(() {
      parser = ArgParser.allowAnything();
    });

    test('exposes empty values', () {
      expect(parser.options, isEmpty);
      expect(parser.commands, isEmpty);
      expect(parser.allowTrailingOptions, isFalse);
      expect(parser.allowsAnything, isTrue);
      expect(parser.usage, isEmpty);
      expect(parser.getUsage(), isEmpty); // ignore: deprecated_member_use
      expect(parser.findByAbbreviation("a"), isNull);
    });

    test('mutation methods throw errors', () {
      expect(() => parser.addCommand("command"), throwsUnsupportedError);
      expect(() => parser.addFlag("flag"), throwsUnsupportedError);
      expect(() => parser.addOption("option"), throwsUnsupportedError);
      expect(() => parser.addSeparator("==="), throwsUnsupportedError);
    });

    test('getDefault() throws an error', () {
      expect(() => parser.getDefault('option'), throwsArgumentError);
    });

    test('parses all values as rest arguments', () {
      var results = parser.parse(['--foo', '-abc', '--', 'bar']);
      expect(results.options, isEmpty);
      expect(results.rest, equals(['--foo', '-abc', '--', 'bar']));
      expect(results.arguments, equals(['--foo', '-abc', '--', 'bar']));
      expect(results.command, isNull);
      expect(results.name, isNull);
    });

    test('works as a subcommand', () {
      var commandParser = ArgParser()..addCommand('command', parser);
      var results =
          commandParser.parse(['command', '--foo', '-abc', '--', 'bar']);
      expect(results.command.options, isEmpty);
      expect(results.command.rest, equals(['--foo', '-abc', '--', 'bar']));
      expect(results.command.arguments, equals(['--foo', '-abc', '--', 'bar']));
      expect(results.command.name, equals('command'));
    });
  });
}
