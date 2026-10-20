/// ANSI styles for a text of the console. Internal.
extension ConsoleStyleExtension on String {
  /// This text in bold, for a terminal
  String get bold => '\x1B[1m$this\x1B[0m';
}
