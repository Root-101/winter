import 'package:routing_examples/health_check.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  test(
    'readiness is a 503 when the database is down; liveness is not',
    () async {
      final database = Database();
      final client = WinterTestClient.build(router: router(database));

      final ok = await client.get('/readyz');
      expect(ok.headers['content-type'], startsWith('application/health+json'));
      expect(ok.json, {
        'status': 'pass',
        'checks': {
          'database': [
            {'status': 'pass'},
          ],
        },
      });

      database.up = false;
      final ready = await client.get('/readyz');

      expect(ready.statusCode, 503);
      expect(ready.json, {
        'status': 'fail',
        'checks': {
          'database': [
            {'status': 'fail'},
          ],
        },
      });
      expect((await client.get('/livez')).statusCode, 200);
    },
  );
}
