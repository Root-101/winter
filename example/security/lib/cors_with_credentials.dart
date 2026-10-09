/// A single-page app on another origin (`https://app.example.com`) that calls the API with the
/// session cookie (`fetch(url, {credentials: 'include'})`): CORS lists the origins, allows
/// credentials, answers the preflights and exposes the headers the app reads.
///
/// Run: `dart run lib/cors_with_credentials.dart`, then a preflight:
/// `curl -i -X OPTIONS localhost:8080/cart -H 'Origin: https://app.example.com' -H 'Access-Control-Request-Method: PUT'`
library;

import 'dart:io' show Cookie, SameSite;

import 'package:winter/winter.dart';

final SecurityConfig securityConfig = SecurityConfig(
  cors: const CorsConfig(
    // Never '*' with credentials: any website could call the API as the user
    allowedOrigins: ['https://app.example.com', 'http://localhost:5173'],
    allowCredentials: true,
    allowedMethods: ['GET', 'PUT', 'DELETE'],
    allowedHeaders: ['Content-Type'],
    exposedHeaders: ['X-Cart-Count'],
    // The browser keeps a preflight for 10 minutes
    maxAge: 600,
  ),
);

WinterRouter router() => WinterRouter(
  routes: [
    Route.get(
      path: '/cart',
      handler: (request) {
        if (request.cookie('session')?.value != 'abc') {
          throw const UnauthorizedException(
            headers: {HttpHeader.wwwAuthenticate: 'Cookie'},
          );
        }
        return ResponseEntity.ok(
          body: ['book', 'pen'],
          headers: {'X-Cart-Count': '2'},
        );
      },
    ),
    Route.put(path: '/cart', handler: (request) => ResponseEntity.noContent()),
    Route.get(
      path: '/session',
      // SameSite=None needs Secure: the cookie travels in calls from another site
      handler: (request) => ResponseEntity.noContent(
        cookies: [
          Cookie('session', 'abc')
            ..httpOnly = true
            ..secure = true
            ..sameSite = SameSite.none
            ..path = '/',
        ],
      ),
    ),
  ],
);

Future<void> main() async =>
    Winter.start(router: router(), securityConfig: securityConfig);
