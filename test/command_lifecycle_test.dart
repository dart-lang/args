// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:args/command_runner.dart';
import 'package:test/test.dart';

void main() {
  late CommandRunner runner;
  late _ReadValueCommand command;
  setUp(() {
    command = _ReadValueCommand();
    runner = CommandRunner('cli', 'desc')..addCommand(command);
    runner.argParser.addOption('globalValue');
  });

  group('argResults', () {
    test('argResults throws when accessed before run()', () {
      expect(
        () => command.argResults,
        throwsA(isA<StateError>()
            .having((e) => e.message, 'message', contains('argResults'))
            .having((e) => e.message, 'message', contains('Command.run'))),
      );
    });

    test('argResults is readable inside run()', () async {
      final result = await runner.run(['foo', '--value=bar']);
      expect(result, 'bar');
    });

    test('argResults throws when accessed after run()', () async {
      await runner.run(['foo', '--value=bar']);
      expect(
        () => command.argResults,
        throwsA(isA<StateError>()
            .having((e) => e.message, 'message', contains('argResults'))
            .having((e) => e.message, 'message', contains('Command.run'))),
      );
    });
  });

  group('globalResults', () {
    test('globalResults throws when accessed before run()', () {
      expect(
        () => command.globalResults,
        throwsA(isA<StateError>()
            .having((e) => e.message, 'message', contains('globalResults'))
            .having((e) => e.message, 'message', contains('Command.run'))),
      );
    });

    test('globalResults is readable inside run()', () async {
      final result = await runner.run(['foo', '--globalValue=bar']);
      expect(result, 'bar');
    });

    test('globalResults throws when accessed after run()', () async {
      await runner.run(['foo', '--globalValue=bar']);
      expect(
        () => command.globalResults,
        throwsA(isA<StateError>()
            .having((e) => e.message, 'message', contains('globalResults'))
            .having((e) => e.message, 'message', contains('Command.run'))),
      );
    });
  });

  test('Command with arguments can not be executed without CommandRunner', () {
    final command = _ReadValueCommand();
    expect(
      () async => command.run(),
      throwsA(isA<StateError>()
          .having((e) => e.message, 'message', contains('argResults'))
          .having((e) => e.message, 'message', contains('Command.run'))),
    );
  });
}

class _ReadValueCommand extends Command {
  @override
  final name = 'foo';

  @override
  final description = 'Returns param: value.';

  @override
  final takesArguments = false;

  _ReadValueCommand() {
    argParser.addOption('value');
  }

  @override
  String? run() {
    final value = argResults['value'] as String?;
    final globalValue = globalResults.wasParsed('globalValue')
        ? globalResults['globalValue'] as String?
        : null;

    return value ?? globalValue;
  }
}
