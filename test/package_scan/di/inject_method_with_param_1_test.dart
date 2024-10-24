@TestOn('vm')
library;

import 'package:test/test.dart';

import '../../../bin/winter.dart';

//NOTE: the '_1' in name represent the param passed as a positioned argument withOUT @Injected
@Injectable(tag: 'test')
String foo(String hw) {
  return 'injectable text in $hw';
}

void main() {
  test('@Injectable on method with positioned argument (without @Injected)',
      () async {
    DependencyInjection di = DependencyInjection.build();

    di.put('Hello world', tag: 'hw');

    PackageScanner scanner =
        PackageScanner(context: BuildContext(dependencyInjection: di));

    String scannedAbc =
        scanner.context.dependencyInjection.find<String>(tag: 'test');

    expect(
      foo('Hello world'),
      scannedAbc,
    );

    expect(scanner.summary.length, 1);

    expect(scanner.summary.first.type, ComponentType.method);
    expect(scanner.summary.first.name, 'foo');
    expect(scanner.summary.first.library, '');
    expect(scanner.summary.first.processedAs, ProcessedAs.injectable);
  });
}
