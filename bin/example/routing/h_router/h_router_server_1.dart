import '../../../winter/winter.dart';

void main() async {
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
          ]),
    ],
  );

  await Winter.run(
    config: ServerConfig(port: 8080),
    router: router,
  );
}
