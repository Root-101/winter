# Request body examples

Every kind of body a client sends (the tabs of the **Body** of Postman), one file per case. Each
is a server of its own: `dart run lib/<case>.dart` (port 8080). The tests run each one in memory:
`dart test`.

| Body (Postman) | File | What it shows | Try it |
|----------------|------|---------------|--------|
| none | [`no_body.dart`](lib/no_body.dart) | `body<T?>()` is `null` without a body | `curl -X POST localhost:8080/ping` |
| raw > JSON | [`json_body.dart`](lib/json_body.dart) | `body<Note>()` typed and validated (400/422), `body<Map>()` | `curl localhost:8080/notes -H 'Content-Type: application/json' -d '{"title": "Groceries"}'` |
| raw > Text, XML, HTML, CSV | [`raw_text.dart`](lib/raw_text.dart) | `body<String>()` with any `Content-Type`, a CSV parsed by hand | `curl localhost:8080/csv -H 'Content-Type: text/csv' --data-binary $'name,age\nAnn,30'` |
| x-www-form-urlencoded | [`urlencoded_form.dart`](lib/urlencoded_form.dart) | `formData()`: `form['email']`, `field<int>`, `fieldsAll` | `curl localhost:8080/subscribe -d 'email=ann@example.com&age=30&topic=dart&topic=web'` |
| form-data | [`multipart_form.dart`](lib/multipart_form.dart) | `formData()` with files: `filesAll`, `UploadedFile` | `curl localhost:8080/albums -F title=Holiday -F photos=@a.png` |
| form-data, big files | [`streaming_upload.dart`](lib/streaming_upload.dart) | `multipart()`: each file to disk as it arrives, `maxBodySize` | `curl localhost:8080/uploads -F file=@video.mp4` |
| binary | [`binary.dart`](lib/binary.dart) | `bytes()` with any `Content-Type`, checking the content | `curl -X PUT localhost:8080/avatar -H 'Content-Type: image/png' --data-binary @me.png` |
| GraphQL | [`graphql.dart`](lib/graphql.dart) | The query and its variables as JSON | `curl localhost:8080/graphql -H 'Content-Type: application/json' -d '{"query": "{ me { name } }"}'` |

Guide: [requests and responses](../../doc/requests-and-responses.md#the-body-of-a-request).
