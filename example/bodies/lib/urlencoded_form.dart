/// x-www-form-urlencoded: an HTML form without files. `formData()` gives the fields, the repeated
/// ones (`fieldsAll`) and typed ones (`field<T>`).
///
/// Run: `dart run lib/urlencoded_form.dart`, then
/// `curl localhost:8080/subscribe -d 'email=ann@example.com&age=30&topic=dart&topic=web'`
library;

import 'package:winter/winter.dart';

WinterRouter router() => WinterRouter(
  routes: [
    Route.post(
      path: '/subscribe',
      handler: (request) async {
        final FormData form = await request.formData();
        final String? email = form['email'];
        if (email == null) {
          throw const BadRequestException(detail: 'The email is missing');
        }
        return ResponseEntity.ok(
          body: {
            'email': email,
            // A 400 naming the field if it isn't an integer
            'age': form.field<int>('age'),
            // Several checkboxes with the same name
            'topics': form.fieldsAll['topic'] ?? const <String>[],
          },
        );
      },
    ),
  ],
);

Future<void> main() async => Winter.start(router: router());
