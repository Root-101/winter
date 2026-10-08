/// The names of the HTTP headers, as constants: `request.headers[HttpHeader.authorization]`.
///
/// Header names are case insensitive: Winter compares them that way, so the case of these names
/// only shows in the responses.
///
/// {@category HTTP}
class HttpHeader {
  /// The `X-Forwarded-For` header, added by proxies with the address of the client
  /// (de facto standard, not in the HTTP spec).
  static const String xForwardedFor = 'X-Forwarded-For';

  /// The HTTP `Accept` header.
  /// See [Section 5.3.2 of RFC 7231](https://tools.ietf.org/html/rfc7231#section-5.3.2).
  static const String accept = 'Accept';

  /// The HTTP `Accept-Charset` header.
  /// See [Section 5.3.3 of RFC 7231](https://tools.ietf.org/html/rfc7231#section-5.3.3).
  static const String acceptCharset = 'Accept-Charset';

  /// The HTTP `Accept-Encoding` header.
  /// See [Section 5.3.4 of RFC 7231](https://tools.ietf.org/html/rfc7231#section-5.3.4).
  static const String acceptEncoding = 'Accept-Encoding';

  /// The HTTP `Accept-Language` header.
  /// See [Section 5.3.5 of RFC 7231](https://tools.ietf.org/html/rfc7231#section-5.3.5).
  static const String acceptLanguage = 'Accept-Language';

  /// The HTTP `Accept-Patch` header.
  /// See [Section 3.1 of RFC 5789](https://tools.ietf.org/html/rfc5789#section-3.1).
  static const String acceptPatch = 'Accept-Patch';

  /// The HTTP `Accept-Ranges` header.
  /// See [Section 5.3.5 of RFC 7233](https://tools.ietf.org/html/rfc7233#section-2.3).
  static const String acceptRanges = 'Accept-Ranges';

  /// The CORS `Access-Control-Allow-Credentials` response header.
  /// See [CORS W3C recommendation](https://www.w3.org/TR/cors/).
  static const String accessControlAllowCredentials =
      'Access-Control-Allow-Credentials';

  /// The CORS `Access-Control-Allow-Headers` response header.
  /// See [CORS W3C recommendation](https://www.w3.org/TR/cors/).
  static const String accessControlAllowHeaders =
      'Access-Control-Allow-Headers';

  /// The CORS `Access-Control-Allow-Methods` response header.
  /// See [CORS W3C recommendation](https://www.w3.org/TR/cors/).
  static const String accessControlAllowMethods =
      'Access-Control-Allow-Methods';

  /// The CORS `Access-Control-Allow-Origin` response header.
  /// See [CORS W3C recommendation](https://www.w3.org/TR/cors/).
  static const String accessControlAllowOrigin = 'Access-Control-Allow-Origin';

  /// The CORS `Access-Control-Expose-Headers` response header.
  /// See [CORS W3C recommendation](https://www.w3.org/TR/cors/).
  static const String accessControlExposeHeaders =
      'Access-Control-Expose-Headers';

  /// The CORS `Access-Control-Max-Age` response header.
  /// See [CORS W3C recommendation](https://www.w3.org/TR/cors/).
  static const String accessControlMaxAge = 'Access-Control-Max-Age';

  /// The CORS `Access-Control-Request-Headers` request header.
  /// See [CORS W3C recommendation](https://www.w3.org/TR/cors/).
  static const String accessControlRequestHeaders =
      'Access-Control-Request-Headers';

  /// The CORS `Access-Control-Request-Method` request header.
  /// See [CORS W3C recommendation](https://www.w3.org/TR/cors/).
  static const String accessControlRequestMethod =
      'Access-Control-Request-Method';

  /// The HTTP `Age` header.
  /// See [Section 5.1 of RFC 7234](https://tools.ietf.org/html/rfc7234#section-5.1).
  static const String age = 'Age';

  /// The HTTP `Allow` header.
  /// See [Section 7.4.1 of RFC 7231](https://tools.ietf.org/html/rfc7231#section-7.4.1).
  static const String allow = 'Allow';

  /// The HTTP `Authorization` header.
  /// See [Section 4.2 of RFC 7235](https://tools.ietf.org/html/rfc7235#section-4.2).
  static const String authorization = 'Authorization';

  /// The HTTP `Cache-Control` header.
  /// See [Section 5.2 of RFC 7234](https://tools.ietf.org/html/rfc7234#section-5.2).
  static const String cacheControl = 'Cache-Control';

  /// The HTTP `Connection` header.
  /// See [Section 6.1 of RFC 7230](https://tools.ietf.org/html/rfc7230#section-6.1).
  static const String connection = 'Connection';

