import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:winter/winter.dart';

/// Makes a `POST` or a `PATCH` safe to retry, with the `Idempotency-Key` header of the IETF draft
/// (`draft-ietf-httpapi-idempotency-key-header`), as payment APIs (Stripe, Adyen) do: a client
/// that didn't get the answer (a timeout, a dropped connection) sends the request again with the
/// same key, and gets the first answer instead of paying twice.
///
/// ```dart
/// Route.post(
///   path: '/payments',
///   filterConfig: FilterConfig([
///     AuthFilter(),
///     IdempotencyFilter(partition: (request) => requestPrincipal<User>().id),
///   ]),
///   handler: createPayment,
/// )
/// ```
///
/// - The first request runs, and its response is kept for [expiry].
/// - The same key and the same body: the kept response, with `Idempotent-Replayed: true`, and the
///   handler doesn't run again.
/// - The same key with another body or query: a 422. While the first one is still running: a 409.
/// - No key (when [required]), or one that isn't valid: a 400.
///
/// A response of 500 or more, a 408, a 425 or a 429 is not kept: the client may try again with the
/// same key. Neither is a stream (Server-Sent Events). A `GET`, `HEAD` or `OPTIONS` is never
/// filtered: they are idempotent already.
///
/// The key is unique per method and path, and per user: without [partition], an authenticated
/// request whose principal is a `String` or a number (an id) gets its own keys, so two users
/// sending the same key and the same body never get each other's response. With another principal
/// (an object), give [partition] (a warning is logged once). Put the filter after the
/// `AuthFilter`, so a 401 isn't kept.
///
/// {@category Filters}
class IdempotencyFilter extends Filter {
  /// Where the keys and their responses are kept (in memory by default: per isolate and per
  /// process; several instances need a shared one)
  final IdempotencyStore store;

  /// How long a key is remembered (24 hours by default)
  final Duration expiry;

  /// Whether a request without `Idempotency-Key` is a 400 (true by default); when false, it runs
  /// as if there was no filter
  final bool required;

  /// Who the key belongs to, besides the method and the path (the user, the API key...). Null:
  /// the principal of the request when it's a `String` or a number
  final FutureOr<String> Function(RequestEntity request)? partition;

  var _warnedShared = false;

  /// A filter that keeps the responses in [store] for [expiry]
  IdempotencyFilter({
    IdempotencyStore? store,
    this.expiry = const Duration(hours: 24),
    this.required = true,
    this.partition,
    super.order,
  }) : store = store ?? InMemoryIdempotencyStore() {
    if (expiry <= Duration.zero) {
      throw ArgumentError.value(expiry, 'expiry', 'Must be more than 0');
    }
  }

  static final RegExp _keyChars = RegExp(r'^[\x20-\x7E]{1,255}$');

  /// The value of `Idempotency-Key`: a Structured Field String (`"8e03978e"`, the draft) or the
  /// bare value (what most clients send), of 1 to 255 printable ASCII characters; null for none,
  /// a 400 for one that isn't valid
  static String? _key(RequestEntity request) {
    final String? header = request.headers[HttpHeader.idempotencyKey]?.trim();
    if (header == null) return null;
    final String key =
        header.length >= 2 && header.startsWith('"') && header.endsWith('"')
        ? header
              .substring(1, header.length - 1)
              .replaceAllMapped(RegExp(r'\\(.)'), (m) => m[1]!)
        : header;
    if (!_keyChars.hasMatch(key)) {
      throw const BadRequestException(
        detail: 'Idempotency-Key must have 1 to 255 printable ASCII characters',
      );
    }
    return key;
  }

  @override
  bool shouldFilter(RequestEntity request) =>
      !const {'GET', 'HEAD', 'OPTIONS'}.contains(request.method) &&
      super.shouldFilter(request);

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final String? key = _key(request);
    if (key == null) {
      if (!required) return chain.doFilter(request);
      throw const BadRequestException(
        detail: 'This operation needs an Idempotency-Key header',
      );
    }
    final String? owner = partition == null
        ? _principalOf(request)
        : await partition!(request);
    // A JSON list, not the parts joined: a key or a partition with a space can't make the id of
    // another one (`carol` + `k2 x` and `carol k2` + `x`)
    final String id = jsonEncode([
      request.method,
      request.requestedUri.path,
      owner,
      key,
    ]);
    // bytes() is cached: the handler reads the same body with body<T>()
    final String fingerprint = _fingerprint(
      request.requestedUri.query,
      await request.bytes(),
    );

