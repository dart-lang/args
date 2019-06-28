// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import '../command_runner.dart';
import 'utils.dart';

/// The built-in help command that's added to every [CommandRunner].
///
/// This command displays help information for the various subcommands.
class HelpCommand<T> extends Command<T> {
  HelpCommand() {
    argParser.addFlag('all',
        abbr: 'a',
        defaultsTo: false,
        negatable: false,
        help: 'Output help for every command and subcommand.');
    argParser.addOption('output',
        abbr: 'o',
        help: 'When --split is given, the output directory. '
            'When --split is not given, the output file.',
        valueHelp: 'OUTPUT');
    argParser.addFlag('split',
        abbr: 's',
        defaultsTo: false,
        negatable: false,
        help:
            'Split help output by subcommand into files written to --output.');
  }

  @override
  final name = "help";

  @override
  String get description =>
      "Display help information for ${runner.executableName}.";

  @override
  String get invocation => "${runner.executableName} help [command]";

  @override
  Future<T> run() async {
    // help --all prints all help text.
    if (argResults['all']) {
      await _outputAllHelp();
      return null;
    }

    // Show the default help if no command was specified.
    if (argResults.rest.isEmpty) {
      runner.printUsage();
      return null;
    }

    // Walk the command tree to show help for the selected command or
    // subcommand.
    var commands = runner.commands;
    Command command;
    var commandString = runner.executableName;

    for (var name in argResults.rest) {
      if (commands.isEmpty) {
        command.usageException(
            'Command "$commandString" does not expect a subcommand.');
      }

      if (commands[name] == null) {
        if (command == null) {
          runner.usageException('Could not find a command named "$name".');
        }

        command.usageException(
            'Could not find a subcommand named "$name" for "$commandString".');
      }

      command = commands[name];
      commands = command.subcommands;
      commandString += " $name";
    }

    command.printUsage();
    return null;
  }

  // Outputs all help text as designated by the flags --split and --output.
  Future<void> _outputAllHelp() async {
    final bool split = argResults['split'];
    final String output = argResults['output'] ?? (split ? '.' : null);

    if (split) {
      Directory(output).createSync(recursive: true);
    }

    IOSink outSink;
    try {
      if (!split) {
        outSink = output == null ? PrintIOSink() : File(output).openWrite();
      }
      for (List<String> helpText in _helpMessages) {
        if (split) {
          await outSink?.flush();
          await outSink?.close();
          final String helpFile =
              '$output${Platform.pathSeparator}${helpText[0]}.txt';
          outSink = File(helpFile).openWrite();
        }
        outSink.write(helpText[1]);
      }
    } finally {
      if (outSink != stdout) {
        await outSink?.flush();
        await outSink?.close();
      }
    }
  }

  String _subcommandChain(Command command) {
    List<String> parents = <String>[command.name];
    for (Command c = command.parent; c != null; c = c.parent) {
      parents.add(c.name);
    }
    return parents.reversed.join("_");
  }

  // Walks the subcommand tree, yielding all help text.
  Iterable<List<String>> get _helpMessages sync* {
    yield <String>[runner.executableName, '${runner.usage}\n'];
    final Iterable<MapEntry<String, Command>> topLevelCommands =
        runner.commands?.entries;
    if (topLevelCommands == null) {
      return;
    }
    final List<MapEntry<String, Command>> commandStack =
        List<MapEntry<String, Command>>.from(topLevelCommands);
    while (commandStack.isNotEmpty) {
      final MapEntry<String, Command> command = commandStack.removeAt(0);
      if (command.value.subcommands != null) {
        commandStack.insertAll(0, command.value.subcommands.entries);
      }
      yield <String>[
        _subcommandChain(command.value),
        wrapText('Command: ${command.key}\n${command.value.usage}\n',
            length: argParser.usageLineLength)
      ];
    }
  }
}
