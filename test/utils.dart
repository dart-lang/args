// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:test/test.dart';

class CommandRunnerWithFooter extends CommandRunner {
  @override
  String get usageFooter => "Also, footer!";

  CommandRunnerWithFooter(String executableName, String description)
      : super(executableName, description);
}

class FooCommand extends Command {
  var hasRun = false;

  @override
  final name = "foo";

  @override
  final description = "Set a value.";

  @override
  final takesArguments = false;

  @override
  void run() {
    hasRun = true;
  }
}

class ValueCommand extends Command<int> {
  @override
  final name = "foo";

  @override
  final description = "Return a value.";

  @override
  final takesArguments = false;

  @override
  int run() => 12;
}

class AsyncValueCommand extends Command<String> {
  @override
  final name = "foo";

  @override
  final description = "Return a future.";

  @override
  final takesArguments = false;

  @override
  Future<String> run() async => "hi";
}

class MultilineCommand extends Command {
  var hasRun = false;

  @override
  final name = "multiline";

  @override
  final description = "Multi\nline.";

  @override
  final takesArguments = false;

  @override
  void run() {
    hasRun = true;
  }
}

class MultilineSummaryCommand extends MultilineCommand {
  @override
  String get summary => description;
}

class HiddenCommand extends Command {
  var hasRun = false;

  @override
  final name = "hidden";

  @override
  final description = "Set a value.";

  @override
  final hidden = true;

  @override
  final takesArguments = false;

  @override
  void run() {
    hasRun = true;
  }
}

class AliasedCommand extends Command {
  var hasRun = false;

  @override
  final name = "aliased";

  @override
  final description = "Set a value.";

  @override
  final takesArguments = false;

  @override
  final aliases = const ["alias", "als"];

  @override
  void run() {
    hasRun = true;
  }
}

class AsyncCommand extends Command {
  var hasRun = false;

  @override
  final name = "async";

  @override
  final description = "Set a value asynchronously.";

  @override
  final takesArguments = false;

  @override
  Future run() => new Future.value().then((_) => hasRun = true);
}

void throwsIllegalArg(function, {String reason}) {
  expect(function, throwsArgumentError, reason: reason);
}

void throwsFormat(ArgParser parser, List<String> args) {
  expect(() => parser.parse(args), throwsFormatException);
}

Matcher throwsUsageException(message, usage) {
  return throwsA(predicate((error) {
    expect(error, new isInstanceOf<UsageException>());
    expect(error.message, message);
    expect(error.usage, usage);
    return true;
  }));
}
