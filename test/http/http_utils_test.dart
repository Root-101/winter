import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  group('StatusCode', () {
    test('valueOf & resolve find the constant by its code', () {
      expect(StatusCode.valueOf(404), StatusCode.notFound);
      expect(StatusCode.resolve(200), StatusCode.ok);
      expect(StatusCode.resolve(999), isNull);
      expect(() => StatusCode.valueOf(999), throwsStateError);
    });

    test('A deprecated alias resolves to the current constant', () {
      expect(StatusCode.valueOf(413), StatusCode.payloadTooLarge);
    });

    test('series & predicates', () {
      expect(StatusCode.continue100.is1xxInformational(), isTrue);
      expect(StatusCode.created.is2xxSuccessful(), isTrue);
      expect(StatusCode.movedPermanently.is3xxRedirection(), isTrue);
      expect(StatusCode.badRequest.is4xxClientError(), isTrue);
      expect(StatusCode.badGateway.is5xxServerError(), isTrue);

      expect(StatusCode.notFound.series, Series.clientError);
      expect(StatusCode.notFound.isError(), isTrue);
      expect(StatusCode.internalServerError.isError(), isTrue);
      expect(StatusCode.ok.isError(), isFalse);
    });

    test('value, reason phrase & toString', () {
      expect(StatusCode.notFound.value, 404);
      expect(StatusCode.notFound.reasonPhrase, 'Not Found');
      expect(StatusCode.notFound.toString(), startsWith('404'));
    });
  });

  group('HttpStatusCode', () {
    test('valueOf returns the StatusCode constant for a standard code', () {
      expect(HttpStatusCode.valueOf(201), same(StatusCode.created));
    });

    test('valueOf returns a DefaultHttpStatusCode for a non standard code', () {
      final custom = HttpStatusCode.valueOf(599);

      expect(custom, isA<DefaultHttpStatusCode>());
      expect(custom.value, 599);
      expect(custom.is5xxServerError(), isTrue);
      expect(custom.isError(), isTrue);
      expect(custom.is4xxClientError(), isFalse);
      expect(custom.toString(), '599');
    });

    test('DefaultHttpStatusCode predicates for every series', () {
      expect(DefaultHttpStatusCode(199).is1xxInformational(), isTrue);
      expect(DefaultHttpStatusCode(299).is2xxSuccessful(), isTrue);
      expect(DefaultHttpStatusCode(399).is3xxRedirection(), isTrue);
      expect(DefaultHttpStatusCode(499).is4xxClientError(), isTrue);
      expect(DefaultHttpStatusCode(499).isError(), isTrue);
      expect(DefaultHttpStatusCode(299).isError(), isFalse);
    });

    test('valueOf only accepts three-digit codes', () {
      expect(() => HttpStatusCode.valueOf(42), throwsA(isA<AssertionError>()));
    });

    test('equality & isSameCodeAs', () {
      expect(DefaultHttpStatusCode(599), DefaultHttpStatusCode(599));
      expect(
        DefaultHttpStatusCode(599).hashCode,
        DefaultHttpStatusCode(599).hashCode,
      );
      expect(DefaultHttpStatusCode(599), isNot(DefaultHttpStatusCode(598)));
      expect(
        DefaultHttpStatusCode(404).isSameCodeAs(StatusCode.notFound),
        isTrue,
      );
    });
  });

  group('Series', () {
    test('valueOf & resolve use the first digit of the code', () {
      expect(Series.valueOf(204), Series.successful);
      expect(Series.resolve(503), Series.serverError);
      expect(Series.resolve(700), isNull);
      expect(() => Series.valueOf(700), throwsStateError);
    });
  });

  group('HttpMethod', () {
    test('equality is case insensitive, also against a String', () {
      expect(const HttpMethod('GET'), HttpMethod.get);
      expect(const HttpMethod('GET').hashCode, HttpMethod.get.hashCode);
      // ignore: unrelated_type_equality_checks
      expect(HttpMethod.post == 'POST', isTrue);
      // ignore: unrelated_type_equality_checks
      expect(HttpMethod.post == 'get', isFalse);
      expect(HttpMethod.post == HttpMethod.put, isFalse);
    });

    test('values & toString', () {
      expect(HttpMethod.values, contains(HttpMethod.options));
      expect(HttpMethod.delete.toString(), 'delete');
    });
  });

  group('MediaType', () {
    test('mimeType & toString', () {
      expect(MediaType.applicationJson.mimeType, 'application/json');
      expect(MediaType.textPlain.toString(), 'text/plain');
    });
  });
}
