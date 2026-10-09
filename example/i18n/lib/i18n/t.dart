import 'package:winter/winter.dart';

import 'messages.g.dart';

export 'messages.g.dart' show AppMessages;

/// One instance per language, built once
final Map<AppLocale, AppMessages> _cache = {
  for (final l in AppLocale.values) l: l.buildSync(),
};

/// Messages of the app in the language of the request in progress.
///
/// A getter, never a `final`: it is evaluated on every use, with the locale of that moment.
/// A region uses its language (`es-MX` → `es`) and an unknown language the base one (`en`).
AppMessages get t =>
    _cache[AppLocaleUtils.parseLocaleParts(
      languageCode: requestLocale.languageCode,
      countryCode: requestLocale.countryCode,
    )]!;
