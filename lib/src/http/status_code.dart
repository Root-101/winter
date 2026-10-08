/// The HTTP status codes, with their reason phrase:
///
/// ```dart
/// throw ApiException(StatusCode.conflict, detail: 'The email is already registered');
/// StatusCode.resolve(422)?.reasonPhrase; // Unprocessable Entity
/// ```
enum StatusCode {
  // 1xx Informational

  /// 100 Continue ([HTTP/1.1: Semantics and Content, section 6.2.1](https://tools.ietf.org/html/rfc7231#section-6.2.1)). Named `continue100`: `continue` is a keyword
  continue100(100, Series.informational, 'Continue'),

  /// 101 Switching Protocols ([HTTP/1.1: Semantics and Content, section 6.2.2](https://tools.ietf.org/html/rfc7231#section-6.2.2))
  switchingProtocols(101, Series.informational, 'Switching Protocols'),

  /// 102 Processing ([WebDAV](https://tools.ietf.org/html/rfc2518#section-10.1))
  processing(102, Series.informational, 'Processing'),

  /// 103 Early Hints ([An HTTP Status Code for Indicating Hints](https://tools.ietf.org/html/rfc8297))
  earlyHints(103, Series.informational, 'Early Hints'),

  // 2xx Success

  /// 200 OK ([HTTP/1.1: Semantics and Content, section 6.3.1](https://tools.ietf.org/html/rfc7231#section-6.3.1))
  ok(200, Series.successful, 'OK'),

  /// 201 Created ([HTTP/1.1: Semantics and Content, section 6.3.2](https://tools.ietf.org/html/rfc7231#section-6.3.2))
  created(201, Series.successful, 'Created'),

  /// 202 Accepted ([HTTP/1.1: Semantics and Content, section 6.3.3](https://tools.ietf.org/html/rfc7231#section-6.3.3))
  accepted(202, Series.successful, 'Accepted'),

  /// 203 Non-Authoritative Information ([HTTP/1.1: Semantics and Content, section 6.3.4](https://tools.ietf.org/html/rfc7231#section-6.3.4))
  nonAuthoritativeInformation(
    203,
    Series.successful,
    'Non-Authoritative Information',
  ),

  /// 204 No Content ([HTTP/1.1: Semantics and Content, section 6.3.5](https://tools.ietf.org/html/rfc7231#section-6.3.5))
  noContent(204, Series.successful, 'No Content'),

  /// 205 Reset Content ([HTTP/1.1: Semantics and Content, section 6.3.6](https://tools.ietf.org/html/rfc7231#section-6.3.6))
  resetContent(205, Series.successful, 'Reset Content'),

  /// 206 Partial Content ([HTTP/1.1: Range Requests, section 4.1](https://tools.ietf.org/html/rfc7233#section-4.1))
  partialContent(206, Series.successful, 'Partial Content'),

  /// 207 Multi-Status ([WebDAV](https://tools.ietf.org/html/rfc4918#section-13))
  multiStatus(207, Series.successful, 'Multi-Status'),

  /// 208 Already Reported ([WebDAV Binding Extensions](https://tools.ietf.org/html/rfc5842#section-7.1))
  alreadyReported(208, Series.successful, 'Already Reported'),

  /// 226 IM Used ([Delta encoding in HTTP](https://tools.ietf.org/html/rfc3229#section-10.4.1))
  imUsed(226, Series.successful, 'IM Used'),

  // 3xx Redirection

  /// 300 Multiple Choices ([HTTP/1.1: Semantics and Content, section 6.4.1](https://tools.ietf.org/html/rfc7231#section-6.4.1))
  multipleChoices(300, Series.redirection, 'Multiple Choices'),

  /// 301 Moved Permanently ([HTTP/1.1: Semantics and Content, section 6.4.2](https://tools.ietf.org/html/rfc7231#section-6.4.2))
  movedPermanently(301, Series.redirection, 'Moved Permanently'),

  /// 302 Found ([HTTP/1.1: Semantics and Content, section 6.4.3](https://tools.ietf.org/html/rfc7231#section-6.4.3))
  found(302, Series.redirection, 'Found'),

  /// 303 See Other ([HTTP/1.1: Semantics and Content, section 6.4.4](https://tools.ietf.org/html/rfc7231#section-6.4.4))
  seeOther(303, Series.redirection, 'See Other'),

  /// 304 Not Modified ([HTTP/1.1: Conditional Requests, section 4.1](https://tools.ietf.org/html/rfc7232#section-4.1))
  notModified(304, Series.redirection, 'Not Modified'),

  /// 307 Temporary Redirect ([HTTP/1.1: Semantics and Content, section 6.4.7](https://tools.ietf.org/html/rfc7231#section-6.4.7))
  temporaryRedirect(307, Series.redirection, 'Temporary Redirect'),

  /// 308 Permanent Redirect ([RFC 7238](https://tools.ietf.org/html/rfc7238))
  permanentRedirect(308, Series.redirection, 'Permanent Redirect'),

  // 4xx Client Error

