import 'dart:io';

import 'package:bodies_examples/streaming_upload.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

import 'multipart_body.dart';

void main() {
  late Directory directory;

  setUp(
    () async => directory = await Directory.systemTemp.createTemp('uploads'),
  );

  tearDown(() => directory.delete(recursive: true));

  test('each file goes to disk with a name of its own', () async {
    final client = WinterTestClient.build(router: router(directory: directory));
    final (String type, String body) = multipartBody(
      fields: {'title': 'Talk'},
      files: [('file', '../../etc/passwd', 'video/mp4', 'not really a video')],
    );

    final response = await client.post(
      '/uploads',
      body: body,
      headers: {HttpHeader.contentType: type},
    );

    expect(response.json, {
      'fields': {'title': 'Talk'},
      'files': [
        {'field': 'file', 'savedAs': 'upload-1', 'bytes': 18},
      ],
    });
    expect(
      await File('${directory.path}/upload-1').readAsString(),
      'not really a video',
    );
  });
}
