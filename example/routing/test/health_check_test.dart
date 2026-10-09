import 'package:routing_examples/health_check.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  test(
    'readiness is a 503 when the database is down; liveness is not',
    () async {
      final database = Database();
      final client = WinterTestClient.build(router: router(database));

      expect((await client.get('/readyz')).json, {
        'status': 'UP',
        'checks': {'database': 'UP'},
      });

      database.up = false;
      final ready = await client.get('/readyz');

      expect(ready.statusCode, 503);
      expect(ready.json, {
        'status': 'DOWN',
        'checks': {'database': 'DOWN'},
      });
      expect((await client.get('/livez')).statusCode, 200);
    },
  );
}
