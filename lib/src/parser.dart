// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'arg_parser.dart';
import 'arg_parser_exception.dart';
import 'arg_results.dart';
import 'option.dart';

/// The actual argument parsing class.
///
/// Unlike [ArgParser] which is really more an "arg grammar", this is the class
/// that does the parsing and holds the mutable state required during a parse.
class Parser {
  /// If parser is parsing a command's options, this will be the name of the
  /// command. For top-level results, this returns `null`.
  final String commandName;

  /// The parser for the supercommand of this command parser, or `null` if this
  /// is the top-level parser.
  final Parser parent;

  /// The grammar being parsed.
  final ArgParser grammar;

  /// The arguments being parsed.
  final Queue<String> args;

  /// The remaining non-option, non-command arguments.
  final rest = <String>[];

  /// The accumulated parsed options.
  final Map<String, dynamic> results = <String, dynamic>{};

  Parser(this.commandName, this.grammar, this.args,
      [this.parent, List<String> rest]) {
    if (rest != null) this.rest.addAll(rest);
  }

  /// The current argument being parsed.
  String get current => args.first;

  /// Parses the arguments. This can only be called once.
  ArgResults parse() {
    var arguments = args.toList();
    if (grammar.allowsAnything) {
      return newArgResults(
          grammar, const {}, commandName, null, arguments, arguments);
    }

    ArgResults commandResults;

    // Parse the args.
    while (args.isNotEmpty) {
      if (current == '--') {
        // Reached the argument terminator, so stop here.
        args.removeFirst();
        break;
      }

      // Try to parse the current argument as a command. This happens before
      // options so that commands can have option-like names.
      var command = grammar.commands[current];
      if (command != null) {
        validate(rest.isEmpty, 'Cannot specify arguments before a command.');
        var commandName = args.removeFirst();
        var commandParser = Parser(commandName, command, args, this, rest);

        try {
          commandResults = commandParser.parse();
        } on ArgParserException catch (error) {
          if (commandName == null) rethrow;
          throw ArgParserException(
              error.message, [commandName, ...error.commands]);
        }

        // All remaining arguments were passed to command so clear them here.
        rest.clear();
        break;
      }

      // Try to parse the current argument as an option. Note that the order
      // here matters.
      if (parseSoloOption()) continue;
      if (parseAbbreviation(this)) continue;
      if (parseLongOption()) continue;

      // This argument is neither option nor command, so stop parsing unless
      // the [allowTrailingOptions] option is set.
      if (!grammar.allowTrailingOptions) break;
      rest.add(args.removeFirst());
    }

    // Invoke the callbacks.
    grammar.options.forEach((name, option) {
      if (option.callback == null) return;
      option.callback(option.getOrDefault(results[name]));
    });

    // Add in the leftover arguments we didn't parse to the innermost command.
    rest.addAll(args);
    args.clear();
    return newArgResults(
        grammar, results, commandName, commandResults, rest, arguments);
  }

  /// Pulls the value for [option] from the second argument in [args].
  ///
  /// Validates that there is a valid value there.
  void readNextArgAsValue(Option option) {
    // Take the option argument from the next command line arg.
    validate(args.isNotEmpty, 'Missing argument for "${option.name}".');

    setOption(results, option, current);
    args.removeFirst();
  }

  /// Tries to parse the current argument as a "solo" option, which is a single
  /// hyphen followed by a single letter.
  ///
  /// We treat this differently than collapsed abbreviations (like "-abc") to
  /// handle the possible value that may follow it.
  bool parseSoloOption() {
    // Hand coded regexp: r'^-([a-zA-Z0-9])$'
    // Length must be two, hyphen followed by any letter/digit.
    if (current.length != 2) return false;
    if (!current.startsWith('-')) return false;
    var opt = current[1];
    if (!_isLetterOrDigit(opt.codeUnitAt(0))) return false;

    var option = grammar.findByAbbreviation(opt);
    if (option == null) {
      // Walk up to the parent command if possible.
      validate(parent != null, 'Could not find an option or flag "-$opt".');
      return parent.parseSoloOption();
    }

    args.removeFirst();

    if (option.isFlag) {
      setFlag(results, option, true);
    } else {
      readNextArgAsValue(option);
    }

    return true;
  }

