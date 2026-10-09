/// Generated file. Do not edit.
///
/// Source: lib/src/i18n
/// To regenerate, run: `dart run slang`

// coverage:ignore-file
// ignore_for_file: type=lint, unused_import

import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'package:slang/slang.dart';
export 'package:slang/slang.dart';

import 'messages_es.g.dart' as l_es;
part 'messages_en.g.dart';

/// Supported locales.
///
/// Usage:
/// - LocaleSettings.setLocale(WinterMessagesLocale.en) // set locale
/// - Locale locale = WinterMessagesLocale.en.flutterLocale // get flutter locale from enum
/// - if (LocaleSettings.currentLocale == WinterMessagesLocale.en) // locale check
enum WinterMessagesLocale
    with BaseAppLocale<WinterMessagesLocale, WinterMessages> {
  en(languageCode: 'en'),
  es(languageCode: 'es');

  const WinterMessagesLocale({
    required this.languageCode,
    this.scriptCode, // ignore: unused_element, unused_element_parameter
    this.countryCode, // ignore: unused_element, unused_element_parameter
  });

  @override
  final String languageCode;
  @override
  final String? scriptCode;
  @override
  final String? countryCode;

  @override
  Future<WinterMessages> build({
    Map<String, Node>? overrides,
    PluralResolver? cardinalResolver,
    PluralResolver? ordinalResolver,
  }) async {
    return buildSync(
      overrides: overrides,
      cardinalResolver: cardinalResolver,
      ordinalResolver: ordinalResolver,
    );
  }

  @override
  WinterMessages buildSync({
    Map<String, Node>? overrides,
    PluralResolver? cardinalResolver,
    PluralResolver? ordinalResolver,
  }) {
    switch (this) {
      case WinterMessagesLocale.en:
        return WinterMessagesEn(
          overrides: overrides,
          cardinalResolver: cardinalResolver,
          ordinalResolver: ordinalResolver,
        );
      case WinterMessagesLocale.es:
        return l_es.WinterMessagesEs(
          overrides: overrides,
          cardinalResolver: cardinalResolver,
          ordinalResolver: ordinalResolver,
        );
    }
  }
}

/// Provides utility functions without any side effects.
class AppLocaleUtils
    extends BaseAppLocaleUtils<WinterMessagesLocale, WinterMessages> {
  AppLocaleUtils._()
    : super(
        baseLocale: WinterMessagesLocale.en,
        locales: WinterMessagesLocale.values,
      );

  static final instance = AppLocaleUtils._();

  // static aliases (checkout base methods for documentation)
  static WinterMessagesLocale parse(String rawLocale) =>
      instance.parse(rawLocale);
  static WinterMessagesLocale parseLocaleParts({
    required String languageCode,
    String? scriptCode,
    String? countryCode,
  }) => instance.parseLocaleParts(
    languageCode: languageCode,
    scriptCode: scriptCode,
    countryCode: countryCode,
  );
  static List<String> get supportedLocalesRaw => instance.supportedLocalesRaw;
}
