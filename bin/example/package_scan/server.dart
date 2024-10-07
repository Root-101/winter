import '../../winter/winter.dart';

import 'package_scan.dart';

void main() {
  PackageScanner scanner = PackageScanner();

  WinterServer(
    config: ServerConfig(port: 8080),
    router: scanner.router,
  ).start();
}
