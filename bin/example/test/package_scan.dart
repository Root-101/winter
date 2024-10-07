import 'dart:async';

import '../../winter/winter.dart';

void main() {
  PackageScanner scanner = PackageScanner();

  WinterServer(
    config: ServerConfig(port: 8080),
    router: scanner.router,
  ).start();
}