  /// Tries to parse the current argument as a series of collapsed abbreviations
  /// (like "-abc") or a single abbreviation with the value directly attached
  /// to it (like "-mrelease").
  bool parseAbbreviation(Parser innermostCommand) {
    // Hand coded regexp: r'^-([a-zA-Z0-9]+)(.*)$'
    // Hyphen then at least one letter/digit then zero or more
    // anything-but-newlines.
    if (current.length < 2) return false;
    if (!current.startsWith('-')) return false;

    // Find where we go from letters/digits to rest.
    var index = 1;
    while (
        index < current.length && _isLetterOrDigit(current.codeUnitAt(index))) {
      ++index;
    }
    // Must be at least one letter/digit.
    if (index == 1) return false;

    // If the first character is the abbreviation for a non-flag option, then
    // the rest is the value.
    var lettersAndDigits = current.substring(1, index);
    var rest = current.substring(index);
    if (rest.contains('\n') || rest.contains('\r')) return false;

    var c = lettersAndDigits.substring(0, 1);
    var first = grammar.findByAbbreviation(c);
    if (first == null) {
      // Walk up to the parent command if possible.
      validate(
          parent != null, 'Could not find an option with short name "-$c".');
      return parent.parseAbbreviation(innermostCommand);
    } else if (!first.isFlag) {
      // The first character is a non-flag option, so the rest must be the
      // value.
      var value = '${lettersAndDigits.substring(1)}$rest';
      setOption(results, first, value);
    } else {
      // If we got some non-flag characters, then it must be a value, but
      // if we got here, it's a flag, which is wrong.
      validate(
          rest == '',
          'Option "-$c" is a flag and cannot handle value '
          '"${lettersAndDigits.substring(1)}$rest".');

      // Not an option, so all characters should be flags.
      // We use "innermostCommand" here so that if a parent command parses the
      // *first* letter, subcommands can still be found to parse the other
      // letters.
      for (var i = 0; i < lettersAndDigits.length; i++) {
        var c = lettersAndDigits.substring(i, i + 1);
        innermostCommand.parseShortFlag(c);
      }
    }

    args.removeFirst();
    return true;
  }

  void parseShortFlag(String c) {
    var option = grammar.findByAbbreviation(c);
    if (option == null) {
      // Walk up to the parent command if possible.
      validate(
          parent != null, 'Could not find an option with short name "-$c".');
      parent.parseShortFlag(c);
      return;
    }

    // In a list of short options, only the first can be a non-flag. If
    // we get here we've checked that already.
    validate(
        option.isFlag, 'Option "-$c" must be a flag to be in a collapsed "-".');

    setFlag(results, option, true);
  }

  /// Tries to parse the current argument as a long-form named option, which
  /// may include a value like "--mode=release" or "--mode release".
  bool parseLongOption() {
    // Hand coded regexp: r'^--([a-zA-Z\-_0-9]+)(=(.*))?$'
    // Two hyphens then at least one letter/digit/hyphen, optionally an equal
    // sign followed by zero or more anything-but-newlines.

    if (!current.startsWith('--')) return false;

    var index = current.indexOf('=');
    var name = index == -1 ? current.substring(2) : current.substring(2, index);
    for (var i = 0; i != name.length; ++i) {
      if (!_isLetterDigitHyphenOrUnderscore(name.codeUnitAt(i))) return false;
    }
    var value = index == -1 ? null : current.substring(index + 1);
    if (value != null && (value.contains('\n') || value.contains('\r'))) {
      return false;
    }

    var option = grammar.options[name];
    if (option != null) {
      args.removeFirst();
      if (option.isFlag) {
        validate(
            value == null, 'Flag option "$name" should not be given a value.');

        setFlag(results, option, true);
      } else if (value != null) {
        // We have a value like --foo=bar.
        setOption(results, option, value);
      } else {
        // Option like --foo, so look for the value as the next arg.
        readNextArgAsValue(option);
      }
    } else if (name.startsWith('no-')) {
      // See if it's a negated flag.
      name = name.substring('no-'.length);
      option = grammar.options[name];
      if (option == null) {
        // Walk up to the parent command if possible.
        validate(parent != null, 'Could not find an option named "$name".');
        return parent.parseLongOption();
      }

      args.removeFirst();
      validate(option.isFlag, 'Cannot negate non-flag option "$name".');
      validate(option.negatable, 'Cannot negate option "$name".');

      setFlag(results, option, false);
    } else {
      // Walk up to the parent command if possible.
      validate(parent != null, 'Could not find an option named "$name".');
      return parent.parseLongOption();
    }

    return true;
  }

  /// Called during parsing to validate the arguments.
  ///
  /// Throws an [ArgParserException] if [condition] is `false`.
  void validate(bool condition, String message) {
    if (!condition) throw ArgParserException(message);
  }

  /// Validates and stores [value] as the value for [option], which must not be
  /// a flag.
  void setOption(Map results, Option option, String value) {
    assert(!option.isFlag);

    if (!option.isMultiple) {
      _validateAllowed(option, value);
      results[option.name] = value;
      return;
    }

    var list = results.putIfAbsent(option.name, () => <String>[]);

    if (option.splitCommas) {
      for (var element in value.split(',')) {
        _validateAllowed(option, element);
        list.add(element);
      }
    } else {
      _validateAllowed(option, value);
      list.add(value);
    }
  }

  /// Validates and stores [value] as the value for [option], which must be a
  /// flag.
  void setFlag(Map results, Option option, bool value) {
    assert(option.isFlag);
    results[option.name] = value;
  }

  /// Validates that [value] is allowed as a value of [option].
  void _validateAllowed(Option option, String value) {
    if (option.allowed == null) return;

    validate(option.allowed.contains(value),
        '"$value" is not an allowed value for option "${option.name}".');
  }
}

bool _isLetterOrDigit(int codeUnit) =>
    // Uppercase letters.
    (codeUnit >= 65 && codeUnit <= 90) ||
    // Lowercase letters.
    (codeUnit >= 97 && codeUnit <= 122) ||
    // Digits.
    (codeUnit >= 48 && codeUnit <= 57);

bool _isLetterDigitHyphenOrUnderscore(int codeUnit) =>
    _isLetterOrDigit(codeUnit) ||
    // Hyphen.
    codeUnit == 45 ||
    // Underscore.
    codeUnit == 95;
