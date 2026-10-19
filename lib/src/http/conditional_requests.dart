import 'dart:io' show HttpDate, HttpException;

import 'package:winter/winter.dart';

/// The preconditions of a request (RFC 9110 §13): `If-Match`, `If-Unmodified-Since`,
/// `If-None-Match` and `If-Modified-Since`.
///
/// A `GET` needs nothing: the server answers a **304** by itself when its response has an
/// `ETag` or a `Last-Modified` that the client already has. A change (`PUT`, `PATCH`, `DELETE`)
/// checks them before it's made, with the version the resource has now, so two clients editing
/// it don't overwrite each other:
///
/// ```dart
/// final Document current = store.find(id);
/// request.checkPreconditions(etag: current.etag, required: true); // 412 or 428
/// store.save(id, changes);
/// ```
///
/// {@category HTTP}
extension ConditionalRequests on RequestEntity {
  /// Evaluates the preconditions of this request against the current [etag] (a quoted
  /// entity-tag: `"7"` or `W/"7"`) and [lastModified] of the resource, in the order of RFC 9110
  /// §13.2.2, and throws when one fails:
  ///
  /// - `If-Match` (strong comparison; `*` is any existing resource), or without it
  ///   `If-Unmodified-Since`: a [PreconditionFailedException] (412) when it fails.
  /// - `If-None-Match` (weak comparison; `*` is any existing resource), or without it
  ///   `If-Modified-Since` (only in a `GET` or `HEAD`): a 304 for a `GET` or `HEAD`, a 412 for
  ///   any other method.
  /// - With [required], a request without `If-Match` nor `If-Unmodified-Since` is a
  ///   [PreconditionRequiredException] (428): the client must say which version it changes.
  ///
  /// [exists] is false when the resource doesn't exist yet (a `PUT` that creates it), so
  /// `If-Match: *` fails and `If-None-Match: *` passes.
  void checkPreconditions({
    String? etag,
    DateTime? lastModified,
    bool exists = true,
    bool required = false,
  }) {
    final String? ifMatch = headers[HttpHeader.ifMatch];
    final DateTime? ifUnmodifiedSince = parseHttpDate(
      headers[HttpHeader.ifUnmodifiedSince],
    );
    if (required && ifMatch == null && ifUnmodifiedSince == null) {
      throw const PreconditionRequiredException(
        detail: 'Send If-Match with the ETag of the version you change',
      );
    }
    if (ifMatch != null) {
      if (!exists || !_matches(ifMatch, etag, weak: false)) {
        throw const PreconditionFailedException(
          detail: 'The resource changed since you read it',
        );
      }
    } else if (ifUnmodifiedSince != null &&
        lastModified != null &&
        _seconds(lastModified) > _seconds(ifUnmodifiedSince)) {
      throw const PreconditionFailedException(
        detail: 'The resource changed since you read it',
      );
    }

    final bool read = _isRead(method);
    final String? ifNoneMatch = headers[HttpHeader.ifNoneMatch];
    final bool unchanged = ifNoneMatch != null
        ? exists && _matches(ifNoneMatch, etag, weak: true)
        : read && _notModifiedSince(this, lastModified);
    if (!unchanged) return;
    if (read) {
      throw ResponseException(
        ResponseEntity<void>(
          StatusCode.notModified.value,
          headers: {
            HttpHeader.etag: ?etag,
            if (lastModified != null)
              HttpHeader.lastModified: HttpDate.format(lastModified),
          },
        ),
      );
    }
    throw const PreconditionFailedException(
      detail: 'The resource already exists in that version',
    );
  }
}

/// The response of a `GET` or `HEAD` as a 304 when the client already has its version (the
/// `ETag` against `If-None-Match`, or without it the `Last-Modified` against
/// `If-Modified-Since`): what the server does with every response. Only a 200 or a 206 with a
/// validator changes; the 304 keeps the headers, without the body and its `Content-*`.
ResponseEntity notModifiedResponse(
  RequestEntity request,
  ResponseEntity response,
) {
  if (!_isRead(request.method)) return response;
  if (response.statusCode != StatusCode.ok.value &&
      response.statusCode != StatusCode.partialContent.value) {
    return response;
  }
  final String? etag = response.headers[HttpHeader.etag];
  final DateTime? lastModified = parseHttpDate(
    response.headers[HttpHeader.lastModified],
  );
  if (etag == null && lastModified == null) return response;

  final String? ifNoneMatch = request.headers[HttpHeader.ifNoneMatch];
  final bool unchanged = ifNoneMatch != null
      ? _matches(ifNoneMatch, etag, weak: true)
      : _notModifiedSince(request, lastModified);
  if (!unchanged) return response;
  return ResponseEntity<void>(
    StatusCode.notModified.value,
    headers: {
      for (final MapEntry(:key, :value) in response.headersAll.entries)
        if (!_bodyHeaders.contains(key.toLowerCase())) key: value,
    },
  );
}

/// The headers that describe a body, which a 304 doesn't have
const Set<String> _bodyHeaders = {
  'content-type',
  'content-length',
  'content-range',
  'content-encoding',
  'transfer-encoding',
};

/// An HTTP date (`Sun, 06 Nov 1994 08:49:37 GMT`), or null when [value] isn't one
DateTime? parseHttpDate(String? value) {
  if (value == null) return null;
  try {
    return HttpDate.parse(value);
  } on HttpException {
    return null;
  }
}

/// A `GET` or a `HEAD`: the methods that only read (a [RequestEntity.method] is upper case)
bool _isRead(String method) => method == 'GET' || method == 'HEAD';

/// Whole seconds: an HTTP date has no milliseconds
int _seconds(DateTime date) => date.millisecondsSinceEpoch ~/ 1000;

/// Whether `If-Modified-Since` of [request] is at or after [lastModified]
bool _notModifiedSince(RequestEntity request, DateTime? lastModified) {
  final DateTime? since = parseHttpDate(
    request.headers[HttpHeader.ifModifiedSince],
  );
  return since != null &&
      lastModified != null &&
      _seconds(lastModified) <= _seconds(since);
}

/// Whether the list of entity-tags [header] (`"1", W/"2"` or `*`) has [etag]. The strong
/// comparison (`If-Match`) needs both strong and equal; the weak one (`If-None-Match`) only the
/// same opaque value.
bool _matches(String header, String? etag, {required bool weak}) {
  if (header.trim() == '*') return true;
  if (etag == null) return false;
  final bool weakEtag = etag.startsWith('W/');
  if (!weak && weakEtag) return false;
  final String opaque = weakEtag ? etag.substring(2) : etag;
  for (final String tag in header.split(',')) {
    final String trimmed = tag.trim();
    final bool weakTag = trimmed.startsWith('W/');
    if (!weak && weakTag) continue;
    if ((weakTag ? trimmed.substring(2) : trimmed) == opaque) return true;
  }
  return false;
}

/// The comparison of two `If-Range` validators: a strong ETag equal to [etag], or an HTTP date
/// equal to [lastModified]
bool ifRangeMatches(String ifRange, String etag, DateTime lastModified) {
  final String value = ifRange.trim();
  if (value.startsWith('"') || value.startsWith('W/')) return value == etag;
  final DateTime? date = parseHttpDate(value);
  return date != null && _seconds(date) == _seconds(lastModified);
}
