import 'dart:convert';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

enum _Plan { free, pro }

void main() {
  const String form = 'application/x-www-form-urlencoded';

  /// Answers the form as JSON: every field with all its values
  Future<TestResponse> post(
    String body, {
    String? contentType = form,
    int? maxBodySize,
    ResponseEntity Function(FormData form)? answer,
  }) {
    final client = WinterTestClient.build(
      maxBodySize: maxBodySize,
      router: WinterRouter(
        routes: [
          Route.post(
            path: '/form',
            handler: (request) async {
              final FormData data = await request.formData();
              return answer?.call(data) ??
                  ResponseEntity.ok(body: data.fieldsAll);
            },
          ),
        ],
      ),
    );
    return client.post(
      '/form',
      body: body,
      headers: {HttpHeader.contentType: ?contentType},
    );
  }

  Map<String, Object?> json(TestResponse response) =>
      jsonDecode(response.body) as Map<String, Object?>;

  group('formData()', () {
    test(
      'decodes the fields: + is a space, and the percent-encoding',
      () async {
        final response = await post(
          'name=Ann+Lee&city=M%C3%A1laga&a%26b=1%3D2',
        );

        expect(response.statusCode, 200);
        expect(json(response), {
          'name': ['Ann Lee'],
          'city': ['Málaga'],
          'a&b': ['1=2'],
        });
      },
    );

    test('keeps every value of a repeated field, in order', () async {
      final response = await post(
        'tag=a&tag=b&tag=c',
        answer: (form) => ResponseEntity.ok(
          body: {'last': form['tag'], 'all': form.fieldsAll['tag']},
        ),
      );

      expect(json(response), {
        'last': 'c',
        'all': ['a', 'b', 'c'],
      });
    });

    test('a field without = is empty, and empty pairs are skipped', () async {
      final response = await post('&agree&name=&&x=1&');

      expect(json(response), {
        'agree': [''],
        'name': [''],
        'x': ['1'],
      });
    });

    test('an empty body has no fields', () async {
      expect(json(await post('')), isEmpty);
    });

    test('the charset of the Content-Type decodes the bytes', () async {
      final response = await post(
        'name=Espa%F1a',
        contentType: '$form; charset=iso-8859-1',
      );

      expect(json(response), {
        'name': ['España'],
      });
    });

    test(
      'field<T>() parses the value, and a missing or empty one is null',
      () async {
        final response = await post(
          'age=30&vip=true&plan=PRO&note=',
          answer: (form) => ResponseEntity.ok(
            body: {
              'age': form.field<int>('age'),
              'vip': form.field<bool>('vip'),
              'plan': form.field<_Plan>('plan', values: _Plan.values)?.name,
              'note': form.field<String>('note'),
              'missing': form.field<int>('missing'),
            },
          ),
        );

        expect(json(response), {
          'age': 30,
          'vip': true,
          'plan': 'pro',
          'note': null,
          'missing': null,
        });
      },
    );

    test(
      'field<T>() of a wrong value is a 400 naming the field, not the value',
      () async {
        final response = await post(
          'age=secret123',
          answer: (form) => ResponseEntity.ok(body: form.field<int>('age')),
        );

        expect(response.statusCode, 400);
        expect(
          json(response)['detail'],
          'The form field age must be an integer',
        );
        expect(response.body, isNot(contains('secret123')));
      },
    );

    test('another Content-Type, or none, is a 415', () async {
      final json = await post('{"a":1}', contentType: 'application/json');
      final none = await post('a=1', contentType: null);

      expect(json.statusCode, 415);
      expect(
        jsonDecode(json.body)['detail'],
        'Unsupported Content-Type application/json, expected $form',
      );
      expect(none.statusCode, 415);
      expect(
        jsonDecode(none.body)['detail'],
        'Missing Content-Type, expected $form',
      );
    });

    test('a bad encoding is a 400 that doesn\'t show the body', () async {
      for (final body in ['a=%zz', 'a=%C3', 'secret=%']) {
        final response = await post(body);

        expect(response.statusCode, 400, reason: body);
        expect(
          json(response)['detail'],
          'The body is not a valid application/x-www-form-urlencoded form',
        );
        expect(response.body, isNot(contains('secret')));
      }
    });

    test('a body over maxBodySize is a 413', () async {
      final response = await post('a=${'x' * 100}', maxBodySize: 10);

      expect(response.statusCode, 413);
    });

    test('is cached: it can be read again, but not the raw body', () async {
      final request = RequestEntity(
        'POST',
        Uri.parse('http://localhost/form'),
        headers: {HttpHeader.contentType: form},
        body: 'a=1',
      );

      expect((await request.formData())['a'], '1');
      expect((await request.copyWith().formData())['a'], '1');
      expect(request.read, throwsStateError);
    });

    test('the maps are read-only, and toString has no values', () async {
      final FormData data = await RequestEntity(
        'POST',
        Uri.parse('http://localhost/form'),
        headers: {HttpHeader.contentType: form},
        body: 'card=4111&card=4222',
      ).formData();

      expect(() => data.fields['x'] = 'y', throwsUnsupportedError);
      expect(() => data.fieldsAll['card']!.add('x'), throwsUnsupportedError);
      expect(data.toString(), 'FormData{card}');
    });
  });
}
