@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../../../bin/winter/winter.dart';

void main() {
  int port = 9090;
  String url = 'http://localhost:$port';

  String body = 'Hello world!!!';
  setUp(() async {
    await Winter.run(
      config: ServerConfig(port: port),
      router: ServeRouter((request) => ResponseEntity.ok(body: body)),
    );
  });

  tearDown(() => Winter.close(force: true));

  Future<String> get(String path) => http.read(Uri.parse(url + path));

  test('Test serve router', () async {
    expect(await get('/anything'), body);
    expect(await get('/anything-1'), body);
    expect(await get('/abc'), body);
    expect(await get('/123'), body);
    expect(await get('/abracadabra'), body);
    expect(await get('/full-stack-badass'), body);
  });
}
