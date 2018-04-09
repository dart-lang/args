// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'arg_parser.dart';
import 'arg_results.dart';
import 'option.dart';
import 'parser.dart';

/// An ArgParser that treats *all input* as non-option arguments.
class AllowAnythingParser implements ArgParser {
  @override
  Map<String, Option> get options => const {};
  @override
  Map<String, ArgParser> get commands => const {};
  @override
  bool get allowTrailingOptions => false;
  @override
  bool get allowsAnything => true;

  @override
  ArgParser addCommand(String name, [ArgParser parser]) {
    throw new UnsupportedError(
        "ArgParser.allowAnything().addCommands() isn't supported.");
  }

  @override
  void addFlag(String name,
      {String abbr,
      String help,
      bool defaultsTo: false,
      bool negatable: true,
      void callback(bool value),
      bool hide: false}) {
    throw new UnsupportedError(
        "ArgParser.allowAnything().addFlag() isn't supported.");
  }

  @override
  void addOption(String name,
      {String abbr,
      String help,
      String valueHelp,
      Iterable<String> allowed,
      Map<String, String> allowedHelp,
      String defaultsTo,
      Function callback,
      bool allowMultiple: false,
      bool splitCommas,
      bool hide: false}) {
    throw new UnsupportedError(
        "ArgParser.allowAnything().addOption() isn't supported.");
  }

  @override
  void addMultiOption(String name,
      {String abbr,
      String help,
      String valueHelp,
      Iterable<String> allowed,
      Map<String, String> allowedHelp,
      Iterable<String> defaultsTo,
      void callback(List<String> values),
      bool splitCommas: true,
      bool hide: false}) {
    throw new UnsupportedError(
        "ArgParser.allowAnything().addMultiOption() isn't supported.");
  }

  @override
  void addSeparator(String text) {
    throw new UnsupportedError(
        "ArgParser.allowAnything().addSeparator() isn't supported.");
  }

  @override
  ArgResults parse(Iterable<String> args) =>
      new Parser(null, this, args.toList()).parse();

  @override
  String getUsage() => usage;

  @override
  String get usage => "";

  @override
  getDefault(String option) {
    throw new ArgumentError('No option named $option');
  }

  @override
  Option findByAbbreviation(String abbr) => null;
}
