// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(nweiz): Remove this ignore when sdk#30084 is fixed or when args no
// longer refers to its own deprecated members.
// ignore_for_file: deprecated_member_use

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

  /// An optional maximum line length for [usage] messages.
  ///
  /// If specified, then help messages in the usage are wrapped at the given
  /// column, after taking into account the width of the options. Will refuse to
  /// wrap help text to less than 10 characters of help text per line if there
  /// isn't enough space on the line. It preserves embedded newlines, and
  /// attempts to wrap at whitespace breaks (although it will split words if
  /// there is no whitespace at which to split).
  ///
  /// If null (the default), help messages are not wrapped.
  final int usageLineLength;

  /// Whether or not this parser treats unrecognized options as non-option
  /// arguments.
  bool get allowsAnything => false;

  /// Creates a new ArgParser.
  ///
  /// If [allowTrailingOptions] is `true` (the default), the parser will parse
  /// flags and options that appear after positional arguments. If it's `false`,
  /// the parser stops parsing as soon as it finds an argument that is neither
  /// an option nor a command.
  factory ArgParser({bool allowTrailingOptions = true, int usageLineLength}) =>
      ArgParser._(<String, Option>{}, <String, ArgParser>{},
          allowTrailingOptions: allowTrailingOptions,
          usageLineLength: usageLineLength);

  /// Creates a new ArgParser that treats *all input* as non-option arguments.
  ///
  /// This is intended to allow arguments to be passed through to child
  /// processes without needing to be redefined in the parent.
  ///
  /// Options may not be defined for this parser.
  factory ArgParser.allowAnything() = AllowAnythingParser;

  ArgParser._(Map<String, Option> options, Map<String, ArgParser> commands,
      {bool allowTrailingOptions = true, this.usageLineLength})
      : _options = options,
        options = UnmodifiableMapView(options),
        _commands = commands,
        commands = UnmodifiableMapView(commands),
        allowTrailingOptions = allowTrailingOptions ?? false;

  /// Defines a command.
  ///
  /// A command is a named argument which may in turn define its own options and
  /// subcommands using the given parser. If [parser] is omitted, implicitly
  /// creates a new one. Returns the parser for the command.
  ///
  /// Note that adding commands this way will not impact the [usage] string. To
  /// add commands which are included in the usage string see `CommandRunner`.
  ArgParser addCommand(String name, [ArgParser parser]) {
    // Make sure the name isn't in use.
    if (_commands.containsKey(name)) {
      throw ArgumentError('Duplicate command "$name".');
    }

    parser ??= ArgParser();
    _commands[name] = parser;
    return parser;
  }

  /// Defines a boolean flag.
  ///
  /// This adds an [Option] with the given properties to [options].
  ///
  /// The [abbr] argument is a single-character string that can be used as a
  /// shorthand for this flag. For example, `abbr: "a"` will allow the user to
  /// pass `-a` to enable the flag.
  ///
  /// The [help] argument is used by [usage] to describe this flag.
  ///
  /// The [defaultsTo] argument indicates the value this flag will have if the
  /// user doesn't explicitly pass it in.
  ///
  /// The [negatable] argument indicates whether this flag's value can be set to
  /// `false`. For example, if [name] is `flag`, the user can pass `--no-flag`
  /// to set its value to `false`.
  ///
  /// The [callback] argument is invoked with the flag's value when the flag
  /// is parsed. Note that this makes argument parsing order-dependent in ways
  /// that are often surprising, and its use is discouraged in favor of reading
  /// values from the [ArgResults].
  ///
  /// If [hide] is `true`, this option won't be included in [usage].
  ///
  /// Throws an [ArgumentError] if:
  ///
  /// * There is already an option named [name].
  /// * There is already an option using abbreviation [abbr].
  void addFlag(String name,
      {String abbr,
      String help,
      bool defaultsTo = false,
      bool negatable = true,
      void Function(bool) callback,
      bool hide = false}) {
    _addOption(
        name,
        abbr,
        help,
        null,
        null,
        null,
        defaultsTo,
        callback == null ? null : (value) => callback(value as bool),
        OptionType.flag,
        negatable: negatable,
        hide: hide);
  }

  /// Defines an option that takes a value.
  ///
  /// This adds an [Option] with the given properties to [options].
  ///
  /// The [abbr] argument is a single-character string that can be used as a
  /// shorthand for this option. For example, `abbr: "a"` will allow the user to
  /// pass `-a value` or `-avalue`.
  ///
  /// The [help] argument is used by [usage] to describe this option.
  ///
  /// The [valueHelp] argument is used by [usage] as a name for the value this
  /// option takes. For example, `valueHelp: "FOO"` will include
  /// `--option=<FOO>` rather than just `--option` in the usage string.
  ///
  /// The [allowed] argument is a list of valid values for this option. If
  /// it's non-`null` and the user passes a value that's not included in the
  /// list, [parse] will throw a [FormatException]. The allowed values will also
  /// be included in [usage].
  ///
  /// The [allowedHelp] argument is a map from values in [allowed] to
  /// documentation for those values that will be included in [usage].
  ///
  /// The [defaultsTo] argument indicates the value this option will have if the
  /// user doesn't explicitly pass it in (or `null` by default).
  ///
  /// The [callback] argument is invoked with the option's value when the option
  /// is parsed. Note that this makes argument parsing order-dependent in ways
  /// that are often surprising, and its use is discouraged in favor of reading
  /// values from the [ArgResults].
  ///
  /// The [allowMultiple] and [splitCommas] options are deprecated; the
  /// [addMultiOption] method should be used instead.
  ///
  /// If [hide] is `true`, this option won't be included in [usage].
  ///
  /// Throws an [ArgumentError] if:
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
      @Deprecated('Use addMultiOption() instead.') bool allowMultiple = false,
      @Deprecated('Use addMultiOption() instead.') bool splitCommas,
      bool hide = false}) {
    if (!allowMultiple && splitCommas != null) {
      throw ArgumentError(
          'splitCommas may not be set if allowMultiple is false.');
    }

    _addOption(
        name,
        abbr,
        help,
        valueHelp,
        allowed,
        allowedHelp,
        allowMultiple
            ? (defaultsTo == null ? <String>[] : [defaultsTo])
            : defaultsTo,
        callback,
        allowMultiple ? OptionType.multiple : OptionType.single,
        splitCommas: splitCommas,
        hide: hide);
  }

  /// Defines an option that takes multiple values.
  ///
  /// The [abbr] argument is a single-character string that can be used as a
  /// shorthand for this option. For example, `abbr: "a"` will allow the user to
  /// pass `-a value` or `-avalue`.
  ///
  /// The [help] argument is used by [usage] to describe this option.
  ///
  /// The [valueHelp] argument is used by [usage] as a name for the value this
  /// argument takes. For example, `valueHelp: "FOO"` will include
  /// `--option=<FOO>` rather than just `--option` in the usage string.
  ///
  /// The [allowed] argument is a list of valid values for this argument. If
  /// it's non-`null` and the user passes a value that's not included in the
  /// list, [parse] will throw a [FormatException]. The allowed values will also
  /// be included in [usage].
  ///
  /// The [allowedHelp] argument is a map from values in [allowed] to
  /// documentation for those values that will be included in [usage].
  ///
  /// The [defaultsTo] argument indicates the values this option will have if
  /// the user doesn't explicitly pass it in (or `[]` by default).
  ///
  /// The [callback] argument is invoked with the option's value when the option
  /// is parsed. Note that this makes argument parsing order-dependent in ways
  /// that are often surprising, and its use is discouraged in favor of reading
  /// values from the [ArgResults].
  ///
  /// If [splitCommas] is `true` (the default), multiple options may be passed
  /// by writing `--option a,b` in addition to `--option a --option b`.
  ///
  /// If [hide] is `true`, this option won't be included in [usage].
  ///
  /// Throws an [ArgumentError] if:
  ///
  /// * There is already an option with name [name].
  /// * There is already an option using abbreviation [abbr].
  void addMultiOption(String name,
      {String abbr,
      String help,
      String valueHelp,
      Iterable<String> allowed,
      Map<String, String> allowedHelp,
      Iterable<String> defaultsTo,
      void Function(List<String>) callback,
      bool splitCommas = true,
      bool hide = false}) {
    _addOption(
        name,
        abbr,
        help,
        valueHelp,
        allowed,
        allowedHelp,
        defaultsTo?.toList() ?? <String>[],
        callback == null ? null : (value) => callback(value as List<String>),
        OptionType.multiple,
        splitCommas: splitCommas,
        hide: hide);
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
      {bool negatable = false,
      bool splitCommas,
      bool hide = false}) {
    // Make sure the name isn't in use.
    if (_options.containsKey(name)) {
      throw ArgumentError('Duplicate option "$name".');
    }

    // Make sure the abbreviation isn't too long or in use.
    if (abbr != null) {
      var existing = findByAbbreviation(abbr);
      if (existing != null) {
        throw ArgumentError(
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
      Parser(null, this, Queue.of(args)).parse();

  /// Generates a string displaying usage information for the defined options.
  ///
  /// This is basically the help text shown on the command line.
  @Deprecated('Replaced with get usage. getUsage() will be removed in args 1.0')
  String getUsage() => usage;

  /// Generates a string displaying usage information for the defined options.
  ///
  /// This is basically the help text shown on the command line.
  String get usage {
    return Usage(_optionsAndSeparators, lineLength: usageLineLength).generate();
  }

  /// Get the default value for an option. Useful after parsing to test if the
  /// user specified something other than the default.
  dynamic getDefault(String option) {
    if (!options.containsKey(option)) {
      throw ArgumentError('No option named $option');
    }
    return options[option].defaultsTo;
  }

  /// Finds the option whose abbreviation is [abbr], or `null` if no option has
  /// that abbreviation.
  Option findByAbbreviation(String abbr) {
    return options.values
        .firstWhere((option) => option.abbr == abbr, orElse: () => null);
  }
}