  /// The HTTP `Content-Encoding` header.
  /// See [Section 3.1.2.2 of RFC 7231](https://tools.ietf.org/html/rfc7231#section-3.1.2.2).
  static const String contentEncoding = 'Content-Encoding';

  /// The HTTP `Content-Disposition` header.
  /// See [RFC 6266](https://tools.ietf.org/html/rfc6266).
  static const String contentDisposition = 'Content-Disposition';

  /// The HTTP `Content-Language` header.
  /// See [Section 3.1.3.2 of RFC 7231](https://tools.ietf.org/html/rfc7231#section-3.1.3.2).
  static const String contentLanguage = 'Content-Language';

  /// The HTTP `Content-Length` header.
  /// See [Section 3.3.2 of RFC 7230](https://tools.ietf.org/html/rfc7230#section-3.3.2).
  static const String contentLength = 'Content-Length';

  /// The HTTP `Content-Location` header.
  /// See [Section 3.1.4.2 of RFC 7231](https://tools.ietf.org/html/rfc7231#section-3.1.4.2).
  static const String contentLocation = 'Content-Location';

  /// The HTTP `Content-Range` header.
  /// See [Section 4.2 of RFC 7233](https://tools.ietf.org/html/rfc7233#section-4.2).
  static const String contentRange = 'Content-Range';

  /// The HTTP `Content-Type` header.
  /// See [Section 3.1.1.5 of RFC 7231](https://tools.ietf.org/html/rfc7231#section-3.1.1.5).
  static const String contentType = 'Content-Type';

  /// The HTTP `Cookie` header.
  /// See [Section 4.3.4 of RFC 2109](https://tools.ietf.org/html/rfc2109#section-4.3.4).
  static const String cookie = 'Cookie';

  /// The HTTP `Date` header.
  /// See [Section 7.1.1.2 of RFC 7231](https://tools.ietf.org/html/rfc7231#section-7.1.1.2).
  static const String date = 'Date';

  /// The HTTP `ETag` header.
  /// See [Section 2.3 of RFC 7232](https://tools.ietf.org/html/rfc7232#section-2.3).
  static const String etag = 'ETag';

  /// The HTTP `Expect` header.
  /// See [Section 5.1.1 of RFC 7231](https://tools.ietf.org/html/rfc7231#section-5.1.1).
  static const String expect = 'Expect';

  /// The HTTP `Expires` header.
  /// See [Section 5.3 of RFC 7234](https://tools.ietf.org/html/rfc7234#section-5.3).
  static const String expires = 'Expires';

  /// The HTTP `From` header.
  /// See [Section 5.5.1 of RFC 7231](https://tools.ietf.org/html/rfc7231#section-5.5.1).
  static const String from = 'From';

  /// The HTTP `Host` header.
  /// See [Section 5.4 of RFC 7230](https://tools.ietf.org/html/rfc7230#section-5.4).
  static const String host = 'Host';

  /// The HTTP `If-Match` header.
  /// See [Section 3.1 of RFC 7232](https://tools.ietf.org/html/rfc7232#section-3.1).
  static const String ifMatch = 'If-Match';

  /// The HTTP `If-Modified-Since` header.
  /// See [Section 3.3 of RFC 7232](https://tools.ietf.org/html/rfc7232#section-3.3).
  static const String ifModifiedSince = 'If-Modified-Since';

  /// The HTTP `If-None-Match` header.
  /// See [Section 3.2 of RFC 7232](https://tools.ietf.org/html/rfc7232#section-3.2).
  static const String ifNoneMatch = 'If-None-Match';

  /// The HTTP `If-Range` header.
  /// See [Section 3.2 of RFC 7233](https://tools.ietf.org/html/rfc7233#section-3.2).
  static const String ifRange = 'If-Range';

  /// The HTTP `If-Unmodified-Since` header.
  /// See [Section 3.4 of RFC 7232](https://tools.ietf.org/html/rfc7232#section-3.4).
  static const String ifUnmodifiedSince = 'If-Unmodified-Since';

  /// The HTTP `Last-Modified` header.
  /// See [Section 2.2 of RFC 7232](https://tools.ietf.org/html/rfc7232#section-2.2).
  static const String lastModified = 'Last-Modified';

  /// The HTTP `Link` header.
  /// See [RFC 5988](https://tools.ietf.org/html/rfc5988).
  static const String link = 'Link';

  /// The HTTP `Location` header.
  /// See [Section 7.1.2 of RFC 7231](https://tools.ietf.org/html/rfc7231#section-7.1.2).
  static const String location = 'Location';

  /// The HTTP `Max-Forwards` header.
  /// See [Section 5.1.2 of RFC 7231](https://tools.ietf.org/html/rfc7231#section-5.1.2).
  static const String maxForwards = 'Max-Forwards';

