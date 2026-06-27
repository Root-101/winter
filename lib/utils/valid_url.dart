bool isValidUri(String path) {
  // Intenta crear un objeto Uri con solo el path
  try {
    String escapedPath = path.replaceAll('{', '%7B')
        .replaceAll('}', '%7D')
        .replaceAll('|', '%7C');

    Uri uri = Uri(path: escapedPath);
    // Valida que el path no contenga caracteres no permitidos y que no comience con "//"
    return !path.startsWith('//') && uri.path == escapedPath;
  } catch (e) {
    return false;
  }
}
