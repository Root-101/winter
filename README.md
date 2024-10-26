## Winter Framework: a backend for the Dart enthusiasts

This project is designed to create server side apps the simplest way possible, and reduce the learning
curve in backend development.

This project aims to be a lightweight backend framework to create BASICS services and APIs.
Maybe in a feature, a more mature framework with a greater ecosystem to build all kind of backends.

It's greatly inspired by others frameworks such as **Spring** or **Nest.js**.

This is an EXPERIMENTAL project, and it's by no means a ready production framework, use it at your own discretion.

**This project is:**

- An **experimental** framework.
- A lightweight library for create APIs.
- A *hobby* project in which we work when we have some spare time.

**This project is NOT:**

- A ready for production framework.
- A fullstack framework to create all kind of webs (just simple APIs, for the moment at least).
- A complete project (most of the features are extremely basics).

Now that we have made all this clear:

## Let's get started

### Configure the package

At this point we assume that you have the basic knowledge of dart, and a fully configured environment

If not, please take a look at the [official dart guide](https://dart.dev/get-dart)

Once you have a basic project running you need to:

1 - Add `winter` to dependencies:

```yaml
dependencies:
  winter: latest_version
```

2 - Run `dart pub get`.

3 - Go to your main file and import the package.

When this step are done, we can now learn:

### How to start the server:

To start the server we need to call the `Winter.run` method. (Remember to import the `package:winter/winter.dart`).

A pretty basic example will be like this:

```dart
void main() =>
    Winter.run(
      router: ServeRouter((request) => ResponseEntity.ok(body: 'Hello world!!!')),
    );
```

Just with that we have running the server in port 8080 (default port if none is specified).
We can now make a request to `http://localhost:8080` and we will receive a response with the *Hello world!!!*.

### ServeRouter

In this example we use the `ServeRouter`, this router expose a
function (`FutureOr<ResponseEntity> Function(RequestEntity request)`) that allow us to handle any incoming request to
the server.
In this case, any request made to the server, we will respond with an `ok` response with the body: *'Hello world!!!'*.

### Custom port

By default, the server will start in port `8080`, if another port needs to be used, we can use:
`config: ServerConfig(port: 1234)`,

this way the code will look like:

```dart
void main() =>
    Winter.run(
      config: ServerConfig(port: 1234),
      router: ServeRouter((request) => ResponseEntity.ok(body: 'Hello world!!!')),
    );
```

This way the server will start in port 1234.

Tests and example for *ServeRouter* and *Custom Port* could be found at `/test/server/serve`.

### Configuring routes

For a more fine-grained control over routes we can use other router provided by winter, like:

#### WinterRouter

For a more easy work on routing we could use some of the router the framework already provide, like:

```dart
void main() =>
    Winter.run(
      router: WinterRouter(
        routes: [
          Route(
            path: '/test',
            method: HttpMethod.get,
            handler: (request) async {
              return ResponseEntity.ok(body: 'Response from /test');
            },
          ),
          Route(
            path: '/custom',
            method: HttpMethod.post,
            handler: (request) async {
              return ResponseEntity.ok(body: 'Response from /custom');
            },
          ),
          Route(
            path: '/.*',
            method: HttpMethod.post,
            handler: (request) async {
              return ResponseEntity.ok(
                  body: 'Response from any other source');
            },
          )
        ],
      ),
    );
```

This way we provide a different handler for every route, now, by making a request to
`http://localhost:8080/test` we will receive a `200:'Response from /test'`, and by making a different request to
`http://localhost:8080/custom` we will receive a `200:'Response from /custom'`, finally if any other request is made (
of `post` type in this case),
it's handled by the `/.*` route, this means that if a request is made to another url,
like `http://localhost:8080/abcdefg`, we will receive `200:'Response from any other source'`.

Note that in the route we can configure the `path`, the http `method` and the `handler`.

The same way, we could create an instance of `WinterRouter` and add the routes with the `.get` (add a route with *get*
method), `.post` (add a route with *post* method), and so on.

Tests and example for *Routing* could be found at '/test/server/winter_router'.

#### There is more in routing:

Routing is a complex and deep subject, because of that, we have created a separated docs just for routing,
if you want to know all the details and more advanced routing, go to [route-docs](doc/routing/winter_router.md).

### Other topics

This is the more basic instruction to start the server, in the way that anyone could follow this guide in order to have an easy running server.

Of course, we also provide a wide range of functionalities like:

- Object Mapping
- [Validations](doc/vs/vs.md)
- Filter Chain
- Exception handler
- Dependency injection
- Annotation/Decoration pattern for config the server
- And some utils like rate-limiter, basic constants

Feel free to go to any of its respective docs to learn how to use it.

### What's next

In the future we intend to improve and make all current functionalities more robust, with more docs and more test,
as well as add others such as:

- Security
- Cron tasks
- Multipart request
- Web sockets
- Complete config of server via package-scan (completely optional and as an alternative to imperative config)

For more details on *What's next*, go to [todo](todo.md).

### Contribute

If you like the project, and want to contribute, you can create an issue or a pull request, and we will be pleased to
look at it.

### FAQ

##### 1 - How to change the port in which is running the server?:

If the app need to be running in a different port (different that *8080* as default), change config
as `config: ServerConfig(port: 1234)`. This will make the server run in port `1234`