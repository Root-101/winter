import 'package:test/test.dart';

import '../../../bin/winter/winter.dart';

@Injectable(tag: 'test')
const String foo = 'Hello world!!!';

void main() {
  test('@Injectable on variable', () async {
    PackageScanner scanner = PackageScanner();

    String scannedAbc =
        scanner.context.dependencyInjection.find<String>(tag: 'test');

    expect(foo, scannedAbc);

    expect(scanner.summary.length, 1);

    expect(scanner.summary.first.type, ComponentType.variable);
    expect(scanner.summary.first.name, 'foo');
    expect(scanner.summary.first.library, '');
    expect(scanner.summary.first.processedAs, ProcessedAs.injectable);
  });
}
