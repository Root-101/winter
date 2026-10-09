import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  group('StatusCode', () {
    test('valueOf & resolve find the constant by its code', () {
      expect(StatusCode.valueOf(404), StatusCode.notFound);
      expect(StatusCode.resolve(200), StatusCode.ok);
      expect(StatusCode.resolve(999), isNull);
      expect(() => StatusCode.valueOf(999), throwsArgumentError);
    });

    test('one constant per code, without the deprecated aliases', () {
      expect(StatusCode.valueOf(413), StatusCode.payloadTooLarge);
      expect(
        StatusCode.values.map((status) => status.value).toSet(),
        hasLength(StatusCode.values.length),
      );
    });

    test('series & predicates', () {
      expect(StatusCode.continue100.isInformational, isTrue);
      expect(StatusCode.created.isSuccessful, isTrue);
      expect(StatusCode.movedPermanently.isRedirection, isTrue);
      expect(StatusCode.badRequest.isClientError, isTrue);
      expect(StatusCode.badGateway.isServerError, isTrue);

      expect(StatusCode.notFound.series, Series.clientError);
      expect(StatusCode.notFound.isError, isTrue);
      expect(StatusCode.internalServerError.isError, isTrue);
      expect(StatusCode.ok.isError, isFalse);
    });

    test('value, reason phrase & toString', () {
      expect(StatusCode.notFound.value, 404);
      expect(StatusCode.notFound.reasonPhrase, 'Not Found');
      expect(StatusCode.notFound.toString(), '404 notFound');
    });
  });

  group('Series', () {
    test('valueOf & resolve use the first digit of the code', () {
      expect(Series.valueOf(204), Series.successful);
      expect(Series.resolve(503), Series.serverError);
      expect(Series.resolve(700), isNull);
      expect(() => Series.valueOf(700), throwsArgumentError);
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
