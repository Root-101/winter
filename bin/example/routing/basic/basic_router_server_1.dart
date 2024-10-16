import '../../../winter/winter.dart';

void main() {
  final router = BasicRouter(
    routes: [
      Route(
        path: '/test',
        method: HttpMethod.get,
        handler: (request) => ResponseEntity.ok(body: 'hello-world'),
      ),
      Route(
        path: '/other',
        method: HttpMethod('other'), //custom http-method
        handler: (request) => ResponseEntity.ok(body: 'hello-other-world'),
      ),
    ],
  );

  Winter.run(
    config: ServerConfig(port: 8080),
    router: router,
  );
}
