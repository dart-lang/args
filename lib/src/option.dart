// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Creates a new [Option].
///
/// Since [Option] doesn't have a public constructor, this lets `ArgParser`
/// get to it. This function isn't exported to the public API of the package.
Option newOption(
    String name,
    String abbreviation,
    String help,
    String valueHelp,
    Iterable<String> allowed,
    Map<String, String> allowedHelp,
    defaultValue,
    Function callback,
    OptionType type,
    {bool negatable,
    bool splitCommas,
    bool hide: false}) {
  return new Option._(name, abbreviation, help, valueHelp, allowed, allowedHelp,
      defaultValue, callback, type,
      negatable: negatable, splitCommas: splitCommas, hide: hide);
}

/// A command-line option. Includes both flags and options which take a value.
class Option {
  final String name;
  final String abbreviation;
  final List<String> allowed;
  final defaultValue;
  final Function callback;
  final String help;
  final String valueHelp;
  final Map<String, String> allowedHelp;
  final OptionType type;
  final bool negatable;
  final bool splitCommas;
  final bool hide;

  /// Whether the option is boolean-valued flag.
  bool get isFlag => type == OptionType.FLAG;

  /// Whether the option takes a single value.
  bool get isSingle => type == OptionType.SINGLE;

  /// Whether the option allows multiple values.
  bool get isMultiple => type == OptionType.MULTIPLE;

  Option._(
      this.name,
      this.abbreviation,
      this.help,
      this.valueHelp,
      Iterable<String> allowed,
      Map<String, String> allowedHelp,
      this.defaultValue,
      this.callback,
      OptionType type,
      {this.negatable,
      bool splitCommas,
      this.hide: false})
      : this.allowed = allowed == null ? null : new List.unmodifiable(allowed),
        this.allowedHelp =
            allowedHelp == null ? null : new Map.unmodifiable(allowedHelp),
        this.type = type,
        // If the user doesn't specify [splitCommas], it defaults to true for
        // multiple options.
        this.splitCommas =
            splitCommas == null ? type == OptionType.MULTIPLE : splitCommas {
    if (name.isEmpty) {
      throw new ArgumentError('Name cannot be empty.');
    } else if (name.startsWith('-')) {
      throw new ArgumentError('Name $name cannot start with "-".');
    }

    // Ensure name does not contain any invalid characters.
    if (_invalidChars.hasMatch(name)) {
      throw new ArgumentError('Name "$name" contains invalid characters.');
    }

    if (abbreviation != null) {
      if (abbreviation.length != 1) {
        throw new ArgumentError('Abbreviation must be null or have length 1.');
      } else if (abbreviation == '-') {
        throw new ArgumentError('Abbreviation cannot be "-".');
      }

      if (_invalidChars.hasMatch(abbreviation)) {
        throw new ArgumentError('Abbreviation is an invalid character.');
      }
    }
  }

  /// Returns [value] if non-`null`, otherwise returns the default value for
  /// this option.
  ///
  /// For single-valued options, it will be [defaultValue] if set or `null`
  /// otherwise. For multiple-valued options, it will be an empty list or a
  /// list containing [defaultValue] if set.
  dynamic getOrDefault(value) {
    if (value != null) return value;

    if (!isMultiple) return defaultValue;
    if (defaultValue != null) return [defaultValue];
    return [];
  }

  static final _invalidChars = new RegExp(r'''[ \t\r\n"'\\/]''');
}

/// What kinds of values an option accepts.
class OptionType {
  /// An option that can only be `true` or `false`.
  ///
  /// The presence of the option name itself in the argument list means `true`.
  static const FLAG = const OptionType._("OptionType.FLAG");

  /// An option that takes a single value.
  ///
  /// Examples:
  ///
  ///     --mode debug
  ///     -mdebug
  ///     --mode=debug
  ///
  /// If the option is passed more than once, the last one wins.
  static const SINGLE = const OptionType._("OptionType.SINGLE");

  /// An option that allows multiple values.
  ///
  /// Example:
  ///
  ///     --output text --output xml
  ///
  /// In the parsed `ArgResults`, a multiple-valued option will always return
  /// a list, even if one or no values were passed.
  static const MULTIPLE = const OptionType._("OptionType.MULTIPLE");

  final String name;

  const OptionType._(this.name);
}
