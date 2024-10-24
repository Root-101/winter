@TestOn('vm')
library;

import 'package:test/test.dart';

import '../../../bin/winter.dart';

//NOTE: the '_4' in name represent the a param is passed as a positioned argument
//and another as named argument, both with @Injected
@Injectable()
String foo(
  @Injected(tag: '1') String hw, {
  @Injected(tag: '2') String? anotherParam,
}) {
  return 'injectable text in $hw and another: $anotherParam';
}

void main() {
  test(
      '@Injectable on method with positioned and named arguments (with @Injected)',
      () async {
    DependencyInjection di = DependencyInjection.build();

    di.put('Hello world', tag: '1');
    di.put('Hello world number 2', tag: '2');

    PackageScanner scanner =
        PackageScanner(context: BuildContext(dependencyInjection: di));

    String scannedAbc = scanner.context.dependencyInjection.find<String>();

    expect(
      foo('Hello world', anotherParam: 'Hello world number 2'),
      scannedAbc,
    );

    expect(scanner.summary.length, 1);

    expect(scanner.summary.first.type, ComponentType.method);
    expect(scanner.summary.first.name, 'foo');
    expect(scanner.summary.first.library, '');
    expect(scanner.summary.first.processedAs, ProcessedAs.injectable);
  });
}
