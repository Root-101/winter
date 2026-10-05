import 'dart:async';

import 'package:winter/winter.dart';

/// State of the request in progress, reachable from any code that runs for it
/// (services, repositories, serializers...) without receiving the [RequestEntity].
///
/// The server runs every request inside its own [Zone] with its own scope.
/// Everything async started there (`await`, [Future], [Timer], [Stream]) stays in that zone,
/// so concurrent requests never see the scope of another one. It's the `ThreadLocal` of Java
/// (`SecurityContextHolder` in Spring), or the `AsyncLocalStorage` of Node.
///
/// Outside a request (at start-up, in a global [Timer], in another isolate) there's no scope.
class RequestScope {
  static final Object _zoneKey = Object();

  /// Shared with `request.securityContext`: the same object for the request and its changes
  final RequestSecurityContext securityContext;

  /// The same as `request.locale`: chosen from the `Accept-Language` of the request
  final WinterLocale locale;

  /// Without [locale], the fallback of `Winter.context.localeConfig`
  RequestScope({required this.securityContext, WinterLocale? locale})
    : locale = locale ?? Winter.context.localeConfig.fallback;

  /// The scope of the request in progress, or null outside a request
  static RequestScope? get current => Zone.current[_zoneKey] as RequestScope?;

  /// Run [body] (and everything async it starts) with [scope] as [current].
  ///
  /// The server calls it for every request. Use it to call code that reads the scope
  /// outside the server, for example to test a service.
  static R run<R>(RequestScope scope, R Function() body) =>
      runZoned(body, zoneValues: {_zoneKey: scope});
}

/// Security context of the request in progress, or null outside a request.
/// The same object as `request.securityContext`.
RequestSecurityContext? get requestSecurityContext =>
    RequestScope.current?.securityContext;

/// Locale of the request in progress (the same as `request.locale`),
/// or the fallback of `Winter.context.localeConfig` outside a request.
WinterLocale get requestLocale =>
    RequestScope.current?.locale ?? Winter.context.localeConfig.fallback;

/// User of the request in progress, set by a filter with `request.securityContext.setAuthentication`.
/// Null outside a request or when nobody set it.
///
/// Work started by a request (even an `unawaited` one that ends after the response)
/// keeps seeing this user.
Authentication? get requestAuthentication =>
    requestSecurityContext?.authentication;
