import 'package:http_parser/http_parser.dart' as http_parser;

/// A media type (MIME type) such as `application/json`, with its [parameters].
///
/// The constants cover the common types of an API; [mimeType] is the text of a `Content-Type`
/// without its parameters:
///
/// ```dart
/// ResponseEntity.ok(body: csv, headers: {HttpHeader.contentType: 'text/csv'});
/// request.mimeType == MediaType.applicationJson.mimeType;
/// ```
///
/// {@category HTTP}
class MediaType {
  /// `*/*`: any type
  static const MediaType all = MediaType('*', '*');

  /// `application/atom+xml`
  static const MediaType applicationAtomXml = MediaType(
    'application',
    'atom+xml',
  );

  /// `application/cbor`
  static const MediaType applicationCbor = MediaType('application', 'cbor');

  /// `application/x-www-form-urlencoded`: an HTML form without files
  static const MediaType applicationFormUrlencoded = MediaType(
    'application',
    'x-www-form-urlencoded',
  );

  /// `application/graphql+json`
  static const MediaType applicationGraphql = MediaType(
    'application',
    'graphql+json',
  );

  /// `application/graphql-response+json`
  static const MediaType applicationGraphqlResponse = MediaType(
    'application',
    'graphql-response+json',
  );

  /// `application/json`
  static const MediaType applicationJson = MediaType('application', 'json');

  /// `application/x-ndjson`: one JSON value per line
  static const MediaType applicationNdjson = MediaType(
    'application',
    'x-ndjson',
  );

  /// `application/octet-stream`: bytes of an unknown type
  static const MediaType applicationOctetStream = MediaType(
    'application',
    'octet-stream',
  );

  /// `application/pdf`
  static const MediaType applicationPdf = MediaType('application', 'pdf');

  /// `application/problem+json`: an error as Problem Details (RFC 9457), the format of every
  /// error of Winter
  static const MediaType applicationProblemJson = MediaType(
    'application',
    'problem+json',
  );

  /// `application/problem+xml`
  static const MediaType applicationProblemXml = MediaType(
    'application',
    'problem+xml',
  );

  /// `application/x-protobuf`
  static const MediaType applicationProtobuf = MediaType(
    'application',
    'x-protobuf',
  );

  /// `application/rss+xml`
  static const MediaType applicationRssXml = MediaType(
    'application',
    'rss+xml',
  );

  /// `application/stream+json`
  static const MediaType applicationStreamJson = MediaType(
    'application',
    'stream+json',
  );

  /// `application/xhtml+xml`
  static const MediaType applicationXhtmlXml = MediaType(
    'application',
    'xhtml+xml',
  );

  /// `application/xml`
  static const MediaType applicationXml = MediaType('application', 'xml');

  /// `image/gif`
  static const MediaType imageGif = MediaType('image', 'gif');

  /// `image/jpeg`
  static const MediaType imageJpeg = MediaType('image', 'jpeg');

  /// `image/png`
  static const MediaType imagePng = MediaType('image', 'png');

  /// `multipart/form-data`: an HTML form that uploads files
  static const MediaType multipartFormData = MediaType(
    'multipart',
    'form-data',
  );

  /// `multipart/mixed`
  static const MediaType multipartMixed = MediaType('multipart', 'mixed');

  /// `multipart/related`
  static const MediaType multipartRelated = MediaType('multipart', 'related');

  /// `text/event-stream`: Server-Sent Events
  static const MediaType textEventStream = MediaType('text', 'event-stream');

  /// `text/html`
  static const MediaType textHtml = MediaType('text', 'html');

  /// `text/markdown`
  static const MediaType textMarkdown = MediaType('text', 'markdown');

  /// `text/plain`
  static const MediaType textPlain = MediaType('text', 'plain');

  /// `text/xml`
  static const MediaType textXml = MediaType('text', 'xml');

  /// The top-level type: `application` in `application/json`
  final String type;

  /// The subtype: `json` in `application/json`
  final String subtype;

  /// The parameters (`charset`, `boundary`...). Case insensitive and read-only when they come
  /// from [MediaType.parse]; as given otherwise.
  final Map<String, String> parameters;

  /// `type/subtype`, without the parameters
  String get mimeType => '$type/$subtype';

  @override
  String toString() => mimeType;

  /// The media type `type/subtype`, with its [parameters]
  const MediaType(this.type, this.subtype, {Map<String, String>? parameters})
    : parameters = parameters ?? const {};

  /// Parses a media type with its parameters (`text/plain; charset=utf-8`): a [FormatException]
  /// if it's invalid.
  factory MediaType.parse(String mediaType) {
    final parsed = http_parser.MediaType.parse(mediaType);
    return MediaType(
      parsed.type,
      parsed.subtype,
      parameters: parsed.parameters,
    );
  }
}
