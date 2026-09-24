bool isValidUri(String path) {
  // Try to create an Uri with only the path
  try {
    String escapedPath = path
        .replaceAll('{', '%7B')
        .replaceAll('}', '%7D')
        .replaceAll('|', '%7C');

    Uri uri = Uri(path: escapedPath);
    // The path must not contain invalid characters nor start with "//"
    return !path.startsWith('//') && uri.path == escapedPath;
  } catch (e) {
    return false;
  }
}
