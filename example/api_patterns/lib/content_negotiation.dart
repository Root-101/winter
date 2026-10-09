/// Content negotiation: the same resource as JSON or as CSV, chosen by the `Accept` header of the
/// client (with its `q` weights). A type the server can't produce is a 406, and every response
/// has `Vary: Accept`, so a cache keeps one copy per format.
///
/// Run: `dart run lib/content_negotiation.dart`, then
/// `curl localhost:8080/sales` and `curl -H 'Accept: text/csv' localhost:8080/sales`
library;

import 'package:winter/winter.dart';

const List<Map<String, Object>> sales = [
  {'month': '2026-01', 'total': 1200},
  {'month': '2026-02', 'total': 950},
];

/// The formats this route can produce, in order of preference
const List<String> produced = ['application/json', 'text/csv'];

/// The produced type the client prefers, or null if it accepts none of them
String? negotiate(String? accept) {
  if (accept == null || accept.trim().isEmpty) return produced.first;

  final List<String> parts = accept.split(',');
  // The highest q first; with the same q, in the order the client sent them
  final List<(String, double, int)> ranges = [
    for (int i = 0; i < parts.length; i++) (_type(parts[i]), _q(parts[i]), i),
  ]..sort((a, b) => a.$2 == b.$2 ? a.$3 - b.$3 : b.$2.compareTo(a.$2));

  for (final (String range, double q, _) in ranges) {
    if (q == 0) continue; // q=0: "not this one"
    for (final String type in produced) {
      if (range == '*/*' ||
          range == type ||
          range == '${type.split('/').first}/*') {
        return type;
      }
    }
  }
  return null;
}

/// `text/csv;q=0.5` → `text/csv`
String _type(String range) => range.split(';').first.trim().toLowerCase();

/// `text/csv;q=0.5` → 0.5 (1 without a q)
double _q(String range) {
  for (final String parameter in range.split(';').skip(1)) {
    final List<String> pair = parameter.trim().split('=');
    if (pair.first == 'q') return double.tryParse(pair.last) ?? 0;
  }
  return 1;
}

WinterRouter router() => WinterRouter(
  routes: [
    Route.get(
      path: '/sales',
      handler: (request) {
        final Map<String, String> vary = {HttpHeader.vary: HttpHeader.accept};
        switch (negotiate(request.headers[HttpHeader.accept])) {
          case 'text/csv':
            final String csv = [
              'month,total',
              for (final row in sales) '${row['month']},${row['total']}',
            ].join('\r\n');
            return ResponseEntity.ok(
              body: csv,
              headers: {
                ...vary,
                HttpHeader.contentType: 'text/csv; charset=utf-8',
              },
            );
          case 'application/json':
            return ResponseEntity.ok(body: sales, headers: vary);
          default:
            throw ApiException(
              StatusCode.notAcceptable,
              detail: 'This resource is available as ${produced.join(' or ')}',
              headers: vary,
            );
        }
      },
    ),
  ],
);

Future<void> main() async => Winter.start(router: router());
