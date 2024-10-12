import '../../winter/winter.dart';

import 'package_scan.dart';

void main() {
  PackageScanner scanner = PackageScanner();

  WinterServer(
    config: ServerConfig(port: 9090),
    router: scanner.router,
  ).start();
}
