import '../../bin/winter.dart';

void main() => Winter.run(
      router:
          ServeRouter((request) => ResponseEntity.ok(body: 'Hello world!!!')),
    );