    final IdempotencyRecord? record = await store.reserve(
      id,
      fingerprint: fingerprint,
      expiry: expiry,
    );
    if (record != null) {
      if (record.fingerprint != fingerprint) {
        throw const UnprocessableContentException(
          detail: 'This Idempotency-Key was used with another request body',
        );
      }
      final IdempotentResponse? kept = record.response;
      if (kept == null) {
        throw const ConflictException(
          detail: 'A request with this Idempotency-Key is still running',
        );
      }
      return ResponseEntity<Uint8List>(
        kept.statusCode,
        // A response without body is replayed without one (and without a Content-Type)
        body: kept.body.isEmpty ? null : kept.body,
        headers: {...kept.headers, HttpHeader.idempotentReplayed: 'true'},
      );
    }

    final ResponseEntity response;
    try {
      response = await chain.doFilter(request);
    } catch (_) {
      // Only without an exception handler (unit tests): nothing to keep
      await store.release(id);
      rethrow;
    }
    if (!_keeps(response)) {
      await store.release(id);
      return response;
    }
    final BytesBuilder bytes = BytesBuilder(copy: false);
    await response.read().forEach(bytes.add);
    await store.complete(
      id,
      IdempotentResponse(
        statusCode: response.statusCode,
        headers: {
          for (final MapEntry(:key, :value) in response.headersAll.entries)
            if (key.toLowerCase() != 'content-length') key: value,
        },
        body: bytes.takeBytes(),
      ),
    );
    return response;
  }

  /// Whether [response] is the final answer to the request: not a failure of the server nor a
  /// temporary one (a timeout, too early, too many requests), and not a stream
  static bool _keeps(ResponseEntity response) {
    final int status = response.statusCode;
    return status < 500 &&
        status != 408 &&
        status != 425 &&
        status != 429 &&
        !response.isStreamed;
  }

  /// The principal of an authenticated request when it's an id (a `String` or a number). Any other
  /// has no stable text to tell users apart: their keys are shared, and a warning says so once.
  String? _principalOf(RequestEntity request) {
    final RequestSecurityContext context = request.securityContext;
    if (!context.isAuthenticated) return null;
    final Object? principal = context.authentication?.principal;
    if (principal is String || principal is num) return '$principal';
    if (!_warnedShared) {
      _warnedShared = true;
      logger.warning(
        'IdempotencyFilter without partition: the principal is a ${principal.runtimeType}, so '
        'its users share their keys; give partition: (request) => <the id of the user>',
      );
    }
    return null;
  }

  /// FNV-1a of 64 bits of the [query] and the [bytes] of the body, with their length: enough to
  /// tell two requests of the same client apart (it's not a cryptographic hash, and it doesn't
  /// need to be)
  static String _fingerprint(String query, Uint8List bytes) {
    var hash = 0xcbf29ce484222325;
    // The ints of the VM have 64 bits and wrap around, as FNV needs
    void add(int byte) => hash = (hash ^ byte) * 0x100000001b3;
    // The query, then a byte no UTF-8 text has, then the body: in place, never a copy of the body
    utf8.encode(query).forEach(add);
    add(0xFF);
    bytes.forEach(add);
    return '${bytes.length}:${hash.toUnsigned(64).toRadixString(16)}';
  }
}

/// A response kept to answer it again
///
/// {@category Filters}
final class IdempotentResponse {
  /// Its status
  final int statusCode;

  /// Its headers, every value of each one
  final Map<String, List<String>> headers;

  /// Its body
  final Uint8List body;

  /// A kept response
  const IdempotentResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });
}

/// What an [IdempotencyStore] has for a key: the fingerprint of the body of its first request,
/// and its response, or null while it's still running
///
/// {@category Filters}
final class IdempotencyRecord {
  /// The fingerprint of the body of the first request
  final String fingerprint;

  /// The response of the first request, or null while it's still running
  final IdempotentResponse? response;

  /// A record of a key
  const IdempotencyRecord({required this.fingerprint, this.response});
}

