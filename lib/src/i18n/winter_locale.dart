import 'package:winter/winter.dart';

/// A language (`es`) with an optional region (`es-MX`).
class WinterLocale {
  static const WinterLocale english = WinterLocale('en');
  static const WinterLocale spanish = WinterLocale('es');

  /// Lowercase ISO 639 code: `en`, `es`...
  final String languageCode;

  /// Uppercase ISO 3166 code: `US`, `MX`... or null
  final String? countryCode;

  const WinterLocale(this.languageCode, [this.countryCode]);

  /// Parse a language tag like `es`, `es-MX` or `es_mx`.
  /// A script subtag (`zh-Hant-TW`) is skipped. Returns null if the tag has no valid language.
  static WinterLocale? tryParse(String tag) {
    final List<String> parts = tag.trim().split(RegExp('[-_]'));
    final String language = parts.first.toLowerCase();
    if (!RegExp(r'^[a-z]{2,3}$').hasMatch(language)) return null;

    final String? country = parts
        .skip(1)
        .where((p) => RegExp(r'^([A-Za-z]{2}|\d{3})$').hasMatch(p))
        .firstOrNull;
    return WinterLocale(language, country?.toUpperCase());
  }

  /// `es` or `es-MX`
  String toLanguageTag() =>
      countryCode == null ? languageCode : '$languageCode-$countryCode';

  @override
  String toString() => toLanguageTag();

  @override
  bool operator ==(Object other) =>
      other is WinterLocale &&
      other.languageCode == languageCode &&
      other.countryCode == countryCode;

  @override
  int get hashCode => Object.hash(languageCode, countryCode);
}

/// Languages the app answers in. Configured in the [BuildContext] (`Winter.context.setUp(localeConfig: ...)`).
class LocaleConfig {
  /// Languages the app can answer in, by preference when the client accepts several with the same `q`.
  /// Default to English only: an app opts in to other languages, so its responses don't change by surprise.
  final List<WinterLocale> supported;

  /// Used without `Accept-Language` or when no accepted language is supported
  final WinterLocale fallback;

  LocaleConfig({
    this.supported = const [WinterLocale.english],
    this.fallback = WinterLocale.english,
  }) : assert(supported.isNotEmpty, 'At least one locale must be supported');

  /// Choose the locale for an `Accept-Language` header (RFC 9110 §12.5.4):
  /// - The languages are tried from the highest `q` to the lowest (`q=0` means "not acceptable").
  /// - `es-MX` matches `es-MX`, and if it isn't supported, falls back to `es` (or any other `es-*`).
  /// - Without header, or when nothing matches: [fallback].
  WinterLocale resolve(String? acceptLanguage) {
    if (acceptLanguage == null || acceptLanguage.trim().isEmpty) {
      return fallback;
    }

    for (final WinterLocale wanted in _parseAcceptLanguage(acceptLanguage)) {
      final WinterLocale? match =
          supported.where((l) => l == wanted).firstOrNull ??
          supported
              .where(
                (l) =>
                    l.languageCode == wanted.languageCode &&
                    l.countryCode == null,
              )
              .firstOrNull ??
          supported
              .where((l) => l.languageCode == wanted.languageCode)
              .firstOrNull;
      if (match != null) return match;
    }
    return fallback;
  }

  /// The accepted locales sorted by `q` (descending, stable). The `*` and invalid entries are skipped.
  static List<WinterLocale> _parseAcceptLanguage(String header) {
    final List<(WinterLocale, double)> entries = [];
    for (final String item in header.split(',')) {
      final List<String> parts = item.split(';');
      final String tag = parts.first.trim();
      if (tag.isEmpty || tag == '*') continue;

      double q = 1;
      for (final String param in parts.skip(1)) {
        final List<String> kv = param.split('=');
        if (kv.length == 2 && kv[0].trim().toLowerCase() == 'q') {
          q = double.tryParse(kv[1].trim()) ?? 0;
        }
      }
      if (q <= 0) continue;

      final WinterLocale? locale = WinterLocale.tryParse(tag);
      if (locale != null) entries.add((locale, q));
    }

    ///List.sort isn't stable, so sort the indexes to keep the order of the header on ties
    final List<int> indexes = List.generate(entries.length, (i) => i)
      ..sort((a, b) {
        final int byQ = entries[b].$2.compareTo(entries[a].$2);
        return byQ != 0 ? byQ : a.compareTo(b);
      });
    return [for (final i in indexes) entries[i].$1];
  }
}
