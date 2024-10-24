import 'package:collection/collection.dart'; //needed for firstWhereOrNull

import 'http_status_code.dart';

enum HttpStatus with HttpStatusCode {
  // 1xx Informational

  /// {status-code: 100 Continue}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.2.1">HTTP/1.1: Semantics and Content, section 6.2.1</a>
  //This has this name because 'continue' is a reserved keyword
  continue100(
    100,
    Series.informational,
    'Continue',
  ),

  /// {status-code: 101 Switching Protocols}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.2.2">HTTP/1.1: Semantics and Content, section 6.2.2</a>
  switchingProtocols(
    101,
    Series.informational,
    'Switching Protocols',
  ),

  /// {status-code: 102 Processing}.
  /// @see <a href="https://tools.ietf.org/html/rfc2518#section-10.1">WebDAV</a>
  processing(
    102,
    Series.informational,
    'Processing',
  ),

  /// {status-code: 103 Early Hints}.
  /// @see <a href="https://tools.ietf.org/html/rfc8297">An HTTP Status Code for Indicating Hints</a>
  /// @since 0.0.1.beta
  earlyHints(
    103,
    Series.informational,
    'Early Hints',
  ),

  // 2xx Success

  /// {status-code: 200 OK}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.3.1">HTTP/1.1: Semantics and Content, section 6.3.1</a>
  ok(
    200,
    Series.successful,
    'OK',
  ),

  /// {status-code: 201 Created}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.3.2">HTTP/1.1: Semantics and Content, section 6.3.2</a>
  created(
    201,
    Series.successful,
    'Created',
  ),

  /// {status-code: 202 Accepted}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.3.3">HTTP/1.1: Semantics and Content, section 6.3.3</a>
  accepted(
    202,
    Series.successful,
    'Accepted',
  ),

  /// {status-code: 203 Non-Authoritative Information}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.3.4">HTTP/1.1: Semantics and Content, section 6.3.4</a>
  nonAuthoritativeInformation(
    203,
    Series.successful,
    'Non-Authoritative Information',
  ),

  /// {status-code: 204 No Content}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.3.5">HTTP/1.1: Semantics and Content, section 6.3.5</a>
  noContent(
    204,
    Series.successful,
    'No Content',
  ),

  /// {status-code: 205 Reset Content}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.3.6">HTTP/1.1: Semantics and Content, section 6.3.6</a>
  resetContent(
    205,
    Series.successful,
    'Reset Content',
  ),

  /// {status-code: 206 Partial Content}.
  /// @see <a href="https://tools.ietf.org/html/rfc7233#section-4.1">HTTP/1.1: Range Requests, section 4.1</a>
  partialContent(
    206,
    Series.successful,
    'Partial Content',
  ),

  /// {status-code: 207 Multi-Status}.
  /// @see <a href="https://tools.ietf.org/html/rfc4918#section-13">WebDAV</a>
  multiStatus(
    207,
    Series.successful,
    'Multi-Status',
  ),

  /// {status-code: 208 Already Reported}.
  /// @see <a href="https://tools.ietf.org/html/rfc5842#section-7.1">WebDAV Binding Extensions</a>
  alreadyReported(
    208,
    Series.successful,
    'Already Reported',
  ),

  /// {status-code: 226 IM Used}.
  /// @see <a href="https://tools.ietf.org/html/rfc3229#section-10.4.1">Delta encoding in HTTP</a>
  imUsed(
    226,
    Series.successful,
    'IM Used',
  ),

  // 3xx Redirection

  /// {status-code: 300 Multiple Choices}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.4.1">HTTP/1.1: Semantics and Content, section 6.4.1</a>
  multipleChoices(
    300,
    Series.redirection,
    'Multiple Choices',
  ),

  /// {status-code: 301 Moved Permanently}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.4.2">HTTP/1.1: Semantics and Content, section 6.4.2</a>
  movedPermanently(
    301,
    Series.redirection,
    'Moved Permanently',
  ),

  /// {status-code: 302 Found}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.4.3">HTTP/1.1: Semantics and Content, section 6.4.3</a>
  found(
    302,
    Series.redirection,
    'Found',
  ),

