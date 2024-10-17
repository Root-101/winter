import '../../winter/winter.dart';

void main() {
  Winter.run(
    config: ServerConfig(port: 9090),
    router: ServeRouter((request) => ResponseEntity.ok(body: 'Hello world!!!')),
  );
}
