## Winter Framework

This project aims to be a lightweight web server to create BASICS services and APIs
This is an EXPERIMENTAL project, and it's by no means a ready production framework, use it at your own discretion

**This project is:**

- An **experimental** framework
- A lightweight library for create rest APIs
- A *hobby* project in which we work when we have some spare time

**This project is NOT:**

- A ready for production framework
- A fullstack framework to create all kind of webs (just simple rest apis, for the moment at least)
- A complete project (most of the features are extremely basics)

Now that we have made all this clear, **let's start**

Now,

## Let's get started

### How to start the server:

To start the server we need to call the `.start()` on an instance of `WinterServer`.

A pretty basic example will be like this:

```dart
void main() =>
    WinterServer(
      config: ServerConfig(port: 8080),
      router: WinterRouter(
        routes: [
          Route(
            path: '/test',
            method: HttpMethod.get,
            handler: (request) =>
                ResponseEntity.ok(
                  body: 'hello-world',
                ),
          ),
        ],
      ),
    ).start();
```

In this example we have a couple of basic concepts:

**1 - config**: `config: ServerConfig(port: 8080)`.  
This class is in charge of provide the configuration for the server, like the port and ip address.

#### Custom port

If the app need to be running in a different port (different that 8080 as default), change config:

`config: ServerConfig(port: 1234)`

To run the server in port `1234`

**2 - router**: To be able of making request we need to provide the server with a router.
This router will be in charge of redirect every call of the service to its respective handler.

Winter provide a couple of pre-implemented routers, in this case we are using the default one: `WinterRouter`.

With this router we define a handler on path `/test` of type `get`, so, every time a `get` request is executed
on `/test` this will be the handler that is going to process it.

**3 - router.handler**: The handler is the function who will process the request.

This function receives a request, which is assumed to be processed, and returns a response

In this example the handler on `/test` return a response with status code `200` and body `hello-world`
##### A more
### FAQ

##### 1 - How to change the port in which is running the server?:

If the app need to be running in a different port (different that *8080* as default), change config
as `config: ServerConfig(port: 1234)`. This will make the server run in port `1234`