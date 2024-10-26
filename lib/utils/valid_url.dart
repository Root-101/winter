bool isValidUri(String path) {
  // Intenta crear un objeto Uri con solo el path
  try {
    path = path.replaceAll('{', '%7B');
    path = path.replaceAll('}', '%7D');
    Uri uri = Uri(path: path);
    // Valida que el path no contenga caracteres no permitidos y que no comience con "//"
    return !path.startsWith('//') && uri.path == path;
  } catch (e) {
    return false;
  }
}
