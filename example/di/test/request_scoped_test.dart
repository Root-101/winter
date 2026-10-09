import 'package:di_examples/request_scoped.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  late AuditSink sink;
  final client = WinterTestClient.build(
    globalFilterConfig: globalFilters,
    router: router(),
  );

  setUp(() {
    Winter.context.setUp(dependencyInjection: DependencyInjection());
    sink = AuditSink();
    registerDependencies(sink);
  });

  test('one trail per request, written when it ends', () async {
    await client.delete('/documents/7', headers: {'x-user': 'ann'});

    expect(sink.lines, ['ann: delete document 7, delete attachments of 7']);
  });

  test('two requests at the same time never mix their trails', () async {
    await Future.wait([
      client.delete('/documents/1', headers: {'x-user': 'ann'}),
      client.delete('/documents/2', headers: {'x-user': 'bob'}),
    ]);

    expect(
      sink.lines,
      unorderedEquals([
        'ann: delete document 1, delete attachments of 1',
        'bob: delete document 2, delete attachments of 2',
      ]),
    );
  });

  test('outside a request there is no trail to find', () {
    expect(() => di.find<AuditTrail>(), throwsStateError);
  });
}
