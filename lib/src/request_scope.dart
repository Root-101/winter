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

  final WinterLocale _locale;
  bool _localeRead = false;

  /// Without [securityContext], an empty one.
  /// Without [locale], the fallback of `Winter.context.localeConfig`.
  RequestScope({RequestSecurityContext? securityContext, WinterLocale? locale})
    : securityContext =
          securityContext ?? RequestSecurityContext<dynamic>.empty(),
      _locale = locale ?? Winter.context.localeConfig.fallback;

  /// The same as `request.locale`: chosen from the `Accept-Language` of the request.
  /// Reading it marks the response as dependent on the language ([localeRead]).
  WinterLocale get locale {
    _localeRead = true;
    return _locale;
  }

  /// True once some code read the language of the request (`requestLocale` or `request.locale`).
  /// Then the server adds `Vary: Accept-Language` to the response, so caches keep one copy per language.
  bool get localeRead => _localeRead;

  final List<FutureOr<void> Function()> _onComplete = [];

  /// Runs [callback] when the request ends: after its response is built, before it's sent.
  /// The callbacks run in reverse order of registration (the last one registered, first), like
  /// the scoped dependencies of `di.putScoped` that are disposed there.
  ///
  /// A response streamed after that point (a [Stream] body) must not need what they close.
  void onComplete(FutureOr<void> Function() callback) =>
      _onComplete.add(callback);

  /// Runs the [onComplete] callbacks (once: they are removed). A callback that fails is logged and
  /// the others still run. The server calls it for every request; call it yourself after
  /// [run] in a test that registers callbacks (or uses scoped dependencies).
  Future<void> complete() async {
    final callbacks = _onComplete.reversed.toList();
    _onComplete.clear();
    for (final callback in callbacks) {
      try {
        await callback();
      } catch (error, stackTrace) {
        logger.error(
          'A callback of the end of the request failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

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

extension RequestLocaleX on RequestEntity {
  static const String _localeKey = 'winter.context.locale';

  /// Locale of this request, chosen from its `Accept-Language` with `Winter.context.localeConfig`.
  /// Calculated the first time and cached in the request context.
  ///
  /// Like `requestLocale`, reading it inside a request adds `Vary: Accept-Language` to the response.
  WinterLocale get locale {
    RequestScope.current?._localeRead = true;

    final WinterLocale? cached = context[_localeKey] as WinterLocale?;
    if (cached != null) return cached;

    final WinterLocale resolved = Winter.context.localeConfig.resolve(
      headers[HttpHeader.acceptLanguage],
    );
    context[_localeKey] = resolved;
    return resolved;
  }
}
