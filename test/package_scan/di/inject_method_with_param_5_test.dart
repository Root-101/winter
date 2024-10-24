@TestOn('vm')
library;

import 'package:test/test.dart';

import '../../../bin/winter.dart';

//NOTE: the '_5' in name represent that a param is passed as a positioned argument with @Injected
//and another as named argument without @Injected and a default value (in this case this default value will be used)
@Injectable()
String foo(
  @Injected(tag: '1') String hw, {
  @Injected(tag: '2') String? anotherParam = 'hi',
}) {
  return 'injectable text in $hw and another: $anotherParam';
}

void main() {
  test(
      '@Injectable on method with positioned and named arguments (using default value on named)',
      () async {
    DependencyInjection di = DependencyInjection.build();

    di.put('Hello world', tag: '1');

    PackageScanner scanner =
        PackageScanner(context: BuildContext(dependencyInjection: di));

    String scannedAbc = scanner.context.dependencyInjection.find<String>();

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

  test(
      '@Injectable on method with positioned and named arguments (ignoring default value)',
      () async {
    DependencyInjection di = DependencyInjection.build();

    di.put('Hello world', tag: '1');
    di.put('Hi World from tag #2', tag: '2');

    PackageScanner scanner =
        PackageScanner(context: BuildContext(dependencyInjection: di));

    String scannedAbc = scanner.context.dependencyInjection.find<String>();

    expect(
      foo('Hello world', anotherParam: 'Hi World from tag #2'),
      scannedAbc,
    );

    expect(scanner.summary.length, 1);

    expect(scanner.summary.first.type, ComponentType.method);
    expect(scanner.summary.first.name, 'foo');
    expect(scanner.summary.first.library, '');
    expect(scanner.summary.first.processedAs, ProcessedAs.injectable);
  });
}