  /// {status-code: 302 Moved Temporarily}.
  /// @see <a href="https://tools.ietf.org/html/rfc1945#section-9.3">HTTP/1.0, section 9.3</a>
  @Deprecated(
    'In favor of {@link #found} which will be returned from {status-code: HttpStatus.valueOf(302)}',
  )
  movedTemporarily(
    302,
    Series.redirection,
    'Moved Temporarily',
  ),

  /// {status-code: 303 See Other}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.4.4">HTTP/1.1: Semantics and Content, section 6.4.4</a>
  seeOther(
    303,
    Series.redirection,
    'See Other',
  ),

  /// {status-code: 304 Not Modified}.
  /// @see <a href="https://tools.ietf.org/html/rfc7232#section-4.1">HTTP/1.1: Conditional Requests, section 4.1</a>
  notModified(
    304,
    Series.redirection,
    'Not Modified',
  ),

  /// {status-code: 305 Use Proxy}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.4.5">HTTP/1.1: Semantics and Content, section 6.4.5</a>
  @Deprecated(
    'Due to security concerns regarding in-band configuration of a proxy',
  )
  useProxy(
    305,
    Series.redirection,
    'Use Proxy',
  ),

  /// {status-code: 307 Temporary Redirect}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.4.7">HTTP/1.1: Semantics and Content, section 6.4.7</a>
  temporaryRedirect(
    307,
    Series.redirection,
    'Temporary Redirect',
  ),

  /// {status-code: 308 Permanent Redirect}.
  /// @see <a href="https://tools.ietf.org/html/rfc7238">RFC 7238</a>
  permanentRedirect(
    308,
    Series.redirection,
    'Permanent Redirect',
  ),

  // --- 4xx Client Error ---

  /// {status-code: 400 Bad Request}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.5.1">HTTP/1.1: Semantics and Content, section 6.5.1</a>
  badRequest(
    400,
    Series.clientError,
    'Bad Request',
  ),

  /// {status-code: 401 Unauthorized}.
  /// @see <a href="https://tools.ietf.org/html/rfc7235#section-3.1">HTTP/1.1: Authentication, section 3.1</a>
  unauthorized(
    401,
    Series.clientError,
    'Unauthorized',
  ),

  /// {status-code: 402 Payment Required}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.5.2">HTTP/1.1: Semantics and Content, section 6.5.2</a>
  paymentRequired(
    402,
    Series.clientError,
    'Payment Required',
  ),

  /// {status-code: 403 Forbidden}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.5.3">HTTP/1.1: Semantics and Content, section 6.5.3</a>
  forbidden(
    403,
    Series.clientError,
    'Forbidden',
  ),

  /// {status-code: 404 Not Found}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.5.4">HTTP/1.1: Semantics and Content, section 6.5.4</a>
  notFound(
    404,
    Series.clientError,
    'Not Found',
  ),

  /// {status-code: 405 Method Not Allowed}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.5.5">HTTP/1.1: Semantics and Content, section 6.5.5</a>
  methodNotAllowed(
    405,
    Series.clientError,
    'Method Not Allowed',
  ),

  /// {status-code: 406 Not Acceptable}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.5.6">HTTP/1.1: Semantics and Content, section 6.5.6</a>
  notAcceptable(
    406,
    Series.clientError,
    'Not Acceptable',
  ),

  /// {status-code: 407 Proxy Authentication Required}.
  /// @see <a href="https://tools.ietf.org/html/rfc7235#section-3.2">HTTP/1.1: Authentication, section 3.2</a>
  proxyAuthenticationRequired(
    407,
    Series.clientError,
    'Proxy Authentication Required',
  ),

  /// {status-code: 408 Request Timeout}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.5.7">HTTP/1.1: Semantics and Content, section 6.5.7</a>
  requestTimeout(
    408,
    Series.clientError,
    'Request Timeout',
  ),

  /// {status-code: 409 Conflict}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.5.8">HTTP/1.1: Semantics and Content, section 6.5.8</a>
  conflict(
    409,
    Series.clientError,
    'Conflict',
  ),

  /// {status-code: 410 Gone}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.5.9">
  ///     HTTP/1.1: Semantics and Content, section 6.5.9</a>
  gone(
    410,
    Series.clientError,
    'Gone',
  ),

