/// `Prefer` (RFC 7240): the client says what it would like, and the server may honor it.
///
/// - `Prefer: return=minimal`: the `POST` answers a 201 with its `Location` but without the body
///   (a mobile client that only needs the id saves the download), and says so with
///   `Preference-Applied: return=minimal`.
/// - Without it, or with `return=representation`: the 201 with the created note.
///
/// Reading `request.preferences` adds `Vary: Prefer` by itself, so a cache never mixes them.
///
/// Run: `dart run lib/prefer_return.dart`, then
/// `curl -i -X POST localhost:8080/notes -H 'Prefer: return=minimal' -H 'Content-Type: application/json' -d '{"text": "hi"}'`
library;

import 'package:winter/winter.dart';

class Note {
  final int id;
  final String text;

  const Note(this.id, this.text);

  Map<String, Object> toJson() => {'id': id, 'text': text};
}

WinterRouter router() {
  final List<Note> notes = [];
  return WinterRouter(
    routes: [
      Route.post(
        path: '/notes',
        handler: (request) async {
          final Map<String, dynamic> json = await request
              .body<Map<String, dynamic>>();
          final Note note = Note(notes.length + 1, json['text'] as String);
          notes.add(note);

          if (request.preferences.returns == 'minimal') {
            return ResponseEntity.created(
              location: '/notes/${note.id}',
              headers: {HttpHeader.preferenceApplied: 'return=minimal'},
            );
          }
          return ResponseEntity.created(
            location: '/notes/${note.id}',
            body: note,
          );
        },
      ),
    ],
  );
}

Future<void> main() async => Winter.start(router: router());
