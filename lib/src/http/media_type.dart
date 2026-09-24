import 'package:http_parser/http_parser.dart' as http_parser;

class MediaType {
  static const MediaType all = MediaType('*', '*');
  static const MediaType applicationAtomXml = MediaType(
    'application',
    'atom+xml',
  );
  static const MediaType applicationCbor = MediaType('application', 'cbor');
  static const MediaType applicationFormUrlencoded = MediaType(
    'application',
    'x-www-form-urlencoded',
  );
  static const MediaType applicationGraphql = MediaType(
    'application',
    'graphql+json',
  );
  static const MediaType applicationGraphqlResponse = MediaType(
    'application',
    'graphql-response+json',
  );
  static const MediaType applicationJson = MediaType('application', 'json');
  static const MediaType applicationNdjson = MediaType(
    'application',
    'x-ndjson',
  );
  static const MediaType applicationOctetStream = MediaType(
    'application',
    'octet-stream',
  );
  static const MediaType applicationPdf = MediaType('application', 'pdf');
  static const MediaType applicationProblemJson = MediaType(
    'application',
    'problem+json',
  );
  static const MediaType applicationProblemXml = MediaType(
    'application',
    'problem+xml',
  );
  static const MediaType applicationProtobuf = MediaType(
    'application',
    'x-protobuf',
  );
  static const MediaType applicationRssXml = MediaType(
    'application',
    'rss+xml',
  );
  static const MediaType applicationStreamJson = MediaType(
    'application',
    'stream+json',
  );
  static const MediaType applicationXhtmlXml = MediaType(
    'application',
    'xhtml+xml',
  );
  static const MediaType applicationXml = MediaType('application', 'xml');
  static const MediaType imageGif = MediaType('image', 'gif');
  static const MediaType imageJpeg = MediaType('image', 'jpeg');
  static const MediaType imagePng = MediaType('image', 'png');
  static const MediaType multipartFormData = MediaType(
    'multipart',
    'form-data',
  );
  static const MediaType multipartMixed = MediaType('multipart', 'mixed');
  static const MediaType multipartRelated = MediaType('multipart', 'related');
  static const MediaType textEventStream = MediaType('text', 'event-stream');
  static const MediaType textHtml = MediaType('text', 'html');
  static const MediaType textMarkdown = MediaType('text', 'markdown');
  static const MediaType textPlain = MediaType('text', 'plain');
  static const MediaType textXml = MediaType('text', 'xml');

  final String type;
  final String subtype;

  /// The parameters to the media type.
  ///
  /// This map is immutable and the keys are case-insensitive.
  final Map<String, String> parameters;

  /// The media type's MIME type.
  String get mimeType => '$type/$subtype';

  @override
  String toString() => mimeType;

  const MediaType(this.type, this.subtype, {Map<String, String>? parameters})
    : parameters = parameters ?? const {};

  /// Parses a media type.
  ///
  /// This will throw a FormatError if the media type is invalid.
  factory MediaType.parse(String mediaType) {
    final parsed = http_parser.MediaType.parse(mediaType);
    return MediaType(
      parsed.type,
      parsed.subtype,
      parameters: parsed.parameters,
    );
  }
}