  /// The HTTP `Origin` header.
  /// See [RFC 6454](https://tools.ietf.org/html/rfc6454).
  static const String origin = 'Origin';

  /// The HTTP `Pragma` header.
  /// See [Section 5.4 of RFC 7234](https://tools.ietf.org/html/rfc7234#section-5.4).
  static const String pragma = 'Pragma';

  /// The HTTP `Proxy-Authenticate` header.
  /// See [Section 4.3 of RFC 7235](https://tools.ietf.org/html/rfc7235#section-4.3).
  static const String proxyAuthenticate = 'Proxy-Authenticate';

  /// The HTTP `Proxy-Authorization` header.
  /// See [Section 4.4 of RFC 7235](https://tools.ietf.org/html/rfc7235#section-4.4).
  static const String proxyAuthorization = 'Proxy-Authorization';

  /// The HTTP `Range` header.
  /// See [Section 3.1 of RFC 7233](https://tools.ietf.org/html/rfc7233#section-3.1).
  static const String range = 'Range';

  /// The HTTP `Referer` header.
  /// See [Section 5.5.2 of RFC 7231](https://tools.ietf.org/html/rfc7231#section-5.5.2).
  static const String referer = 'Referer';

  /// The HTTP `Retry-After` header.
  /// See [Section 7.1.3 of RFC 7231](https://tools.ietf.org/html/rfc7231#section-7.1.3).
  static const String retryAfter = 'Retry-After';

  /// The HTTP `Server` header.
  /// See [Section 7.4.2 of RFC 7231](https://tools.ietf.org/html/rfc7231#section-7.4.2).
  static const String server = 'Server';

  /// The HTTP `Set-Cookie` header.
  /// See [Section 4.2.2 of RFC 2109](https://tools.ietf.org/html/rfc2109#section-4.2.2).
  static const String setCookie = 'Set-Cookie';

  /// The HTTP `Set-Cookie2` header.
  /// See [RFC 2965](https://tools.ietf.org/html/rfc2965).
  static const String setCookie2 = 'Set-Cookie2';

  /// The HTTP `TE` header.
  /// See [Section 4.3 of RFC 7230](https://tools.ietf.org/html/rfc7230#section-4.3).
  static const String te = 'TE';

  /// The HTTP `Trailer` header.
  /// See [Section 4.4 of RFC 7230](https://tools.ietf.org/html/rfc7230#section-4.4).
  static const String trailer = 'Trailer';

  /// The HTTP `Transfer-Encoding` header.
  /// See [Section 3.3.1 of RFC 7230](https://tools.ietf.org/html/rfc7230#section-3.3.1).
  static const String transferEncoding = 'Transfer-Encoding';

  /// The HTTP `Upgrade` header.
  /// See [Section 6.7 of RFC 7230](https://tools.ietf.org/html/rfc7230#section-6.7).
  static const String upgrade = 'Upgrade';

  /// The HTTP `User-Agent` header.
  /// See [Section 5.5.3 of RFC 7231](https://tools.ietf.org/html/rfc7231#section-5.5.3).
  static const String userAgent = 'User-Agent';

  /// The HTTP `Vary` header.
  /// See [Section 7.1.4 of RFC 7231](https://tools.ietf.org/html/rfc7231#section-7.1.4).
  static const String vary = 'Vary';

  /// The HTTP `Via` header.
  /// See [Section 5.7.1 of RFC 7230](https://tools.ietf.org/html/rfc7230#section-5.7.1).
  static const String via = 'Via';

  /// The HTTP `Warning` header.
  /// See [Section 5.5 of RFC 7234](https://tools.ietf.org/html/rfc7234#section-5.5).
  static const String warning = 'Warning';

  /// The HTTP `WWW-Authenticate` header.
  /// See [Section 4.1 of RFC 7235](https://tools.ietf.org/html/rfc7235#section-4.1).
  static const String wwwAuthenticate = 'WWW-Authenticate';

  /// The id of a request (not standard, but widely used): Winter reads it from the request, or
  /// generates one, and sends it back in the response (see `requestId`).
  static const String xRequestId = 'X-Request-Id';

  /// Stops a browser from guessing the type of a response (`nosniff`)
  static const String xContentTypeOptions = 'X-Content-Type-Options';

  /// Whether a browser may show the response in a frame (`DENY`)
  static const String xFrameOptions = 'X-Frame-Options';

  /// How much of the URL a browser sends as the `Referer` of the next request
  static const String referrerPolicy = 'Referrer-Policy';

  /// What a browser may load for the response
  static const String contentSecurityPolicy = 'Content-Security-Policy';

  /// HSTS: the browser only uses HTTPS for the domain
  static const String strictTransportSecurity = 'Strict-Transport-Security';
}
