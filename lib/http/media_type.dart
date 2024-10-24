import 'package:winter/winter.dart';

class MediaType {
  static MediaType all = const MediaType(
    '*',
    '*',
  );
  static MediaType applicationAtomXml = const MediaType(
    'application',
    'atom+xml',
  );
  static MediaType applicationCbor = const MediaType(
    'application',
    'cbor',
  );
  static MediaType applicationFormUrlencoded = const MediaType(
    'application',
    'x-www-form-urlencoded',
  );
  static MediaType applicationGraphql = const MediaType(
    'application',
    'graphql+json',
  );
  static MediaType applicationGraphqlResponse = const MediaType(
    'application',
    'graphql-response+json',
  );
  static MediaType applicationJson = const MediaType(
    'application',
    'json',
  );
  static MediaType applicationNdjson = const MediaType(
    'application',
    'x-ndjson',
  );
  static MediaType applicationOctetStream = const MediaType(
    'application',
    'octet-stream',
  );
  static MediaType applicationPdf = const MediaType(
    'application',
    'pdf',
  );
  static MediaType applicationProblemJson = const MediaType(
    'application',
    'problem+json',
  );
  static MediaType applicationProblemXml = const MediaType(
    'application',
    'problem+xml',
  );
  static MediaType applicationProtobuf = const MediaType(
    'application',
    'x-protobuf',
  );
  static MediaType applicationRssXml = const MediaType(
    'application',
    'rss+xml',
  );
  static MediaType applicationStreamJson = const MediaType(
    'application',
    'stream+json',
  );
  static MediaType applicationXhtmlXml = const MediaType(
    'application',
    'xhtml+xml',
  );
  static MediaType applicationXml = const MediaType(
    'application',
    'xml',
  );
  static MediaType imageGif = const MediaType(
    'image',
    'gif',
  );
  static MediaType imageJpeg = const MediaType(
    'image',
    'jpeg',
  );
  static MediaType imagePng = const MediaType(
    'image',
    'png',
  );
  static MediaType multipartFormData = const MediaType(
    'multipart',
    'form-data',
  );
  static MediaType multipartMixed = const MediaType(
    'multipart',
    'mixed',
  );
  static MediaType multipartRelated = const MediaType(
    'multipart',
    'related',
  );
  static MediaType textEventStream = const MediaType(
    'text',
    'event-stream',
  );
  static MediaType textHtml = const MediaType(
    'text',
    'html',
  );
  static MediaType textMarkdown = const MediaType(
    'text',
    'markdown',
  );
  static MediaType textPlain = const MediaType(
    'text',
    'plain',
  );
  static MediaType textXml = const MediaType(
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
