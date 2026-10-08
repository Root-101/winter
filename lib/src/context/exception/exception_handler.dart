import 'dart:async';

import 'package:winter/winter.dart';

/// Turns any error thrown while handling a request into a response.
///
/// The filter chain calls it where the error is thrown, so every outer filter (CORS, logs...) gets
/// a response. It receives [Exception]s and [Error]s alike: an [Error] is a bug, so it must become
/// a 500 that never shows its details.
///
/// {@category Errors}
abstract class ExceptionHandler {
  /// The response for [error], thrown while handling [request]
  Future<ResponseEntity> call(
    RequestEntity request,
    Object error,
    StackTrace stackTrace,
  );
}

/// Log an unexpected error (the ones that end in a 500) with its stack trace.
/// The details are only logged, never sent to the client.
///
/// {@category Errors}
void defaultLogUnhandledError(
  RequestEntity request,
  Object error,
  StackTrace stackTrace,
) {
  logger.error(
    'Unhandled error in ${request.method} ${request.requestedUri.path}',
    error: error,
    stackTrace: stackTrace,
  );
}

/// Generic 500, without any internal detail of the error. Inside a request it has the
/// `requestId`, so the client can report it and the logs of that request can be found.
///
/// {@category Errors}
ResponseEntity internalServerErrorResponse() => ProblemDetails.of(
  StatusCode.internalServerError,
  extensions: {'requestId': ?requestId},
).toResponse();

/// The default [ExceptionHandler]: every error is answered as a [ProblemDetails].
///
/// - An [ApiException] with its status, `detail` and headers; a [ValidationException] adds the
///   `violations`.
/// - A [DeserializationException] (a body that can't be read) is a 400 with its message.
/// - A [ResponseException] answers its own response.
/// - Anything else (including any [Error]) is logged with [logUnhandledError] and becomes a
///   generic 500.
///
/// Register the answer for an exception of the app with [on], or extend it and override [call]:
///
/// ```dart
/// SimpleExceptionHandler()
///   ..on<EmailTakenException>((request, e) => ConflictException(detail: e.message));
/// ```
///
/// {@category Errors}
class SimpleExceptionHandler extends ExceptionHandler {
  /// Logs the errors that end in a 500
  final void Function(
    RequestEntity request,
    Object error,
    StackTrace stackTrace,
  )
  logUnhandledError;

  final List<_Mapping<Object>> _mappings = [];

  /// A handler that logs the unexpected errors with [logUnhandledError]
  SimpleExceptionHandler({this.logUnhandledError = defaultLogUnhandledError});

  /// Answers the errors of type [T] (and its subtypes) with [handle], which returns an
  /// [ApiException] (sent as a [ProblemDetails]), a [ProblemDetails] or a [ResponseEntity].
  ///
  /// When several registered types match, the most specific one wins, whatever the order of
  /// registration; registering the same type again replaces it. If [handle] throws, what it
  /// throws is answered by the default rules.
  void on<T extends Object>(
    FutureOr<Object> Function(RequestEntity request, T error) handle,
  ) {
    _mappings
      ..removeWhere((mapping) => mapping.type == T)
      ..add(_Mapping<T>(handle));
  }

  @override
  Future<ResponseEntity> call(
    RequestEntity request,
    Object error,
    StackTrace stackTrace,
  ) async {
    final _Mapping<Object>? mapping = _mostSpecificFor(error);
    if (mapping == null) return handle(request, error, stackTrace);

    final Object result;
    try {
      result = await mapping.handle(request, error);
    } catch (thrown, thrownStackTrace) {
      // The default rules, never the mappings again (a mapping can't loop)
      return handle(request, thrown, thrownStackTrace);
    }
    return switch (result) {
      ResponseEntity() => result,
      ProblemDetails() => result.toResponse(),
      _ => handle(request, result, stackTrace),
    };
  }

  /// The default rules, without the mappings of [on]. Override it to change them and keep [on].
  Future<ResponseEntity> handle(
    RequestEntity request,
    Object error,
    StackTrace stackTrace,
  ) async {
    switch (error) {
      case ResponseException():
        return error.responseEntity;
      case DeserializationException():

        ///The client sent a body that can't be read: 400 with the reason (never Dart details)
        return ProblemDetails.of(
          StatusCode.badRequest,
          detail: error.message,
        ).toResponse();
      case ValidationException():

        ///The messages are already in the language of the request
        ///(reading it adds `Vary: Accept-Language`, see `RequestScope.localeRead`).
        ///`fieldName` follows the `fieldNaming` of the mapper, so it's the name the client sent
        return ProblemDetails.of(
          error.status,
          type: error.type,
          title: error.title,
          detail: error.detail,
          extensions: {
            ...error.extensions,
            'violations': [
              for (final violation in error.violations)
                violation.copyWith(
                  fieldName: om.jsonFieldName(violation.fieldName),
                ),
            ],
          },
        ).toResponse(headers: error.headers);
      case ApiException():
        return error.toProblemDetails().toResponse(headers: error.headers);
    }

    ///Anything else (a failed serialization of a response, any Error) is a server error:
    ///log it and don't expose its details
    logUnhandledError(request, error, stackTrace);
    return internalServerErrorResponse();
  }

  /// The registered mapping of the most specific type that matches [error]
  _Mapping<Object>? _mostSpecificFor(Object error) {
    _Mapping<Object>? found;
    for (final mapping in _mappings) {
      if (!mapping.accepts(error)) continue;
      if (found == null || mapping.isSubtypeOf(found)) found = mapping;
    }
    return found;
  }
}

class _Mapping<T extends Object> {
  final FutureOr<Object> Function(RequestEntity request, T error) _handle;

  _Mapping(this._handle);

  Type get type => T;

  bool accepts(Object error) => error is T;

  /// Whether [T] is a subtype of the type of [other]
  bool isSubtypeOf(_Mapping<Object> other) => other._isSupertypeOf<T>();

  bool _isSupertypeOf<S>() => <S>[] is List<T>;

  FutureOr<Object> handle(RequestEntity request, Object error) =>
      _handle(request, error as T);
}
