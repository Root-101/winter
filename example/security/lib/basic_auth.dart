/// HTTP Basic authentication for an internal area (an admin panel, the metrics of a scraper):
/// the browser shows its own login dialog when it gets the `WWW-Authenticate: Basic` of the 401.
///
/// Only over HTTPS: the password goes in every request, only encoded in base64.
///
/// Run: `dart run lib/basic_auth.dart`, then `curl -u admin:s3cret localhost:8080/admin/metrics`
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:winter/winter.dart';

class BasicAuthFilter extends Filter {
  /// user → SHA-256 of the password (a real app uses a slow hash: bcrypt, argon2)
  final Map<String, String> passwordHashes;

  BasicAuthFilter(this.passwordHashes);

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final (String, String)? credentials = parseBasic(
      request.headers[HttpHeader.authorization],
    );
    if (credentials != null) {
      final (String user, String password) = credentials;
      final String? expected = passwordHashes[user];
      if (expected != null && constantTimeEquals(hash(password), expected)) {
        request.securityContext.setAuthentication(
          Authentication<String>(principal: user, roles: {'admin'}),
        );
      }
    }
    return chain.doFilter(request);
  }
}

String hash(String password) =>
    sha256.convert(utf8.encode(password)).toString();

/// `Basic YWRtaW46czNjcmV0` → (`admin`, `s3cret`); null when it isn't valid Basic
(String, String)? parseBasic(String? header) {
  if (header == null || !header.toLowerCase().startsWith('basic ')) return null;
  try {
    final String decoded = utf8.decode(
      base64.decode(header.substring(6).trim()),
    );
    final int colon = decoded.indexOf(':');
    if (colon < 0) return null;
    return (decoded.substring(0, colon), decoded.substring(colon + 1));
  } on FormatException {
    return null; // not base64, or not UTF-8: the same as no credentials
  }
}

/// Compares without stopping at the first difference, so the time doesn't tell how much of a
/// guess was right
bool constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  int difference = 0;
  for (int i = 0; i < a.length; i++) {
    difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return difference == 0;
}

WinterRouter router() => WinterRouter(
  routes: [
    Route.parent(
      path: '/admin',
      filterConfig: FilterConfig([
        BasicAuthFilter({'admin': hash('s3cret')}),
        AuthFilter(
          rules: hasRole('admin'),
          challenge: 'Basic realm="admin", charset="UTF-8"',
        ),
      ]),
      routes: [
        Route.get(
          path: '/metrics',
          handler: (request) => ResponseEntity.ok(
            body: {'user': requestPrincipal<String>(), 'requests': 1234},
          ),
        ),
      ],
    ),
  ],
);

Future<void> main() async => Winter.start(router: router());
