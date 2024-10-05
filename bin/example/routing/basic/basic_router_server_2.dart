import '../../../winter/winter.dart';

void main() {
  final router = BasicRouter()
    ..get('/test', (request) => ResponseEntity.ok(body: 'hello-world'))
    ..add('/other', HttpMethod('other'),
        (request) => ResponseEntity.ok(body: 'hello-other-world'));

  WinterServer(
    config: ServerConfig(port: 8080),
    router: router,
  ).start();
}
