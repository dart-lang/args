// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math' as math;

import '../args.dart';

/// Takes an [ArgParser] and generates a string of usage (i.e. help) text for
/// its defined options.
///
/// Internally, it works like a tabular printer. The output is divided into
/// three horizontal columns, like so:
///
///     -h, --help  Prints the usage information
///     |  |        |                                 |
///
/// It builds the usage text up one column at a time and handles padding with
/// spaces and wrapping to the next line to keep the cells correctly lined up.
class Usage {
  /// Abbreviation, long name, help.
  static const _columnCount = 3;

  /// A list of the [Option]s intermingled with [String] separators.
  final List optionsAndSeparators;

  /// The working buffer for the generated usage text.
  StringBuffer buffer;

  /// The column that the "cursor" is currently on.
  ///
  /// If the next call to [write()] is not for this column, it will correctly
  /// handle advancing to the next column (and possibly the next row).
  int currentColumn = 0;

  /// The width in characters of each column.
  List<int> columnWidths;

  /// The number of sequential lines of text that have been written to the last
  /// column (which shows help info).
  ///
  /// We track this so that help text that spans multiple lines can be padded
  /// with a blank line after it for separation. Meanwhile, sequential options
  /// with single-line help will be compacted next to each other.
  int numHelpLines = 0;

  /// How many newlines need to be rendered before the next bit of text can be
  /// written.
  ///
  /// We do this lazily so that the last bit of usage doesn't have dangling
  /// newlines. We only write newlines right *before* we write some real
  /// content.
  int newlinesNeeded = 0;

  /// The horizontal character position at which help text is wrapped. Help that
  /// extends past this column will be wrapped at the nearest whitespace (or
  /// truncated if there is no available whitespace).
  final int lineLength;

  Usage(this.optionsAndSeparators, {this.lineLength});

  /// Generates a string displaying usage information for the defined options.
  /// This is basically the help text shown on the command line.
  String generate() {
    buffer = new StringBuffer();

    calculateColumnWidths();

    for (var optionOrSeparator in optionsAndSeparators) {
      if (optionOrSeparator is String) {
        // Ensure that there's always a blank line before a separator.
        if (buffer.isNotEmpty) buffer.write("\n\n");
        buffer.write(optionOrSeparator);
        newlinesNeeded = 1;
        continue;
      }

      var option = optionOrSeparator as Option;
      if (option.hide) continue;

      write(0, getAbbreviation(option));
      write(1, getLongOption(option));

      if (option.help != null) write(2, option.help);

      if (option.allowedHelp != null) {
        var allowedNames = option.allowedHelp.keys.toList(growable: false);
        allowedNames.sort();
        newline();
        for (var name in allowedNames) {
          write(1, getAllowedTitle(option, name));
          write(2, option.allowedHelp[name]);
        }
        newline();
      } else if (option.allowed != null) {
        write(2, buildAllowedList(option));
      } else if (option.isFlag) {
        if (option.defaultsTo == true) {
          write(2, '(defaults to on)');
        }
      } else if (option.isMultiple) {
        if (option.defaultsTo != null && option.defaultsTo.isNotEmpty) {
          write(
              2,
              '(defaults to ' +
                  option.defaultsTo.map((value) => '"$value"').join(', ') +
                  ')');
        }
      } else {
        if (option.defaultsTo != null) {
          write(2, '(defaults to "${option.defaultsTo}")');
        }
      }

      // If any given option displays more than one line of text on the right
      // column (i.e. help, default value, allowed options, etc.) then put a
      // blank line after it. This gives space where it's useful while still
      // keeping simple one-line options clumped together.
      if (numHelpLines > 1) newline();
    }

    return buffer.toString();
  }

  String getAbbreviation(Option option) =>
      option.abbr == null ? '' : '-${option.abbr}, ';

  String getLongOption(Option option) {
    var result;
    if (option.negatable) {
      result = '--[no-]${option.name}';
    } else {
      result = '--${option.name}';
    }

    if (option.valueHelp != null) result += "=<${option.valueHelp}>";

    return result;
  }

  String getAllowedTitle(Option option, String allowed) {
    var isDefault = option.defaultsTo is List
        ? option.defaultsTo.contains(allowed)
        : option.defaultsTo == allowed;
    return '      [$allowed]' + (isDefault ? ' (default)' : '');
  }

  void calculateColumnWidths() {
    var abbr = 0;
    var title = 0;
    for (var option in optionsAndSeparators) {
      if (option is! Option) continue;
      if (option.hide) continue;

      // Make room in the first column if there are abbreviations.
      abbr = math.max(abbr, getAbbreviation(option).length);

      // Make room for the option.
      title = math.max(title, getLongOption(option).length);

      // Make room for the allowed help.
      if (option.allowedHelp != null) {
        for (var allowed in option.allowedHelp.keys) {
          title = math.max(title, getAllowedTitle(option, allowed).length);
        }
      }
    }

    // Leave a gutter between the columns.
    title += 4;
    columnWidths = [abbr, title];
  }

