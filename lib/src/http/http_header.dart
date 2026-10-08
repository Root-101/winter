class HttpHeader {
  /// The `X-Forwarded-For` header, added by proxies with the address of the client
  /// (de facto standard, not in the HTTP spec).
  static const String xForwardedFor = 'X-Forwarded-For';

  /// The HTTP {@code Accept} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-5.3.2">Section 5.3.2 of RFC 7231</a>
  static const String accept = 'Accept';

  /// The HTTP {@code Accept-Charset} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-5.3.3">Section 5.3.3 of RFC 7231</a>
  static const String acceptCharset = 'Accept-Charset';

  /// The HTTP {@code Accept-Encoding} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-5.3.4">Section 5.3.4 of RFC 7231</a>
  static const String acceptEncoding = 'Accept-Encoding';

  /// The HTTP {@code Accept-Language} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-5.3.5">Section 5.3.5 of RFC 7231</a>
  static const String acceptLanguage = 'Accept-Language';

  /// The HTTP {@code Accept-Patch} header field name.
  /// @since 5.3.6
  /// @see <a href="https://tools.ietf.org/html/rfc5789#section-3.1">Section 3.1 of RFC 5789</a>
  static const String acceptPatch = 'Accept-Patch';

  /// The HTTP {@code Accept-Ranges} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7233#section-2.3">Section 5.3.5 of RFC 7233</a>
  static const String acceptRanges = 'Accept-Ranges';

  /// The CORS {@code Access-Control-Allow-Credentials} response header field name.
  /// @see <a href="https://www.w3.org/TR/cors/">CORS W3C recommendation</a>
  static const String accessControlAllowCredentials =
      'Access-Control-Allow-Credentials';

  /// The CORS {@code Access-Control-Allow-Headers} response header field name.
  /// @see <a href="https://www.w3.org/TR/cors/">CORS W3C recommendation</a>
  static const String accessControlAllowHeaders =
      'Access-Control-Allow-Headers';

  /// The CORS {@code Access-Control-Allow-Methods} response header field name.
  /// @see <a href="https://www.w3.org/TR/cors/">CORS W3C recommendation</a>
  static const String accessControlAllowMethods =
      'Access-Control-Allow-Methods';

  /// The CORS {@code Access-Control-Allow-Origin} response header field name.
  /// @see <a href="https://www.w3.org/TR/cors/">CORS W3C recommendation</a>
  static const String accessControlAllowOrigin = 'Access-Control-Allow-Origin';

  /// The CORS {@code Access-Control-Expose-Headers} response header field name.
  /// @see <a href="https://www.w3.org/TR/cors/">CORS W3C recommendation</a>
  static const String accessControlExposeHeaders =
      'Access-Control-Expose-Headers';

  /// The CORS {@code Access-Control-Max-Age} response header field name.
  /// @see <a href="https://www.w3.org/TR/cors/">CORS W3C recommendation</a>
  static const String accessControlMaxAge = 'Access-Control-Max-Age';

  /// The CORS {@code Access-Control-Request-Headers} request header field name.
  /// @see <a href="https://www.w3.org/TR/cors/">CORS W3C recommendation</a>
  static const String accessControlRequestHeaders =
      'Access-Control-Request-Headers';

  /// The CORS {@code Access-Control-Request-Method} request header field name.
  /// @see <a href="https://www.w3.org/TR/cors/">CORS W3C recommendation</a>
  static const String accessControlRequestMethod =
      'Access-Control-Request-Method';

  /// The HTTP {@code Age} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7234#section-5.1">Section 5.1 of RFC 7234</a>
  static const String age = 'Age';

  /// The HTTP {@code Allow} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-7.4.1">Section 7.4.1 of RFC 7231</a>
  static const String allow = 'Allow';

  /// The HTTP {@code Authorization} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7235#section-4.2">Section 4.2 of RFC 7235</a>
  static const String authorization = 'Authorization';

  /// The HTTP {@code Cache-Control} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7234#section-5.2">Section 5.2 of RFC 7234</a>
  static const String cacheControl = 'Cache-Control';

  /// The HTTP {@code Connection} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7230#section-6.1">Section 6.1 of RFC 7230</a>
  static const String connection = 'Connection';

  /// The HTTP {@code Content-Encoding} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-3.1.2.2">Section 3.1.2.2 of RFC 7231</a>
  static const String contentEncoding = 'Content-Encoding';

  /// The HTTP {@code Content-Disposition} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc6266">RFC 6266</a>
  static const String contentDisposition = 'Content-Disposition';

  /// The HTTP {@code Content-Language} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-3.1.3.2">Section 3.1.3.2 of RFC 7231</a>
  static const String contentLanguage = 'Content-Language';

  /// The HTTP {@code Content-Length} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7230#section-3.3.2">Section 3.3.2 of RFC 7230</a>
  static const String contentLength = 'Content-Length';

  /// The HTTP {@code Content-Location} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-3.1.4.2">Section 3.1.4.2 of RFC 7231</a>
  static const String contentLocation = 'Content-Location';

  /// The HTTP {@code Content-Range} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7233#section-4.2">Section 4.2 of RFC 7233</a>
  static const String contentRange = 'Content-Range';

  /// The HTTP {@code Content-Type} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-3.1.1.5">Section 3.1.1.5 of RFC 7231</a>
  static const String contentType = 'Content-Type';

  /// The HTTP {@code Cookie} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc2109#section-4.3.4">Section 4.3.4 of RFC 2109</a>
  static const String cookie = 'Cookie';

  /// The HTTP {@code Date} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-7.1.1.2">Section 7.1.1.2 of RFC 7231</a>
  static const String date = 'Date';

  /// The HTTP {@code ETag} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7232#section-2.3">Section 2.3 of RFC 7232</a>
  static const String etag = 'ETag';

  /// The HTTP {@code Expect} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-5.1.1">Section 5.1.1 of RFC 7231</a>
  static const String expect = 'Expect';

  /// The HTTP {@code Expires} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7234#section-5.3">Section 5.3 of RFC 7234</a>
  static const String expires = 'Expires';

  /// The HTTP {@code From} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-5.5.1">Section 5.5.1 of RFC 7231</a>
  static const String from = 'From';

  /// The HTTP {@code Host} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7230#section-5.4">Section 5.4 of RFC 7230</a>
  static const String host = 'Host';

  /// The HTTP {@code If-Match} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7232#section-3.1">Section 3.1 of RFC 7232</a>
  static const String ifMatch = 'If-Match';

  /// The HTTP {@code If-Modified-Since} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7232#section-3.3">Section 3.3 of RFC 7232</a>
  static const String ifModifiedSince = 'If-Modified-Since';

  /// The HTTP {@code If-None-Match} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7232#section-3.2">Section 3.2 of RFC 7232</a>
  static const String ifNoneMatch = 'If-None-Match';

  /// The HTTP {@code If-Range} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7233#section-3.2">Section 3.2 of RFC 7233</a>
  static const String ifRange = 'If-Range';

  /// The HTTP {@code If-Unmodified-Since} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7232#section-3.4">Section 3.4 of RFC 7232</a>
  static const String ifUnmodifiedSince = 'If-Unmodified-Since';

  /// The HTTP {@code Last-Modified} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7232#section-2.2">Section 2.2 of RFC 7232</a>
  static const String lastModified = 'Last-Modified';

  /// The HTTP {@code Link} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc5988">RFC 5988</a>
  static const String link = 'Link';

  /// The HTTP {@code Location} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-7.1.2">Section 7.1.2 of RFC 7231</a>
  static const String location = 'Location';

  /// The HTTP {@code Max-Forwards} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-5.1.2">Section 5.1.2 of RFC 7231</a>
  static const String maxForwards = 'Max-Forwards';

  /// The HTTP {@code Origin} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc6454">RFC 6454</a>
  static const String origin = 'Origin';

  /// The HTTP {@code Pragma} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7234#section-5.4">Section 5.4 of RFC 7234</a>
  static const String pragma = 'Pragma';

  /// The HTTP {@code Proxy-Authenticate} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7235#section-4.3">Section 4.3 of RFC 7235</a>
  static const String proxyAuthenticate = 'Proxy-Authenticate';

  /// The HTTP {@code Proxy-Authorization} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7235#section-4.4">Section 4.4 of RFC 7235</a>
  static const String proxyAuthorization = 'Proxy-Authorization';

  /// The HTTP {@code Range} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7233#section-3.1">Section 3.1 of RFC 7233</a>
  static const String range = 'Range';

  /// The HTTP {@code Referer} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-5.5.2">Section 5.5.2 of RFC 7231</a>
  static const String referer = 'Referer';

  /// The HTTP {@code Retry-After} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-7.1.3">Section 7.1.3 of RFC 7231</a>
  static const String retryAfter = 'Retry-After';

  /// The HTTP {@code Server} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-7.4.2">Section 7.4.2 of RFC 7231</a>
  static const String server = 'Server';

  /// The HTTP {@code Set-Cookie} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc2109#section-4.2.2">Section 4.2.2 of RFC 2109</a>
  static const String setCookie = 'Set-Cookie';

  /// The HTTP {@code Set-Cookie2} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc2965">RFC 2965</a>
  static const String setCookie2 = 'Set-Cookie2';

  /// The HTTP {@code TE} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7230#section-4.3">Section 4.3 of RFC 7230</a>
  static const String te = 'TE';

  /// The HTTP {@code Trailer} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7230#section-4.4">Section 4.4 of RFC 7230</a>
  static const String trailer = 'Trailer';

  /// The HTTP {@code Transfer-Encoding} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7230#section-3.3.1">Section 3.3.1 of RFC 7230</a>
  static const String transferEncoding = 'Transfer-Encoding';

  /// The HTTP {@code Upgrade} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7230#section-6.7">Section 6.7 of RFC 7230</a>
  static const String upgrade = 'Upgrade';

  /// The HTTP {@code User-Agent} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-5.5.3">Section 5.5.3 of RFC 7231</a>
  static const String userAgent = 'User-Agent';

  /// The HTTP {@code Vary} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7231#section-7.1.4">Section 7.1.4 of RFC 7231</a>
  static const String vary = 'Vary';

  /// The HTTP {@code Via} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7230#section-5.7.1">Section 5.7.1 of RFC 7230</a>
  static const String via = 'Via';

  /// The HTTP {@code Warning} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7234#section-5.5">Section 5.5 of RFC 7234</a>
  static const String warning = 'Warning';

  /// The HTTP {@code WWW-Authenticate} header field name.
  /// @see <a href="https://tools.ietf.org/html/rfc7235#section-4.1">Section 4.1 of RFC 7235</a>
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
