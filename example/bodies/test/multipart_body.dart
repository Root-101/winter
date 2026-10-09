/// A multipart/form-data body for the tests: [fields] and [files] (field, filename, type, content)
(String contentType, String body) multipartBody({
  Map<String, String> fields = const {},
  List<(String, String, String, String)> files = const [],
}) {
  const String boundary = 'example-boundary';
  final StringBuffer body = StringBuffer();
  for (final MapEntry(:key, :value) in fields.entries) {
    body.write(
      '--$boundary\r\nContent-Disposition: form-data; name="$key"\r\n\r\n$value\r\n',
    );
  }
  for (final (String field, String filename, String type, String content)
      in files) {
    body.write(
      '--$boundary\r\nContent-Disposition: form-data; name="$field"; filename="$filename"\r\n'
      'Content-Type: $type\r\n\r\n$content\r\n',
    );
  }
  body.write('--$boundary--\r\n');
  return ('multipart/form-data; boundary=$boundary', body.toString());
}