  /// {status-code: 411 Length Required}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.5.10">
  ///     HTTP/1.1: Semantics and Content, section 6.5.10</a>
  lengthRequired(
    411,
    Series.clientError,
    'Length Required',
  ),

  /// {status-code: 412 Precondition failed}.
  /// @see <a href="https://tools.ietf.org/html/rfc7232#section-4.2">
  ///     HTTP/1.1: Conditional Requests, section 4.2</a>
  preconditionFailed(
    412,
    Series.clientError,
    'Precondition Failed',
  ),

  /// {status-code: 413 Payload Too Large}.
  /// @since 0.0.1.beta
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.5.11">
  ///     HTTP/1.1: Semantics and Content, section 6.5.11</a>
  payloadTooLarge(
    413,
    Series.clientError,
    'Payload Too Large',
  ),

  /// {status-code: 413 Request Entity Too Large}.
  /// @see <a href="https://tools.ietf.org/html/rfc2616#section-10.4.14">HTTP/1.1, section 10.4.14</a>
  @Deprecated(
    'In favor of {@link #payloadTooLarge} which will be returned from {status-code: HttpStatus.valueOf(413)}',
  )
  requestEntityTooLarge(
    413,
    Series.clientError,
    'Request Entity Too Large',
  ),

  /// {status-code: 414 URI Too Long}.
  /// @since 0.0.1.beta
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.5.12">
  ///     HTTP/1.1: Semantics and Content, section 6.5.12</a>
  uriTooLong(
    414,
    Series.clientError,
    'URI Too Long',
  ),

  /// {status-code: 414 Request-URI Too Long}.
  /// @see <a href="https://tools.ietf.org/html/rfc2616#section-10.4.15">HTTP/1.1, section 10.4.15</a>
  @Deprecated(
    'In favor of {@link #uriTooLong} which will be returned from {status-code: HttpStatus.valueOf(414)}',
  )
  requestURITooLong(
    414,
    Series.clientError,
    'Request-URI Too Long',
  ),

  /// {status-code: 415 Unsupported Media Type}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.5.13">
  ///     HTTP/1.1: Semantics and Content, section 6.5.13</a>
  unsupportedMediaType(
    415,
    Series.clientError,
    'Unsupported Media Type',
  ),

  /// {status-code: 416 Requested Range Not Satisfiable}.
  /// @see <a href="https://tools.ietf.org/html/rfc7233#section-4.4">HTTP/1.1: Range Requests, section 4.4</a>
  rangeNotSatisfiable(
    416,
    Series.clientError,
    'Requested range not satisfiable',
  ),

  /// {status-code: 417 Expectation Failed}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.5.14">
  ///     HTTP/1.1: Semantics and Content, section 6.5.14</a>
  expectationFailed(
    417,
    Series.clientError,
    'Expectation Failed',
  ),

  /// {status-code: 418 I'm a teapot}.
  /// @see <a href="https://tools.ietf.org/html/rfc2324#section-2.3.2">HTCPCP/1.0</a>
  imATeapot(
    418,
    Series.clientError,
    "I'm a teapot",
  ),
  @Deprecated(
    'See WebDAV Draft Changes: https://tools.ietf.org/rfcdiff?difftype=--hwdiff&amp;url2=draft-ietf-webdav-protocol-06.txt',
  )
  insufficientSpaceOnResource(
    419,
    Series.clientError,
    'Insufficient Space On Resource',
  ),
  @Deprecated(
    'See WebDAV Draft Changes: https://tools.ietf.org/rfcdiff?difftype=--hwdiff&amp;url2=draft-ietf-webdav-protocol-06.txt',
  )
  methodFailure(
    420,
    Series.clientError,
    'Method Failure',
  ),
  @Deprecated(
    'See WebDAV Draft Changes: https://tools.ietf.org/rfcdiff?difftype=--hwdiff&amp;url2=draft-ietf-webdav-protocol-06.txt',
  )
  destinationLocked(
    421,
    Series.clientError,
    'Destination Locked',
  ),

