/// Whether [path] is a valid route path: its literal parts must be a valid url path, and it can't
/// start with `//`. The params (`{id}`, `{id|[0-9]+}`) and the regex characters (`.*`, `[a-z]+`)
/// can have any character.
bool isValidUri(String path) {
  if (path.startsWith('//')) return false;

  final String literal = path
      .replaceAll(_paramPattern, 'p')
      .replaceAll(_regexCharacters, 'x');
  try {
    return Uri(path: literal).path == literal;
  } catch (e) {
    return false;
  }
}

final RegExp _paramPattern = RegExp(r'{[^}]*}');

final RegExp _regexCharacters = RegExp(r'[*+?()\[\]|\\^$]');
