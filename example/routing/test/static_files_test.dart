import 'package:routing_examples/static_files.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  test(
    'the index of the folder, its files, and the API next to them',
    () async {
      final index = await client.get('/');
      final css = await client.get('/style.css');

      expect(index.headers['content-type'], 'text/html; charset=utf-8');
      expect(index.body, contains('Route.static'));
      expect(css.headers['content-type'], 'text/css; charset=utf-8');
      expect(css.headers['cache-control'], 'public, max-age=60');
      expect((await client.get('/api/time')).statusCode, 200);
    },
  );

  test('304 with the ETag, a range, and nothing outside the folder', () async {
    final first = await client.get('/style.css');
    final notModified = await client.get(
      '/style.css',
      headers: {'If-None-Match': first.headers['etag']!},
    );
    final range = await client.get(
      '/style.css',
      headers: {'Range': 'bytes=0-3'},
    );

    expect(notModified.statusCode, 304);
    expect(range.statusCode, 206);
    expect(range.body, 'body');
    expect((await client.get('/%2e%2e/pubspec.yaml')).statusCode, 404);
  });
}