  /// {status-code: 422 Unprocessable Entity}.
  /// @see <a href="https://tools.ietf.org/html/rfc4918#section-11.2">WebDAV</a>
  unprocessableEntity(
    422,
    Series.clientError,
    'Unprocessable Entity',
  ),

  /// {status-code: 423 Locked}.
  /// @see <a href="https://tools.ietf.org/html/rfc4918#section-11.3">WebDAV</a>
  locked(
    423,
    Series.clientError,
    'Locked',
  ),

  /// {status-code: 424 Failed Dependency}.
  /// @see <a href="https://tools.ietf.org/html/rfc4918#section-11.4">WebDAV</a>
  failedDependency(
    424,
    Series.clientError,
    'Failed Dependency',
  ),

  /// {status-code: 425 Too Early}.
  /// @since 0.0.1.beta
  /// @see <a href="https://tools.ietf.org/html/rfc8470">RFC 8470</a>
  tooEarly(
    425,
    Series.clientError,
    'Too Early',
  ),

  /// {status-code: 426 Upgrade Required}.
  /// @see <a href="https://tools.ietf.org/html/rfc2817#section-6">Upgrading to TLS Within HTTP/1.1</a>
  upgradeRequired(
    426,
    Series.clientError,
    'Upgrade Required',
  ),

  /// {status-code: 428 Precondition Required}.
  /// @see <a href="https://tools.ietf.org/html/rfc6585#section-3">Additional HTTP Status Codes</a>
  preconditionRequired(
    428,
    Series.clientError,
    'Precondition Required',
  ),

  /// {status-code: 429 Too Many Requests}.
  /// @see <a href="https://tools.ietf.org/html/rfc6585#section-4">Additional HTTP Status Codes</a>
  tooManyRequests(
    429,
    Series.clientError,
    'Too Many Requests',
  ),

  /// {status-code: 431 Request Header Fields Too Large}.
  /// @see <a href="https://tools.ietf.org/html/rfc6585#section-5">Additional HTTP Status Codes</a>
  requestHeaderFieldsTooLarge(
    431,
    Series.clientError,
    'Request Header Fields Too Large',
  ),

  /// {status-code: 451 Unavailable For Legal Reasons}.
  /// @see <a href="https://tools.ietf.org/html/draft-ietf-httpbis-legally-restricted-status-04">
  /// An HTTP Status Code to Report Legal Obstacles</a>
  /// @since 0.0.1.beta
  unavailableForLegalReasons(
    451,
    Series.clientError,
    'Unavailable For Legal Reasons',
  ),

  // --- 5xx Server Error ---

  /// {status-code: 500 Internal Server Error}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.6.1">HTTP/1.1: Semantics and Content, section 6.6.1</a>
  internalServerError(
    500,
    Series.serverError,
    'Internal Server Error',
  ),

  /// {status-code: 501 Not Implemented}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.6.2">HTTP/1.1: Semantics and Content, section 6.6.2</a>
  notImplemented(
    501,
    Series.serverError,
    'Not Implemented',
  ),

  /// {status-code: 502 Bad Gateway}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.6.3">HTTP/1.1: Semantics and Content, section 6.6.3</a>
  badGateway(
    502,
    Series.serverError,
    'Bad Gateway',
  ),

  /// {status-code: 503 Service Unavailable}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.6.4">HTTP/1.1: Semantics and Content, section 6.6.4</a>
  serviceUnavailable(
    503,
    Series.serverError,
    'Service Unavailable',
  ),

  /// {status-code: 504 Gateway Timeout}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.6.5">HTTP/1.1: Semantics and Content, section 6.6.5</a>
  gatewayTimeout(
    504,
    Series.serverError,
    'Gateway Timeout',
  ),

  /// {status-code: 505 HTTP Version Not Supported}.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-6.6.6">HTTP/1.1: Semantics and Content, section 6.6.6</a>
  httpVersionNotSupported(
    505,
    Series.serverError,
    'HTTP Version not supported',
  ),

  /// {status-code: 506 Variant Also Negotiates}
  /// @see <a href="https://tools.ietf.org/html/rfc2295#section-8.1">Transparent Content Negotiation</a>
  variantAlsoNegotiates(
    506,
    Series.serverError,
    'Variant Also Negotiates',
  ),

