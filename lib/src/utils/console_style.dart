/// The ANSI colors of a terminal, for the logs of the console. Internal.
enum ConsoleColor {
  /// Black
  black(30),

  /// Red
  red(31),

  /// Green
  green(32),

  /// Yellow
  yellow(33),

  /// Blue
  blue(34),

  /// Magenta
  magenta(35),

  /// Cyan
  cyan(36),

  /// White
  white(37);

  /// The ANSI code of the color
  final int code;

  const ConsoleColor(this.code);
}

/// ANSI styles for a text of the console. Internal.
extension ConsoleStyleExtension on String {
  /// Apply ANSI styles (bold and/or color) to this String
  String stylize({bool bold = false, ConsoleColor? color}) {
    if (!bold && color == null) return this;

    final List<int> codes = [];

    if (bold) codes.add(1);
    if (color != null) codes.add(color.code);

    final String ansiSequence = codes.join(';');

    // 'this' is the original String the extension is applied to
    return '\x1B[${ansiSequence}m$this\x1B[0m';
  }
}
