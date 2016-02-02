## 0.13.3+1

* Print all lines of multi-line command descriptions.

## 0.13.2

* Allow option values that look like options. This more closely matches the
  behavior of [`getopt`][getopt], the *de facto* standard for option parsing.

[getopt]: http://man7.org/linux/man-pages/man3/getopt.3.html

## 0.13.1

* Add `ArgParser.addSeparator()`. Separators allow users to group their options
  in the usage text.

## 0.13.0

* **Breaking change**: An option that allows multiple values will now
  automatically split apart comma-separated values. This can be controlled with
  the `splitCommas` option.

## 0.12.2+6

* Remove the dependency on the `collection` package.

## 0.12.2+5

* Add syntax highlighting to the README.

## 0.12.2+4

* Add an example of using command-line arguments to the README.

## 0.12.2+3

* Fixed implementation of ArgResults.options to really use Iterable<String>
  instead of Iterable<dynamic> cast to Iterable<String>.

## 0.12.2+2

* Updated dependency constraint on `unittest`.

* Formatted source code.

* Fixed use of deprecated API in example.

## 0.12.2+1

* Fix the built-in `help` command for `CommandRunner`.

## 0.12.2

* Add `CommandRunner` and `Command` classes which make it easy to build a
  command-based command-line application.

* Add an `ArgResults.arguments` field, which contains the original argument list.

## 0.12.1

* Replace `ArgParser.getUsage()` with `ArgParser.usage`, a getter.
  `ArgParser.getUsage()` is now deprecated, to be removed in args version 1.0.0.

## 0.12.0+2

* Widen the version constraint on the `collection` package.

## 0.12.0+1

* Remove the documentation link from the pubspec so this is linked to
  pub.dartlang.org by default.

## 0.12.0

* Removed public constructors for `ArgResults` and `Option`.
 
* `ArgResults.wasParsed()` can be used to determine if an option was actually
  parsed or the default value is being returned.

* Replaced `isFlag` and `allowMultiple` fields in the `Option` class with a
  three-value `OptionType` enum.
  
* Options may define `valueHelp` which will then be shown in the usage.

## 0.11.0

* Move handling trailing options from `ArgParser.parse()` into `ArgParser`
  itself. This lets subcommands have different behavior for how they handle
  trailing options.

## 0.10.0+2

* Usage ignores hidden options when determining column widths.