  /// {status-code: 507 Insufficient Storage}
  /// @see <a href="https://tools.ietf.org/html/rfc4918#section-11.5">WebDAV</a>
  insufficientStorage(
    507,
    Series.serverError,
    'Insufficient Storage',
  ),

  /// {status-code: 508 Loop Detected}
  /// @see <a href="https://tools.ietf.org/html/rfc5842#section-7.2">WebDAV Binding Extensions</a>
  loopDetected(
    508,
    Series.serverError,
    'Loop Detected',
  ),

  /// {status-code: 509 Bandwidth Limit Exceeded}
  bandwidthLimitExceeded(
    509,
    Series.serverError,
    'Bandwidth Limit Exceeded',
  ),

  /// {status-code: 510 Not Extended}
  /// @see <a href="https://tools.ietf.org/html/rfc2774#section-7">HTTP Extension Framework</a>
  notExtended(
    510,
    Series.serverError,
    'Not Extended',
  ),

  /// {status-code: 511 Network Authentication Required}.
  /// @see <a href="https://tools.ietf.org/html/rfc6585#section-6">Additional HTTP Status Codes</a>
  networkAuthenticationRequired(
    511,
    Series.serverError,
    'Network Authentication Required',
  );

  @override
  final int value;

  final Series series;

  final String reasonPhrase;

  const HttpStatus(
    this.value,
    this.series,
    this.reasonPhrase,
  );

  @override
  bool is1xxInformational() {
    return series == Series.informational;
  }

  @override
  bool is2xxSuccessful() {
    return series == Series.successful;
  }

  @override
  bool is3xxRedirection() {
    return series == Series.redirection;
  }

  @override
  bool is4xxClientError() {
    return series == Series.clientError;
  }

  @override
  bool is5xxServerError() {
    return series == Series.serverError;
  }

  @override
  bool isError() {
    return (is4xxClientError() || is5xxServerError());
  }

  /// Return a string representation of this status code.
  @override
  String toString() {
    return '$value $name';
  }

  /// Return the {status-code: HttpStatus} enum constant with the specified numeric value.
  /// @param statusCode the numeric value of the enum to be returned
  /// @return the enum constant with the specified numeric value
  /// @throws IllegalArgumentException if this enum has no constant for the specified numeric value
  static HttpStatus valueOf(int statusCode) {
    HttpStatus? status = resolve(statusCode);
    if (status == null) {
      throw StateError('No matching constant for [$statusCode]');
    }
    return status;
  }

  /// Resolve the given status code to an {status-code: HttpStatus}, if possible.
  /// @param statusCode the HTTP status code (potentially non-standard)
  /// @return the corresponding {status-code: HttpStatus}, or {status-code: null} if not found
  /// @since 0.0.1.beta
  static HttpStatus? resolve(int statusCode) {
    // Use cached VALUES instead of values() to prevent array allocation.
    return values.firstWhereOrNull(
      (element) => element.value == statusCode,
    );
  }
}

/// Enumeration of HTTP status series.
/// <p>Retrievable via {@link HttpStatus#series()}.
///
enum Series {
  informational(1),
  successful(2),
  redirection(3),
  clientError(4),
  serverError(5);

  final int value;

  const Series(this.value);

  /// Return the {status-code: Series} enum constant for the supplied status code.
  /// @param statusCode the HTTP status code (potentially non-standard)
  /// @return the {status-code: Series} enum constant for the supplied status code
  /// @throws IllegalArgumentException if this enum has no corresponding constant
  ///
  static Series valueOf(int statusCode) {
    Series? series = resolve(statusCode);
    if (series == null) {
      throw StateError('No matching constant for [$statusCode]');
    }
    return series;
  }

  /// Resolve the given status code to an {status-code: HttpStatus.Series}, if possible.
  /// @param statusCode the HTTP status code (potentially non-standard)
  /// @return the corresponding {status-code: Series}, or {status-code: null} if not found
  /// @since 0.0.1.beta
  ///
  static Series? resolve(int statusCode) {
    int seriesCode = statusCode ~/ 100;
    for (Series series in Series.values) {
      if (series.value == seriesCode) {
        return series;
      }
    }
    return null;
  }
}