  /// 400 Bad Request ([HTTP/1.1: Semantics and Content, section 6.5.1](https://tools.ietf.org/html/rfc7231#section-6.5.1))
  badRequest(400, Series.clientError, 'Bad Request'),

  /// 401 Unauthorized ([HTTP/1.1: Authentication, section 3.1](https://tools.ietf.org/html/rfc7235#section-3.1))
  unauthorized(401, Series.clientError, 'Unauthorized'),

  /// 402 Payment Required ([HTTP/1.1: Semantics and Content, section 6.5.2](https://tools.ietf.org/html/rfc7231#section-6.5.2))
  paymentRequired(402, Series.clientError, 'Payment Required'),

  /// 403 Forbidden ([HTTP/1.1: Semantics and Content, section 6.5.3](https://tools.ietf.org/html/rfc7231#section-6.5.3))
  forbidden(403, Series.clientError, 'Forbidden'),

  /// 404 Not Found ([HTTP/1.1: Semantics and Content, section 6.5.4](https://tools.ietf.org/html/rfc7231#section-6.5.4))
  notFound(404, Series.clientError, 'Not Found'),

  /// 405 Method Not Allowed ([HTTP/1.1: Semantics and Content, section 6.5.5](https://tools.ietf.org/html/rfc7231#section-6.5.5))
  methodNotAllowed(405, Series.clientError, 'Method Not Allowed'),

  /// 406 Not Acceptable ([HTTP/1.1: Semantics and Content, section 6.5.6](https://tools.ietf.org/html/rfc7231#section-6.5.6))
  notAcceptable(406, Series.clientError, 'Not Acceptable'),

  /// 407 Proxy Authentication Required ([HTTP/1.1: Authentication, section 3.2](https://tools.ietf.org/html/rfc7235#section-3.2))
  proxyAuthenticationRequired(
    407,
    Series.clientError,
    'Proxy Authentication Required',
  ),

  /// 408 Request Timeout ([HTTP/1.1: Semantics and Content, section 6.5.7](https://tools.ietf.org/html/rfc7231#section-6.5.7))
  requestTimeout(408, Series.clientError, 'Request Timeout'),

  /// 409 Conflict ([HTTP/1.1: Semantics and Content, section 6.5.8](https://tools.ietf.org/html/rfc7231#section-6.5.8))
  conflict(409, Series.clientError, 'Conflict'),

  /// 410 Gone
  gone(410, Series.clientError, 'Gone'),

  /// 411 Length Required
  lengthRequired(411, Series.clientError, 'Length Required'),

  /// 412 Precondition Failed
  preconditionFailed(412, Series.clientError, 'Precondition Failed'),

  /// 413 Payload Too Large
  payloadTooLarge(413, Series.clientError, 'Payload Too Large'),

  /// 414 URI Too Long
  uriTooLong(414, Series.clientError, 'URI Too Long'),

  /// 415 Unsupported Media Type
  unsupportedMediaType(415, Series.clientError, 'Unsupported Media Type'),

  /// 416 Requested range not satisfiable ([HTTP/1.1: Range Requests, section 4.4](https://tools.ietf.org/html/rfc7233#section-4.4))
  rangeNotSatisfiable(
    416,
    Series.clientError,
    'Requested range not satisfiable',
  ),

  /// 417 Expectation Failed
  expectationFailed(417, Series.clientError, 'Expectation Failed'),

  /// 418 I'm a teapot ([HTCPCP/1.0](https://tools.ietf.org/html/rfc2324#section-2.3.2))
  imATeapot(418, Series.clientError, "I'm a teapot"),

  /// 422 Unprocessable Entity ([WebDAV](https://tools.ietf.org/html/rfc4918#section-11.2))
  unprocessableEntity(422, Series.clientError, 'Unprocessable Entity'),

  /// 423 Locked ([WebDAV](https://tools.ietf.org/html/rfc4918#section-11.3))
  locked(423, Series.clientError, 'Locked'),

  /// 424 Failed Dependency ([WebDAV](https://tools.ietf.org/html/rfc4918#section-11.4))
  failedDependency(424, Series.clientError, 'Failed Dependency'),

  /// 425 Too Early ([RFC 8470](https://tools.ietf.org/html/rfc8470))
  tooEarly(425, Series.clientError, 'Too Early'),

  /// 426 Upgrade Required ([Upgrading to TLS Within HTTP/1.1](https://tools.ietf.org/html/rfc2817#section-6))
  upgradeRequired(426, Series.clientError, 'Upgrade Required'),

  /// 428 Precondition Required ([Additional HTTP Status Codes](https://tools.ietf.org/html/rfc6585#section-3))
  preconditionRequired(428, Series.clientError, 'Precondition Required'),

  /// 429 Too Many Requests ([Additional HTTP Status Codes](https://tools.ietf.org/html/rfc6585#section-4))
  tooManyRequests(429, Series.clientError, 'Too Many Requests'),

