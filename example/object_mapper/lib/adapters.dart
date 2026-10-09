/// Types you don't own, or written as text: a `JsonAdapter` registers both directions at once, and
/// their lists and maps come with it.
///
/// Run: `dart run lib/adapters.dart`
library;

import 'package:winter/winter.dart';

/// An amount of money, written as text: `"12.50 EUR"`
class Money {
  final int cents;
  final String currency;

  const Money(this.cents, this.currency);

  /// A FormatException for anything else: a 400 `invalid value` at its path
  factory Money.parse(String text) {
    final RegExpMatch? match = RegExp(
      r'^(\d+)\.(\d\d) ([A-Z][A-Z][A-Z])$',
    ).firstMatch(text);
    if (match == null) throw FormatException('Not an amount', text);
    return Money(int.parse(match[1]!) * 100 + int.parse(match[2]!), match[3]!);
  }

  @override
  String toString() =>
      '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')} $currency';
}

ObjectMapper objectMapper() => ObjectMapper(
  adapters: [
    JsonAdapter<Money>.string(
      toJson: (money) => '$money',
      fromJson: Money.parse,
    ),
    JsonAdapter<Uri>.string(toJson: (uri) => '$uri', fromJson: Uri.parse),
  ],
);

WinterRouter router() => WinterRouter(
  routes: [
    // List<Money> and Map<String, Uri> are derived from the adapters
    Route.post(
      path: '/total',
      handler: (request) async {
        final List<Money> amounts = await request.body<List<Money>>();
        final int cents = amounts.fold(0, (sum, money) => sum + money.cents);
        return ResponseEntity.ok(
          body: {'total': Money(cents, amounts.first.currency)},
        );
      },
    ),
    Route.post(
      path: '/links',
      handler: (request) async {
        final Map<String, Uri> links = await request.body<Map<String, Uri>>();
        return ResponseEntity.ok(
          body: {
            for (final MapEntry(:key, :value) in links.entries) key: value.host,
          },
        );
      },
    ),
  ],
);

Future<void> main() async {
  Winter.context.setUp(objectMapper: objectMapper());
  await Winter.start(router: router());
}
