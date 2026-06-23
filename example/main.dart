import 'package:winter/winter.dart';

void main() => Winter.start(
  router: ServeRouter((request) => ResponseEntity.ok(body: 'Hello world!!!')),
);
