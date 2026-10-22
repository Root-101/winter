import 'dart:io';

import 'package:winter/winter.dart';

/// The headers the trusted proxies write about the client
///
/// {@category Server}
enum ForwardedHeaders {
  /// `Forwarded` (RFC 7239): `for=203.0.113.7;proto=https;host=api.example.com`
  forwarded,

  /// `X-Forwarded-For`, `X-Forwarded-Proto` and `X-Forwarded-Host`: what nginx, the load
  /// balancers of AWS and Google, Cloud Run, Heroku and Kubernetes ingresses send
  xForwarded,
}

/// The reverse proxies in front of the app (a load balancer, nginx, an ingress), whose headers
/// about the client are trusted. Without it (the default) they are ignored: any client can send
/// them, with a fake IP to bypass a rate limiter or a fake host to poison a link.
///
/// ```dart
/// await Winter.start(config: const ServerConfig(trustedProxies: TrustedProxies(1)));
/// ```
///
/// With it, for every request:
///
/// - [RequestEntity.clientIp] is the address that the outermost of the [count] proxies saw (each
///   proxy adds the address it received from). One that isn't an IP is ignored.
/// - [RequestEntity.requestedUri] gets the scheme (`http` or `https`) and the host (with its
///   port) that the client used, so `Location`, the `instance` of the errors and OpenAPI see the
///   public URL. A value that isn't valid is ignored.
///
/// Only [headers] are read, never the other kind: a proxy that writes `X-Forwarded-For` lets a
/// client's `Forwarded` through untouched. The proxies must set (or overwrite) the scheme and
/// the host they forward.
///
/// {@category Server}
final class TrustedProxies {
  /// How many proxies in front of the app add their entry (at least 1)
  final int count;

  /// The headers they write
  final ForwardedHeaders headers;

  /// [count] proxies that write [headers]
  const TrustedProxies(
    this.count, {
    this.headers = ForwardedHeaders.xForwarded,
  });

  /// An [ArgumentError] when [count] is below 1 (a `const` constructor can't check it)
  void validate() {
    if (count < 1) {
      throw ArgumentError.value(count, 'count', 'Must be at least 1');
    }
  }
}

/// The client address that the trusted proxies forwarded, in the context of the request
final ContextKey<String> forwardedClientIpKey = ContextKey<String>(
  'winter.forwardedClientIp',
);

/// [request] as the client sent it, read from the headers of the [proxies]: the client address
/// (in [forwardedClientIpKey]) and the scheme and host of [RequestEntity.requestedUri]
RequestEntity applyTrustedProxies(
  RequestEntity request,
  TrustedProxies proxies,
) {
  final _Hop hop = switch (proxies.headers) {
    ForwardedHeaders.forwarded => _forwardedHop(request, proxies.count),
    ForwardedHeaders.xForwarded => _xForwardedHop(request, proxies.count),
  };
  final String? proto = hop.proto?.toLowerCase();
  final String? scheme = proto == 'http' || proto == 'https' ? proto : null;
  final Uri? host = parseHost(hop.host);
  final RequestEntity forwarded = scheme == null && host == null
      ? request
      : request.copyWith(
          requestedUri: _forwardedUri(request.requestedUri, scheme, host),
        );
  final String? clientIp = hop.clientIp;
  if (clientIp != null && InternetAddress.tryParse(clientIp) != null) {
    forwarded.context.set(forwardedClientIpKey, clientIp);
  }
  return forwarded;
}

/// [uri] with the [scheme] and the [host] of the client (each one only when given). Without a
/// port of its own, the host gets the default one of the scheme.
Uri _forwardedUri(Uri uri, String? scheme, Uri? host) {
  final String newScheme = scheme ?? uri.scheme;
  int defaultPort(String scheme) => scheme == 'https' ? 443 : 80;
  final int port = host != null
      ? (host.hasPort ? host.port : defaultPort(newScheme))
      : (uri.port == defaultPort(uri.scheme)
            ? defaultPort(newScheme)
            : uri.port);
  return uri.replace(
    scheme: newScheme,
    host: host?.host ?? uri.host,
    port: port,
  );
}

final RegExp _hostChars = RegExp(r'^[A-Za-z0-9.\-\[\]:]+$');

