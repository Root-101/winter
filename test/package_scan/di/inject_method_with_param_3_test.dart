@TestOn('vm')
library;

import 'package:test/test.dart';

import '../../../bin/winter/winter.dart';

//NOTE: the '_3' in name represent the a param is passed as a positioned argument
//and another as named argument, both withOUT @Injected
@Injectable()
String foo(String hw, {String? anotherParam}) {
  return 'injectable text in $hw and another: $anotherParam';
}

void main() {
  test(
      '@Injectable on method with positioned and named arguments (without @Injected)',
      () async {
    DependencyInjection di = DependencyInjection.build();

    di.put('Hello world', tag: 'hw');
    di.put('Hello world number 2', tag: 'anotherParam');

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
