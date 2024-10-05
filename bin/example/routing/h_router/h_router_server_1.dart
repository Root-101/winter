import '../../../winter/winter.dart';

void main() {
  final router = HRouter(
    routes: [
      HRoute(
        path: '/test',
        method: HttpMethod.get,
        handler: (request) => ResponseEntity.ok(body: 'hello-world'),
        routes: [
          HRoute(
            path: '/abc',
            method: HttpMethod('abc'), //custom http-method
            handler: (request) => ResponseEntity.ok(body: 'hello-abc-world'),
          ),
        ]
      ),
    ],
  );

  WinterServer(
    config: ServerConfig(port: 8080),
    router: router,
  ).start();
}