/// Where an [IdempotencyFilter] keeps its keys. It's asynchronous so a shared store (Redis, a
/// database) can implement it; [reserve] must be atomic for a key.
///
/// {@category Filters}
abstract interface class IdempotencyStore {
  /// Reserves [key] for a request whose body has [fingerprint], for [expiry], and returns null;
  /// or, when [key] is already there (and not expired), returns its record without changing it
  Future<IdempotencyRecord?> reserve(
    String key, {
    required String fingerprint,
    required Duration expiry,
  });

  /// Keeps [response] as the answer of [key]
  Future<void> complete(String key, IdempotentResponse response);

  /// Forgets [key], so the next request with it runs again
  Future<void> release(String key);

  /// Forgets every key
  Future<void> clear();
}

/// The default [IdempotencyStore]: in memory, per isolate and per process. A key is forgotten
/// [IdempotencyFilter.expiry] after its first request; the expired ones are purged once a minute,
/// as the store is used.
///
/// {@category Filters}
class InMemoryIdempotencyStore implements IdempotencyStore {
  /// The time now (`DateTime.now` by default; a fake one in tests)
  final DateTime Function() clock;

  /// The most keys kept: a new one past it forgets the oldest, so a client sending a new key with
  /// every request can't grow the memory without end
  final int maxKeys;

  /// The most bytes of responses kept (bodies and headers, 64 MB by default): a new one past it
  /// forgets the oldest, and a response bigger than all of it isn't kept (a retry runs again).
  /// [maxKeys] alone would let large responses (or ones that echo the request) fill the memory.
  final int maxBytes;

  /// In the order they were reserved: the first is the oldest
  final Map<String, (IdempotencyRecord, DateTime expires)> _keys = {};

  /// The size of every kept response, by key
  final Map<String, int> _sizes = {};
  int _bytes = 0;
  DateTime? _lastPurge;

  /// An empty store of at most [maxKeys] and [maxBytes]
  InMemoryIdempotencyStore({
    this.clock = DateTime.now,
    this.maxKeys = 100000,
    this.maxBytes = 64 * 1024 * 1024,
  }) {
    if (maxKeys < 1) {
      throw ArgumentError.value(maxKeys, 'maxKeys', 'Must be at least 1');
    }
    if (maxBytes < 1) {
      throw ArgumentError.value(maxBytes, 'maxBytes', 'Must be at least 1');
    }
  }

  /// How many keys are kept (to watch the memory)
  int get size => _keys.length;

  /// How many bytes of responses are kept (to watch the memory)
  int get bytes => _bytes;

  @override
  Future<IdempotencyRecord?> reserve(
    String key, {
    required String fingerprint,
    required Duration expiry,
  }) async {
    final DateTime now = clock();
    _purge(now);
    final (IdempotencyRecord, DateTime)? entry = _keys[key];
    if (entry != null && now.isBefore(entry.$2)) return entry.$1;
    _remove(key);
    if (_keys.length >= maxKeys) _remove(_keys.keys.first);
    _keys[key] = (IdempotencyRecord(fingerprint: fingerprint), now.add(expiry));
    return null;
  }

  @override
  Future<void> complete(String key, IdempotentResponse response) async {
    final (IdempotencyRecord, DateTime)? entry = _keys[key];
    if (entry == null) return;
    final int size =
        response.body.length +
        response.headers.entries.fold(
          0,
          (total, header) =>
              total +
              header.key.length +
              header.value.fold(0, (sum, value) => sum + value.length),
        );
    if (size > maxBytes) {
      _remove(key);
      return;
    }
    _keys[key] = (
      IdempotencyRecord(fingerprint: entry.$1.fingerprint, response: response),
      entry.$2,
    );
    _sizes[key] = size;
    _bytes += size;
    while (_bytes > maxBytes) {
      _remove(_sizes.keys.first);
    }
  }

  @override
  Future<void> release(String key) async => _remove(key);

  @override
  Future<void> clear() async {
    _keys.clear();
    _sizes.clear();
    _bytes = 0;
  }

  void _remove(String key) {
    _keys.remove(key);
    _bytes -= _sizes.remove(key) ?? 0;
  }

  void _purge(DateTime now) {
    final DateTime? last = _lastPurge;
    if (last != null && now.difference(last) < const Duration(minutes: 1)) {
      return;
    }
    _lastPurge = now;
    [
      for (final MapEntry(:key, :value) in _keys.entries)
        if (!now.isBefore(value.$2)) key,
    ].forEach(_remove);
  }
}
