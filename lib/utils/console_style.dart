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
  /// Aplica estilos ANSI a este String (Negrita y/or Color)
  String stylize({bool bold = false, ConsoleColor? color}) {
    if (!bold && color == null) return this;

    final List<int> codes = [];

    if (bold) codes.add(1);
    if (color != null) codes.add(color.code);

    final String ansiSequence = codes.join(';');

    // 'this' hace referencia al String original sobre el que aplicas la extensión
    return '\x1B[${ansiSequence}m$this\x1B[0m';
  }
}