  /// 431 Request Header Fields Too Large ([Additional HTTP Status Codes](https://tools.ietf.org/html/rfc6585#section-5))
  requestHeaderFieldsTooLarge(
    431,
    Series.clientError,
    'Request Header Fields Too Large',
  ),

  /// 451 Unavailable For Legal Reasons
  unavailableForLegalReasons(
    451,
    Series.clientError,
    'Unavailable For Legal Reasons',
  ),

  // 5xx Server Error

  /// 500 Internal Server Error ([HTTP/1.1: Semantics and Content, section 6.6.1](https://tools.ietf.org/html/rfc7231#section-6.6.1))
  internalServerError(500, Series.serverError, 'Internal Server Error'),

  /// 501 Not Implemented ([HTTP/1.1: Semantics and Content, section 6.6.2](https://tools.ietf.org/html/rfc7231#section-6.6.2))
  notImplemented(501, Series.serverError, 'Not Implemented'),

  /// 502 Bad Gateway ([HTTP/1.1: Semantics and Content, section 6.6.3](https://tools.ietf.org/html/rfc7231#section-6.6.3))
  badGateway(502, Series.serverError, 'Bad Gateway'),

  /// 503 Service Unavailable ([HTTP/1.1: Semantics and Content, section 6.6.4](https://tools.ietf.org/html/rfc7231#section-6.6.4))
  serviceUnavailable(503, Series.serverError, 'Service Unavailable'),

  /// 504 Gateway Timeout ([HTTP/1.1: Semantics and Content, section 6.6.5](https://tools.ietf.org/html/rfc7231#section-6.6.5))
  gatewayTimeout(504, Series.serverError, 'Gateway Timeout'),

  /// 505 HTTP Version not supported ([HTTP/1.1: Semantics and Content, section 6.6.6](https://tools.ietf.org/html/rfc7231#section-6.6.6))
  httpVersionNotSupported(
    505,
    Series.serverError,
    'HTTP Version not supported',
  ),

  /// 506 Variant Also Negotiates ([Transparent Content Negotiation](https://tools.ietf.org/html/rfc2295#section-8.1))
  variantAlsoNegotiates(506, Series.serverError, 'Variant Also Negotiates'),

  /// 507 Insufficient Storage ([WebDAV](https://tools.ietf.org/html/rfc4918#section-11.5))
  insufficientStorage(507, Series.serverError, 'Insufficient Storage'),

  /// 508 Loop Detected ([WebDAV Binding Extensions](https://tools.ietf.org/html/rfc5842#section-7.2))
  loopDetected(508, Series.serverError, 'Loop Detected'),

  /// 509 Bandwidth Limit Exceeded
  bandwidthLimitExceeded(509, Series.serverError, 'Bandwidth Limit Exceeded'),

  /// 510 Not Extended ([HTTP Extension Framework](https://tools.ietf.org/html/rfc2774#section-7))
  notExtended(510, Series.serverError, 'Not Extended'),

  /// 511 Network Authentication Required ([Additional HTTP Status Codes](https://tools.ietf.org/html/rfc6585#section-6))
  networkAuthenticationRequired(
    511,
    Series.serverError,
    'Network Authentication Required',
  );

  /// The numeric code (`404`)
  final int value;

  /// The class of the code (`Series.clientError` for a 404)
  final Series series;

  /// The text of the status line (`Not Found`)
  final String reasonPhrase;

  const StatusCode(this.value, this.series, this.reasonPhrase);

  /// 1xx
  bool get isInformational => series == Series.informational;

  /// 2xx
  bool get isSuccessful => series == Series.successful;

  /// 3xx
  bool get isRedirection => series == Series.redirection;

  /// 4xx
  bool get isClientError => series == Series.clientError;

  /// 5xx
  bool get isServerError => series == Series.serverError;

  /// 4xx or 5xx
  bool get isError => isClientError || isServerError;

  /// `404 notFound`
  @override
  String toString() => '$value $name';

  /// The status of [code]: an [ArgumentError] if it's not one of these values
  static StatusCode valueOf(int code) =>
      resolve(code) ??
      (throw ArgumentError.value(code, 'code', 'Not a known status code'));

  /// The status of [code], or null if it's not one of these values (a non standard code)
  static StatusCode? resolve(int code) => _byValue[code];

  static final Map<int, StatusCode> _byValue = {
    for (final status in values) status.value: status,
  };
}

/// The class of a status code, its first digit
enum Series {
  informational(1),
  successful(2),
  redirection(3),
  clientError(4),
  serverError(5);

  /// The first digit of the codes of this series
  final int value;

  const Series(this.value);

  /// The series of [statusCode]: an [ArgumentError] if it's not between 100 and 599
  static Series valueOf(int statusCode) =>
      resolve(statusCode) ??
      (throw ArgumentError.value(
        statusCode,
        'statusCode',
        'Not between 100 and 599',
      ));

  /// The series of [statusCode], or null if it's not between 100 and 599
  static Series? resolve(int statusCode) {
    final int first = statusCode ~/ 100;
    for (final series in Series.values) {
      if (series.value == first) return series;
    }
    return null;
  }
}
