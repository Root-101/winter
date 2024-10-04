## Docs for WinterRouter

`WinterRouter` is the default, expected to use router implementation, it's designed to a robust and complete router than
can handle all the possibles routes in a service.

Now, let's dive a little dipper.

### Understanding it

`WinterRouter` allow as to create the more complex routes, for example, *nested routes*, where we can create child
routes to make routing easier.

Let's take this example:

```dart

WinterRouter router = WinterRouter(
  routes: [
    Route(
      path: '/user',
      method: HttpMethod.get,
      handler: (request) => ResponseEntity.ok(body: 'Route: /user'),
      routes: [
        Route(
          path: '/123456',
          method: HttpMethod.get,
          handler: (request) => ResponseEntity.ok(body: 'Route: /user/123456'),
        ),
        Route(
          path: '/abcdef',
          method: HttpMethod.get,
          handler: (request) => ResponseEntity.ok(body: 'Route: /user/abcdef'),
        ),
      ],
    ),
    Route(
      path: '/tables',
      method: HttpMethod.get,
      handler: (request) => ResponseEntity.ok(body: 'Tables route'),
    ),
  ],
);
```

This concatenates the child routes with its parent, giving as result the following routes:

```
Routes:
GET:    /user
GET:    /user/123456
GET:    /user/abcdef
GET:    /tables
```

#### Including path-params in parent

This could be even extended with the user of path args in the parent, and the child will have access to it:

```dart

WinterRouter router = WinterRouter(
  routes: [
    Route(
      path: '/user/{user-id}',
      method: HttpMethod.get,
      handler: (request) => ResponseEntity.ok(body: 'User route'),
      routes: [
        Route(
          path: '/details',
          method: HttpMethod.get,
          handler: (request) =>
              ResponseEntity.ok(
                  body: 'Details of user ${request.pathParams['user-id']}'),
        ),
      ],
    ),
  ],
);
```

In this example the routes will be:

```
GET:    /user/{user-id}
GET:    /user/{user-id}/details
```

This means that if a request is made to `/user/123456/details` the response will be `200 : Details of user 123456`

#### Excluding parent

If by any chance we don't wanna that the 'parent' route is a route itself, we can use the `ParentRoute` for that.

This route only needs the `path`, and the other fields (method, handler) are ignores as this route is not included in
a 'processable' route

In this example:

```dart

WinterRouter router = WinterRouter(
  routes: [
    ParentRoute(
      path: '/user',
      routes: [
        Route(
          path: '/{user-id}/details',
          method: HttpMethod.get,
          handler: (request) =>
              ResponseEntity.ok(
                  body: 'Details of user ${request.pathParams['user-id']}'),
        ),
        Route(
          path: '/test',
          method: HttpMethod.get,
          handler: (request) =>
              ResponseEntity.ok(
                  body: 'Details of user ${request.pathParams['user-id']}'),
        ),
      ],
    ),
  ],
);
```

We will have this routes to handle requests:

```
Routes:
GET:    /user/{user-id}/details
GET:    /user/test
```

Note that the `GET:    /user` is no longer there.

#### Overwritten Routes

We have to be cautious on how we define the routes, because a route could override another and it will have unexpected
results, for example:

```dart

final router = WinterRouter(
  routes: [
    ParentRoute(
      path: '/user',
      routes: [
        Route(
          path: '/abcdef',
          method: HttpMethod.get,
          handler: (request) =>
              ResponseEntity.ok(body: 'Route /user/abcdef'),
        ),
        Route(
          path: '/{user-id}',
          method: HttpMethod.get,
          handler: (request) =>
              ResponseEntity.ok(
                  body: 'Details of user ${request.pathParams['user-id']}'),
        ),
      ],
    ),
  ],
);
```

In this example the routes will be:

```
Routes:
GET:    /user/abcdef
GET:    /user/{user-id}
```

This means that if a request is made to `/user/abcdef` the server will respond with: `200: Route /user/abcdef`, but any other
combination will call the second handler; for example, a request made to `/user/123456` the server will respond
with: `200: Details of user 123456`.

And this itself is not bad, but if the routes are configured backwards, like this:

```dart

final router = WinterRouter(
  routes: [
    ParentRoute(
      path: '/user',
      routes: [
        Route(
          path: '/{user-id}',
          method: HttpMethod.get,
          handler: (request) =>
              ResponseEntity.ok(
                  body: 'Details of user ${request.pathParams['user-id']}'),
        ),
        Route(
          path: '/abcdef',
          method: HttpMethod.get,
          handler: (request) =>
              ResponseEntity.ok(body: 'Route /user/abcdef'),
        ),
      ],
    ),
  ],
);
```

The router will **ALWAYS** find first the route: `/user/{user-id}`, this means that even if the route `/user/abcdef` is
well configured, its handler will never be called because always be called to one in the `/user/{user-id}`

### Router Config
