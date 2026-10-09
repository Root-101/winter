# Winter and other frameworks

Winter didn't invent its ideas: an explicit pipeline of filters, dependency injection, JSON
mapping, validation and one format for every error are what most backend frameworks offer. This
page says where each idea comes from, which frameworks are the closest, and what Winter does
differently. It helps to pick the right tool, and to find your way in Winter if you come from one
of them.

## Where each idea comes from

| In Winter | Comes from |
|-----------|------------|
| `Filter` and `FilterChain` (`doFilter(request, chain)`) | The `Filter` of Java Servlets, made popular by the filter chain of Spring Security |
| `ResponseEntity` | Spring MVC |
| `SimpleExceptionHandler.on<T>()` | `@ControllerAdvice` / `@ExceptionHandler` of Spring |
| Problem Details for every error | RFC 9457, built into Spring 6 and ASP.NET Core |
| `Validatable`, `ConstraintViolation`, the 422 | Bean Validation (Java) |
| `putScoped` and the `RequestScope` (a `Zone`) | The request scope of Spring and the scoped services of .NET; the `Zone` plays the role of `AsyncLocalStorage` (Node) or `AsyncLocal` (.NET) |
| The OpenAPI document from the routes | springdoc (Spring) and FastAPI |
| `AuthFilter` with `hasRole(...)` and `&` / `\|` | The authorization expressions of Spring Security (`hasRole('ADMIN') and ...`) |
| `Route.health` | Spring Boot Actuator and the health checks of ASP.NET Core |

## The closest frameworks

Frameworks that share the idea **and** declare everything in code, without annotations:

| Framework | Language | What it shares with Winter |
|-----------|----------|----------------------------|
| ASP.NET Core Minimal APIs | C# | Routes in code, a middleware pipeline, built-in DI with singleton, transient and scoped lifetimes, endpoint filters, Problem Details |
| Spring WebFlux functional endpoints | Java | `RouterFunction` and `HandlerFilterFunction`: Spring without annotations |
| Ktor | Kotlin | A routing DSL, plugins for authentication, CORS and serialization |
| Javalin, Helidon SE | Java | Explicit routes, before/after handlers, what you register is what runs |

## The same idea, with more magic

| Framework | Language | Similar | Different |
|-----------|----------|---------|-----------|
| Spring Boot (MVC) | Java | The whole vocabulary: filter chain, `ResponseEntity`, exception handlers, validation, security rules | Annotations, classpath scanning and reflection decide what runs |
| NestJS | TypeScript | Guards (`AuthFilter`), interceptors (filters), validation pipes, exception filters (`on<T>()`), DI | Decorators and metadata |
| FastAPI | Python | A validated body, OpenAPI from the routes, DI with `Depends` | Types read at runtime (Pydantic) |
| Micronaut, Quarkus | Java | The model of Spring | Resolved at compile time, with annotations |

Middleware chains alone, without DI, validation or a format for errors out of the box, are in
Express, Koa and Fastify (Node), Gin, Echo and Chi (Go) and Axum (Rust, with the layers of
`tower`).

## In Dart

| Package | Approach |
|---------|----------|
| [shelf](https://pub.dev/packages/shelf) | A `Pipeline` of `Middleware` around a `Handler`; Winter ran on it until its phase 3.1 (see [`DECISIONS.md` §10](../DECISIONS.md#10-the-http-layer)) |
| [dart_frog](https://pub.dev/packages/dart_frog) | Routes from the files of a folder, middleware, DI with providers; minimal, the rest is left to the app |
| [Serverpod](https://pub.dev/packages/serverpod) | Full stack with code generation, an ORM and a generated client |
| Conduit (Aqueduct), Angel | Earlier frameworks in the style of Spring or Rails, no longer maintained |

## What Winter does its own way

- **No annotations, no code generation, no reflection.** Dart compiled to native code has no
  runtime reflection, and Winter doesn't generate code (only the translations, with slang): routes,
  filters and dependencies are registered in code, and what you register is what runs
  ([`DECISIONS.md` §11](../DECISIONS.md#11-the-public-api)).
- **Errors are responses where they're thrown.** Every filter around the error (CORS, logs) gets
  a response, never an exception ([error handling](error-handling.md)).
- **A service locator, not a container.** `di` finds by exact type, without autowiring
  ([dependency injection](dependency-injection.md)).
- **One process.** The rate limiter and the scheduled tasks live in the process, like the
  in-memory defaults of the frameworks above; a shared store is yours to add.

In short, Winter takes the vocabulary of Spring (filter chain, `ResponseEntity`, exception
handlers) and the way of ASP.NET Core Minimal APIs and Ktor (everything declared in code).

*The other frameworks are described as of 2026: check their own documentation for the details.*
