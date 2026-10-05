enum ConsoleColor {
  black(30),
  red(31),
  green(32),
  yellow(33),
  blue(34),
  magenta(35),
  cyan(36),
  white(37);

  final int code;

  const ConsoleColor(this.code);
}

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