  void newline() {
    newlinesNeeded++;
    currentColumn = 0;
    numHelpLines = 0;
  }

  /// Wraps a single line of text into lines no longer than [lineLength],
  /// starting at the [start] column.
  ///
  /// Tries to split at whitespace, but if that's not good enough to keep it
  /// under the limit, then splits in the middle of a word.
  List<String> _wrap(String text, int start) {
    assert(lineLength != null, "Should wrap when given a length.");
    assert(start >= 0);

    text = text.trim();

    var length = math.max(lineLength - start, 10);
    if (text.length <= length) return [text];

    var result = <String>[];
    var currentLineStart = 0;
    int lastWhitespace;
    for (var i = 0; i < text.length; ++i) {
      if (_isWhitespace(text, i)) lastWhitespace = i;

      if (i - currentLineStart >= length) {
        // Back up to the last whitespace, unless there wasn't any, in which
        // case we just split where we are.
        if (lastWhitespace != null) i = lastWhitespace;

        result.add(text.substring(currentLineStart, i));

        // Skip any intervening whitespace.
        while (_isWhitespace(text, i) && i < text.length) i++;

        currentLineStart = i;
        lastWhitespace = null;
      }
    }

    result.add(text.substring(currentLineStart));
    return result;
  }

  void write(int column, String text) {
    var lines = text.split('\n');
    // If we are writing the last column, word wrap it to fit.
    if (column == columnWidths.length && lineLength != null) {
      var wrappedLines = <String>[];
      var start = columnWidths
          .sublist(0, column)
          .reduce((start, width) => start += width);

      for (var line in lines) {
        wrappedLines.addAll(_wrap(line, start));
      }

      lines = wrappedLines;
    }

    // Strip leading and trailing empty lines.
    while (lines.length > 0 && lines[0].trim() == '') {
      lines.removeRange(0, 1);
    }

    while (lines.length > 0 && lines[lines.length - 1].trim() == '') {
      lines.removeLast();
    }

    for (var line in lines) {
      writeLine(column, line);
    }
  }

  void writeLine(int column, String text) {
    // Write any pending newlines.
    while (newlinesNeeded > 0) {
      buffer.write('\n');
      newlinesNeeded--;
    }

    // Advance until we are at the right column (which may mean wrapping around
    // to the next line.
    while (currentColumn != column) {
      if (currentColumn < _columnCount - 1) {
        buffer.write(' ' * columnWidths[currentColumn]);
      } else {
        buffer.write('\n');
      }
      currentColumn = (currentColumn + 1) % _columnCount;
    }

    if (column < columnWidths.length) {
      // Fixed-size column, so pad it.
      buffer.write(text.padRight(columnWidths[column]));
    } else {
      // The last column, so just write it.
      buffer.write(text);
    }

    // Advance to the next column.
    currentColumn = (currentColumn + 1) % _columnCount;

    // If we reached the last column, we need to wrap to the next line.
    if (column == _columnCount - 1) newlinesNeeded++;

    // Keep track of how many consecutive lines we've written in the last
    // column.
    if (column == _columnCount - 1) {
      numHelpLines++;
    } else {
      numHelpLines = 0;
    }
  }

  String buildAllowedList(Option option) {
    var isDefault = option.defaultsTo is List
        ? option.defaultsTo.contains
        : (value) => value == option.defaultsTo;

    var allowedBuffer = new StringBuffer();
    allowedBuffer.write('[');
    var first = true;
    for (var allowed in option.allowed) {
      if (!first) allowedBuffer.write(', ');
      allowedBuffer.write(allowed);
      if (isDefault(allowed)) {
        allowedBuffer.write(' (default)');
      }
      first = false;
    }
    allowedBuffer.write(']');
    return allowedBuffer.toString();
  }
}

/// Returns true if the code unit at [index] in [text] is a whitespace
/// character.
///
/// Based on: https://en.wikipedia.org/wiki/Whitespace_character#Unicode
bool _isWhitespace(String text, int index) {
  var rune = text.codeUnitAt(index);
  return rune >= 0x0009 && rune <= 0x000D ||
      rune == 0x0020 ||
      rune == 0x0085 ||
      rune == 0x1680 ||
      rune == 0x180E ||
      rune >= 0x2000 && rune <= 0x200A ||
      rune == 0x2028 ||
      rune == 0x2029 ||
      rune == 0x202F ||
      rune == 0x205F ||
      rune == 0x3000 ||
      rune == 0xFEFF;
}
