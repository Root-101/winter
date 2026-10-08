# Request Bodies Example

One endpoint for each kind of body a client can send: the tabs of the **Body** of Postman (none,
form-data, x-www-form-urlencoded, raw, binary, GraphQL). Each one reads its body with the method
that fits and answers what it got.

## Key Concepts

| Postman tab              | `Content-Type`                        | Read with                          | Endpoint                 |
|--------------------------|---------------------------------------|------------------------------------|--------------------------|
| none                     | —                                     | `body<T?>()` (null), `body<String>()` (`''`) | `POST /bodies/none` |
| raw > JSON               | `application/json`                    | `body<Note>()`: typed and validated | `POST /bodies/json`     |
| raw > Text, XML, HTML, JavaScript | `text/plain`, `application/xml`, `text/html`, `application/javascript` | `body<String>()` | `POST /bodies/raw` |
| x-www-form-urlencoded    | `application/x-www-form-urlencoded`   | `formData()`                       | `POST /bodies/urlencoded` |
| form-data                | `multipart/form-data; boundary=...`   | `formData()` (`fields`, `files`)   | `POST /bodies/form-data` |
| binary                   | any (`image/png`, `application/octet-stream`...) | `bytes()` (or `body<Uint8List>()`) | `POST /bodies/binary` |
| GraphQL                  | `application/json`                    | `body<GraphQLRequest>()`           | `POST /bodies/graphql`   |

*   `body<T>()`, `bytes()` and `formData()` read the body once and cache it: they can be called
    many times. `read()` is the stream as it arrives, for a big upload (`multipart()` for big
    files, see `example/06_files`).
*   A wrong body is always a client error: a JSON with a wrong field is a 400 that names it
    (`$.title: expected a string, got an integer`), an invalid one a 422, a `Content-Type` that
    `body<Note>()` can't read a 415, and bytes that are not text read with `body<String>()` a 400.
*   `ServerConfig(maxBodySize: 5 MB)`: a bigger body is a 413, whatever its kind.

## How to Run

1. Installation: `dart pub get`.
2. Execution: `dart run lib/main.dart` (port 8080).
3. Tests: `dart test` (one per kind of body, in memory).

```bash
# none
curl -X POST localhost:8080/bodies/none

# raw > JSON
curl -X POST localhost:8080/bodies/json -H 'Content-Type: application/json' \
  -d '{"title": "Groceries", "tags": ["home"]}'

# raw > XML (or text/plain, text/html, application/javascript)
curl -X POST localhost:8080/bodies/raw -H 'Content-Type: application/xml' \
  -d '<note><title>Hi</title></note>'

# x-www-form-urlencoded
curl -X POST localhost:8080/bodies/urlencoded --data-urlencode 'name=Ann Lee' -d 'age=30&tag=a&tag=b'

# form-data
curl -X POST localhost:8080/bodies/form-data -F title=Holiday -F photos=@beach.png

# binary
curl -X POST localhost:8080/bodies/binary -H 'Content-Type: image/png' --data-binary @beach.png

# GraphQL
curl -X POST localhost:8080/bodies/graphql -H 'Content-Type: application/json' \
  -d '{"query": "query Me($id: ID!) { user(id: $id) { name } }", "variables": {"id": "7"}}'
```
