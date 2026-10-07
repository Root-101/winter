@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:winter/winter.dart';

const WinterLocale english = WinterLocale.english;
const WinterLocale spanish = WinterLocale.spanish;
const WinterLocale french = WinterLocale('fr');

class _MemoryLogger extends WinterLogger {
  final List<String> warnings = [];

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level == LogLevel.warning) warnings.add(message);
  }
}

void main() {
  group('localesWithoutWinterMessages', () {
    test('English and Spanish are translated', () {
      expect(
        localesWithoutWinterMessages(
          LocaleConfig(supported: [english, spanish]),
        ),
        isEmpty,
      );
    });

    test('A region counts as its language', () {
      expect(
        localesWithoutWinterMessages(
          LocaleConfig(supported: [const WinterLocale('es', 'MX')]),
        ),
        isEmpty,
      );
    });

    test('The languages without messages, once each and in order', () {
      expect(
        localesWithoutWinterMessages(
          LocaleConfig(
            supported: [
              french,
              english,
              const WinterLocale('de', 'AT'),
              const WinterLocale('fr', 'CA'),
            ],
          ),
        ),
        [french, const WinterLocale('de', 'AT')],
      );
    });

    test('The fallback is checked too', () {
      expect(
        localesWithoutWinterMessages(
          LocaleConfig(supported: [english], fallback: french),
        ),
        [french],
      );
    });
  });

  group('Warning on start', () {
    const int port = 9087;
    late WinterLogger previousLogger;
    late LocaleConfig previousLocaleConfig;
    late _MemoryLogger memoryLogger;

    setUp(() {
      previousLogger = Winter.context.logger;
      previousLocaleConfig = Winter.context.localeConfig;
      memoryLogger = _MemoryLogger();
    });

    tearDown(() async {
      await Winter.close(force: true);
      Winter.context.setUp(
        logger: previousLogger,
        localeConfig: previousLocaleConfig,
      );
    });

    Future<void> start(LocaleConfig localeConfig) async {
      Winter.context.setUp(logger: memoryLogger, localeConfig: localeConfig);
      await Winter.start(
        config: const ServerConfig(port: port, handleSignals: false),
      );
    }

    test('A supported language without messages of Winter', () async {
      await start(LocaleConfig(supported: [english, spanish, french]));

      expect(memoryLogger.warnings, hasLength(1));
      expect(
        memoryLogger.warnings.single,
        startsWith(
          'Winter has no validation messages for fr: they will be in English',
        ),
      );
    });

    test('Nothing when Winter translates every language', () async {
      await start(LocaleConfig(supported: [english, spanish]));
      expect(memoryLogger.warnings, isEmpty);
    });
  });
}