/// A `host[:port]` (of a `Host` header or a forwarded one), or null when it isn't one (a path, a
/// user, a query...)
Uri? parseHost(String? value) {
  if (value == null || !_hostChars.hasMatch(value)) return null;
  final Uri? uri = Uri.tryParse('http://$value');
  return uri == null || uri.host.isEmpty ? null : uri;
}

/// What the outermost trusted proxy saw
typedef _Hop = ({String? clientIp, String? proto, String? host});

const _Hop _noHop = (clientIp: null, proto: null, host: null);

/// Every value of a header, split by commas
List<String> _values(RequestEntity request, String name) => [
  for (final String line in request.headersAll[name] ?? const <String>[])
    for (final String value in line.split(','))
      if (value.trim().isNotEmpty) value.trim(),
];

/// Each proxy appends the address it received from: the one that the first of the [count]
/// proxies added is the client. The scheme and the host are the entry at the same place, or the
/// first one when the proxies overwrite them with one value.
_Hop _xForwardedHop(RequestEntity request, int count) {
  final List<String> ips = _values(request, HttpHeader.xForwardedFor);
  String? at(List<String> values) => values.isEmpty
      ? null
      : values[(values.length - count).clamp(0, values.length - 1)];
  final int index = ips.length - count;
  return (
    clientIp: index >= 0 ? ips[index] : null,
    proto: at(_values(request, HttpHeader.xForwardedProto)),
    host: at(_values(request, HttpHeader.xForwardedHost)),
  );
}

/// The element of `Forwarded` that the first of the [count] proxies added (RFC 7239: one per
/// proxy, appended), with its `for`, `proto` and `host`
_Hop _forwardedHop(RequestEntity request, int count) {
  final List<Map<String, String>> elements = [];
  for (final String line
      in request.headersAll[HttpHeader.forwarded] ?? const <String>[]) {
    final List<Map<String, String>>? parsed = _forwardedElements(line);
    if (parsed == null) return _noHop;
    elements.addAll(parsed);
  }
  final int index = elements.length - count;
  if (index < 0) return _noHop;
  final Map<String, String> element = elements[index];
  return (
    clientIp: _node(element['for']),
    proto: element['proto'],
    host: element['host'],
  );
}

/// The elements of a `Forwarded` line: `name=value` pairs split by `;`, elements by `,`; a value
/// is a token or a quoted string (with `\` escapes). Null for a line that ends inside a quoted
/// string: it would swallow the elements after it, the one of the proxy included.
List<Map<String, String>>? _forwardedElements(String line) {
  final List<Map<String, String>> elements = [{}];
  final StringBuffer name = StringBuffer();
  final StringBuffer value = StringBuffer();
  var inValue = false;
  var quoted = false;
  void endPair() {
    final String key = name.toString().trim().toLowerCase();
    if (key.isNotEmpty) elements.last[key] = value.toString().trim();
    name.clear();
    value.clear();
    inValue = false;
  }

  for (var i = 0; i < line.length; i++) {
    final String char = line[i];
    if (quoted) {
      if (char == r'\' && i + 1 < line.length) {
        value.write(line[++i]);
      } else if (char == '"') {
        quoted = false;
      } else {
        value.write(char);
      }
    } else if (char == '"' && inValue) {
      quoted = true;
    } else if (char == '=' && !inValue) {
      inValue = true;
    } else if (char == ';') {
      endPair();
    } else if (char == ',') {
      endPair();
      elements.add({});
    } else {
      (inValue ? value : name).write(char);
    }
  }
  if (quoted) return null;
  endPair();
  return elements;
}

/// The address of a `for` node: `192.0.2.43`, `192.0.2.43:4711`, `[2001:db8::17]:4711`; null
/// for `unknown` and an obfuscated one (`_hidden`)
String? _node(String? node) {
  if (node == null) return null;
  if (node.startsWith('[')) {
    final int end = node.indexOf(']');
    return end < 0 ? null : node.substring(1, end);
  }
  final int colon = node.indexOf(':');
  // More than one colon: an IPv6 without brackets (invalid, but kept for tryParse to decide)
  return colon < 0 || node.indexOf(':', colon + 1) >= 0
      ? node
      : node.substring(0, colon);
}
