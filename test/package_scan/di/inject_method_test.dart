@TestOn('vm')
library;

import 'package:test/test.dart';

import '../../../bin/winter/winter.dart';

@Injectable(tag: 'test')
String foo() {
  return 'injectable text';
}

void main() {
  test('@Injectable on method', () async {
    PackageScanner scanner = PackageScanner();

    String scannedAbc =
        scanner.context.dependencyInjection.find<String>(tag: 'test');

    expect(foo(), scannedAbc);

    expect(scanner.summary.length, 1);

    expect(scanner.summary.first.type, ComponentType.method);
    expect(scanner.summary.first.name, 'foo');
    expect(scanner.summary.first.library, '');
    expect(scanner.summary.first.processedAs, ProcessedAs.injectable);
  });
}
