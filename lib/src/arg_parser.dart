// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'allow_anything_parser.dart';
import 'arg_results.dart';
import 'option.dart';
import 'parser.dart';
import 'usage.dart';

/// A class for taking a list of raw command line arguments and parsing out
/// options and flags from them.
class ArgParser {
  final Map<String, Option> _options;
  final Map<String, ArgParser> _commands;

  /// The options that have been defined for this parser.
  final Map<String, Option> options;

  /// The commands that have been defined for this parser.
  final Map<String, ArgParser> commands;

  /// A list of the [Option]s in [options] intermingled with [String]
  /// separators.
  final _optionsAndSeparators = [];

  /// Whether or not this parser parses options that appear after non-option
  /// arguments.
  final bool allowTrailingOptions;

  /// Whether or not this parser treats unrecognized options as non-option
  /// arguments.
  bool get allowsAnything => false;

  /// Creates a new ArgParser.
  ///
  /// If [allowTrailingOptions] is `true` (the default), the parser will parse
  /// flags and options that appear after positional arguments. If it's `false`,
  /// the parser stops parsing as soon as it finds an argument that is neither
  /// an option nor a command.
  factory ArgParser({bool allowTrailingOptions: true}) =>
      new ArgParser._(<String, Option>{}, <String, ArgParser>{},
          allowTrailingOptions: allowTrailingOptions);

  /// Creates a new ArgParser that treats *all input* as non-option arguments.
  ///
  /// This is intended to allow arguments to be passed through to child
  /// processes without needing to be redefined in the parent.
  ///
  /// Options may not be defined for this parser.
  factory ArgParser.allowAnything() = AllowAnythingParser;

  ArgParser._(Map<String, Option> options, Map<String, ArgParser> commands,
      {bool allowTrailingOptions: true})
      : this._options = options,
        this.options = new UnmodifiableMapView(options),
        this._commands = commands,
        this.commands = new UnmodifiableMapView(commands),
        this.allowTrailingOptions =
            allowTrailingOptions != null ? allowTrailingOptions : false;

  /// Defines a command.
  ///
  /// A command is a named argument which may in turn define its own options and
  /// subcommands using the given parser. If [parser] is omitted, implicitly
  /// creates a new one. Returns the parser for the command.
  ArgParser addCommand(String name, [ArgParser parser]) {
    // Make sure the name isn't in use.
    if (_commands.containsKey(name)) {
      throw new ArgumentError('Duplicate command "$name".');
    }

    if (parser == null) parser = new ArgParser();
    _commands[name] = parser;
    return parser;
  }

  /// Defines a flag. Throws an [ArgumentError] if:
  ///
  /// * There is already an option named [name].
  /// * There is already an option using abbreviation [abbr].
  void addFlag(String name,
      {String abbr,
      String help,
      bool defaultsTo: false,
      bool negatable: true,
      void callback(bool value),
      bool hide: false}) {
    _addOption(
        name,
        abbr,
        help,
        null,
        null,
        null,
        defaultsTo,
        callback == null ? null : (value) => callback(value as bool),
        OptionType.FLAG,
        negatable: negatable,
        hide: hide);
  }

  /// Defines a value-taking option. Throws an [ArgumentError] if:
  ///
  /// * There is already an option with name [name].
  /// * There is already an option using abbreviation [abbr].
  /// * [splitCommas] is passed but [allowMultiple] is `false`.
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
    if (!allowMultiple && splitCommas != null) {
      throw new ArgumentError(
          'splitCommas may not be set if allowMultiple is false.');
    }

    _addOption(name, abbr, help, valueHelp, allowed, allowedHelp, defaultsTo,
        callback, allowMultiple ? OptionType.MULTIPLE : OptionType.SINGLE,
        splitCommas: splitCommas, hide: hide);
  }

  void _addOption(
      String name,
      String abbr,
      String help,
      String valueHelp,
      Iterable<String> allowed,
      Map<String, String> allowedHelp,
      defaultsTo,
      Function callback,
      OptionType type,
      {bool negatable: false,
      bool splitCommas,
      bool hide: false}) {
    // Make sure the name isn't in use.
    if (_options.containsKey(name)) {
      throw new ArgumentError('Duplicate option "$name".');
    }

    // Make sure the abbreviation isn't too long or in use.
    if (abbr != null) {
      var existing = findByAbbreviation(abbr);
      if (existing != null) {
        throw new ArgumentError(
            'Abbreviation "$abbr" is already used by "${existing.name}".');
      }
    }

    var option = newOption(name, abbr, help, valueHelp, allowed, allowedHelp,
        defaultsTo, callback, type,
        negatable: negatable, splitCommas: splitCommas, hide: hide);
    _options[name] = option;
    _optionsAndSeparators.add(option);
  }

  /// Adds a separator line to the usage.
  ///
  /// In the usage text for the parser, this will appear between any options
  /// added before this call and ones added after it.
  void addSeparator(String text) {
    _optionsAndSeparators.add(text);
  }

  /// Parses [args], a list of command-line arguments, matches them against the
  /// flags and options defined by this parser, and returns the result.
  ArgResults parse(Iterable<String> args) =>
      new Parser(null, this, args.toList()).parse();

  /// Generates a string displaying usage information for the defined options.
  ///
  /// This is basically the help text shown on the command line.
  @Deprecated("Replaced with get usage. getUsage() will be removed in args 1.0")
  String getUsage() => usage;

  /// Generates a string displaying usage information for the defined options.
  ///
  /// This is basically the help text shown on the command line.
  String get usage => new Usage(_optionsAndSeparators).generate();

  /// Get the default value for an option. Useful after parsing to test if the
  /// user specified something other than the default.
  getDefault(String option) {
    if (!options.containsKey(option)) {
      throw new ArgumentError('No option named $option');
    }
    return options[option].defaultValue;
  }

  /// Finds the option whose abbreviation is [abbr], or `null` if no option has
  /// that abbreviation.
  Option findByAbbreviation(String abbr) {
    return options.values.firstWhere((option) => option.abbreviation == abbr,
        orElse: () => null);
  }
}
