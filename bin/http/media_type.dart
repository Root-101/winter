import 'package:http_parser/src/scan.dart';
import 'package:string_scanner/string_scanner.dart';

class MediaType {
  static MediaType ALL = const MediaType(
    '*',
    '*',
  );
  static MediaType APPLICATION_ATOM_XML = const MediaType(
    'application',
    'atom+xml',
  );
  static MediaType APPLICATION_CBOR = const MediaType(
    'application',
    'cbor',
  );
  static MediaType APPLICATION_FORM_URLENCODED = const MediaType(
    'application',
    'x-www-form-urlencoded',
  );
  static MediaType APPLICATION_GRAPHQL = const MediaType(
    'application',
    'graphql+json',
  );
  static MediaType APPLICATION_GRAPHQL_RESPONSE = const MediaType(
    'application',
    'graphql-response+json',
  );
  static MediaType APPLICATION_JSON = const MediaType(
    'application',
    'json',
  );
  static MediaType APPLICATION_NDJSON = const MediaType(
    'application',
    'x-ndjson',
  );
  static MediaType APPLICATION_OCTET_STREAM = const MediaType(
    'application',
    'octet-stream',
  );
  static MediaType APPLICATION_PDF = const MediaType(
    'application',
    'pdf',
  );
  static MediaType APPLICATION_PROBLEM_JSON = const MediaType(
    'application',
    'problem+json',
  );
  static MediaType APPLICATION_PROBLEM_XML = const MediaType(
    'application',
    'problem+xml',
  );
  static MediaType APPLICATION_PROTOBUF = const MediaType(
    'application',
    'x-protobuf',
  );
  static MediaType APPLICATION_RSS_XML = const MediaType(
    'application',
    'rss+xml',
  );
  static MediaType APPLICATION_STREAM_JSON = const MediaType(
    'application',
    'stream+json',
  );
  static MediaType APPLICATION_XHTML_XML = const MediaType(
    'application',
    'xhtml+xml',
  );
  static MediaType APPLICATION_XML = const MediaType(
    'application',
    'xml',
  );
  static MediaType IMAGE_GIF = const MediaType(
    'image',
    'gif',
  );
  static MediaType IMAGE_JPEG = const MediaType(
    'image',
    'jpeg',
  );
  static MediaType IMAGE_PNG = const MediaType(
    'image',
    'png',
  );
  static MediaType MULTIPART_FORM_DATA = const MediaType(
    'multipart',
    'form-data',
  );
  static MediaType MULTIPART_MIXED = const MediaType(
    'multipart',
    'mixed',
  );
  static MediaType MULTIPART_RELATED = const MediaType(
    'multipart',
    'related',
  );
  static MediaType TEXT_EVENT_STREAM = const MediaType(
    'text',
    'event-stream',
  );
  static MediaType TEXT_HTML = const MediaType(
    'text',
    'html',
  );
  static MediaType TEXT_MARKDOWN = const MediaType(
    'text',
    'markdown',
  );
  static MediaType TEXT_PLAIN = const MediaType(
    'text',
    'plain',
  );
  static MediaType TEXT_XML = const MediaType(
    'text',
    'xml',
  );

  final String type;
  final String subtype;

  /// The parameters to the media type.
  ///
  /// This map is immutable and the keys are case-insensitive.
  final Map<String, String> parameters;

  /// The media type's MIME type.
  String get mimeType => '$type/$subtype';

  const MediaType(
    this.type,
    this.subtype, {
    Map<String, String>? parameters,
  }) : parameters = parameters ?? const {};

  /// Parses a media type.
  ///
  /// This will throw a FormatError if the media type is invalid.
  factory MediaType.parse(String mediaType) {
    final scanner = StringScanner(
      mediaType,
    );
    scanner.scan(
      whitespace,
    );
    scanner.expect(
      token,
    );
    final type = scanner.lastMatch![0]!;
    scanner.expect(
      '/',
    );
    scanner.expect(
      token,
    );
    final subtype = scanner.lastMatch![0]!;
    scanner.scan(
      whitespace,
    );

    final parameters = <String, String>{};
    while (scanner.scan(';')) {
      scanner.scan(
        whitespace,
      );
      scanner.expect(
        token,
      );
      final attribute = scanner.lastMatch![0]!;
      scanner.expect(
        '=',
      );

      String value;
      if (scanner.scan(token)) {
        value = scanner.lastMatch![0]!;
      } else {
        value = expectQuotedString(
          scanner,
        );
      }

      scanner.scan(
        whitespace,
      );
      parameters[attribute] = value;
    }

    scanner.expectDone();
    return MediaType(
      type,
      subtype,
      parameters: parameters,
    );
  }
}
