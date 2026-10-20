import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// `Prefer` and `Preference-Applied` (RFC 7240)
void main() {
  group('Preferences.parse', () {
    test('the preferences of RFC 7240, with their typed getters', () {
      final preferences = Preferences.parse([
        'return=minimal, respond-async; wait=10',
        'handling=Lenient',
      ]);

      expect(preferences.returns, 'minimal');
      expect(preferences.respondAsync, isTrue);
      expect(preferences.handling, 'lenient');
      expect(preferences.all.keys, ['return', 'respond-async', 'handling']);
      // A parameter of a preference is not a preference of its own
      expect(preferences.wait, isNull);
      expect(preferences.all['respond-async']!.params, {'wait': '10'});
      expect(Preferences.parse(['wait=10']).wait, const Duration(seconds: 10));
    });

    test('names are case insensitive and the first one of a name wins', () {
      final preferences = Preferences.parse([
        'Return=representation',
        'return=minimal',
      ]);

      expect(preferences.returns, 'representation');
      expect(preferences.has('RETURN'), isTrue);
    });

    test('a quoted value, with a comma and an escape inside', () {
      final preferences = Preferences.parse([r'foo="a, \"b\"; c", bar']);

      expect(preferences['foo'], 'a, "b"; c');
      expect(preferences.has('bar'), isTrue);
      expect(preferences['bar'], isNull);
    });

    test('a malformed part is skipped, and so is a wait that is not seconds', () {
      final preferences = Preferences.parse([
        'bad name=1, =x, , ok, wait=soon',
      ]);

      expect(preferences.all.keys, ['ok', 'wait']);
      // A huge header (hostile, never a real one) is ignored without parsing it
      expect(
        Preferences.parse([
          'respond-async, ${List.filled(2000, 'p=v').join(',')}',
          'return=minimal',
        ]).all.keys,
        ['return'],
      );
      expect(preferences.wait, isNull);
      expect(Preferences.parse(['wait=-1']).wait, isNull);
      expect(Preferences.none.returns, isNull);
      expect(Preferences.none.respondAsync, isFalse);
    });
  });

  group('In a request', () {
    final client = WinterTestClient.build(
      router: WinterRouter(
        routes: [
          Route.post(
            path: '/notes',
            handler: (request) => request.preferences.returns == 'minimal'
                ? ResponseEntity.created(
                    location: '/notes/1',
                    headers: {HttpHeader.preferenceApplied: 'return=minimal'},
                  )
                : ResponseEntity.created(location: '/notes/1', body: {'id': 1}),
          ),
          Route.get(path: '/plain', handler: (r) => ResponseEntity.ok()),
        ],
      ),
    );

    test('a handler honors return=minimal, and says so', () async {
      final minimal = await client.post(
        '/notes',
        headers: {HttpHeader.prefer: 'return=minimal'},
      );
      final full = await client.post('/notes');

      expect(minimal.body, isEmpty);
      expect(minimal.headers['preference-applied'], 'return=minimal');
      expect(full.json, {'id': 1});
      expect(full.headers, isNot(contains('preference-applied')));
    });

    test(
      'reading the preferences adds Vary: Prefer, with or without them',
      () async {
        final withPrefer = await client.post(
          '/notes',
          headers: {HttpHeader.prefer: 'return=minimal'},
        );
        final without = await client.post('/notes');
        final plain = await client.get(
          '/plain',
          headers: {HttpHeader.prefer: 'return=minimal'},
        );

        expect(withPrefer.headers['vary'], contains('Prefer'));
        expect(without.headers['vary'], contains('Prefer'));
        expect(plain.headers['vary'], isNull);
      },
    );
  });
}
