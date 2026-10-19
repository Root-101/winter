import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// `Link` (RFC 8288): `WebLink` and the links of a page
void main() {
  RequestEntity request(String url) => RequestEntity('GET', Uri.parse(url));

  List<String> pages(String url, {required int page, required int last}) => [
    for (final link in WebLink.pages(request(url), page: page, last: last))
      '$link',
  ];

  test('a link with its attributes, quoted and escaped', () {
    final link = WebLink(
      Uri.parse('https://api.example.com/docs?a=1'),
      rel: 'help',
      type: 'text/html',
      title: r'The "v2" guide \ API',
      hreflang: 'es',
      params: {'anchor': '#top'},
    );

    expect(
      '$link',
      r'<https://api.example.com/docs?a=1>; rel="help"; type="text/html"; '
          r'title="The \"v2\" guide \\ API"; hreflang="es"; anchor="#top"',
    );
  });

  test('an attribute that is not printable ASCII, or a bad name, is an ArgumentError', () {
    for (final make in [
      () => WebLink(Uri.parse('/x'), rel: 'next\r\nX-Evil: 1'),
      () => WebLink(Uri.parse('/x'), rel: 'next', title: 'año'),
      () => WebLink(Uri.parse('/x'), rel: 'next', params: {'a b': 'c'}),
    ]) {
      expect(make, throwsArgumentError);
    }
  });

  test('a page in the middle: every link, keeping the other params', () {
    expect(
      pages(
        'http://localhost/articles?page=2&size=5&tag=a&tag=b',
        page: 2,
        last: 5,
      ),
      [
        '</articles?page=1&size=5&tag=a&tag=b>; rel="first"',
        '</articles?page=1&size=5&tag=a&tag=b>; rel="prev"',
        '</articles?page=3&size=5&tag=a&tag=b>; rel="next"',
        '</articles?page=5&size=5&tag=a&tag=b>; rel="last"',
      ],
    );
  });

  test(
    'the first page has no prev, the last no next, an empty list one page',
    () {
      expect(pages('http://localhost/articles', page: 1, last: 3), [
        '</articles?page=1>; rel="first"',
        '</articles?page=2>; rel="next"',
        '</articles?page=3>; rel="last"',
      ]);
      expect(
        pages('http://localhost/articles?page=3', page: 3, last: 3).join(),
        isNot(contains('next')),
      );
      expect(pages('http://localhost/articles', page: 1, last: 0), [
        '</articles?page=1>; rel="first"',
        '</articles?page=1>; rel="last"',
      ]);
      // A page past the end goes back to the last one
      expect(
        pages('http://localhost/articles?page=9', page: 9, last: 3)[1],
        '</articles?page=3>; rel="prev"',
      );
    },
  );

  test('another name for the param, and the links in the header', () async {
    final client = WinterTestClient.build(
      router: WinterRouter(
        routes: [
          Route.get(
            path: '/items',
            handler: (request) => ResponseEntity.ok(
              headers: {
                HttpHeader.link: WebLink.pages(
                  request,
                  page: 1,
                  last: 2,
                  param: 'p',
                ),
              },
            ),
          ),
        ],
      ),
    );

    expect((await client.get('/items?p=1')).headersAll['link'], [
      '</items?p=1>; rel="first"',
      '</items?p=2>; rel="next"',
      '</items?p=2>; rel="last"',
    ]);
  });
}
