# Benchmarks

What Winter costs on top of `dart:io`, measured with the programs of [`benchmark/`](../benchmark).
They measure the framework, not an app: an empty endpoint, so the overhead is as visible as it can
be. A real handler (a database, JSON of some KB) makes it a small share of each request.

## How they were run

- Machine: Intel Core i5-12450H (12 threads), 32 GB, Windows 11.
- Dart 3.13.1, every benchmark compiled to native code (`dart compile exe`), the way a server runs:
  `dart run` is JIT, slower and noisier.
- Absolute numbers change from one day to another on the same machine (load, power plan); compare
  the ratios, which hold. The numbers below are of 2026-10-22 (after the security and quality
  audits, roadmap 10), each one the range of several runs.

```bash
dart compile exe benchmark/http_benchmark.dart -o build/http_bench.exe
build/http_bench.exe
```

## HTTP: requests per second against `dart:io`

`benchmark/http_benchmark.dart`: an empty endpoint, the server in its own isolate, a client with
64 concurrent connections for 10 seconds (after 2 of warm-up).

| Server                                                        | Requests per second | Of `dart:io` |
|---------------------------------------------------------------|--------------------:|-------------:|
| `dart:io` alone (`HttpServer`), the ceiling                    |      16 000 - 17 200 |        100 % |
| Winter (`Winter.start`, whole pipeline, the defaults)          |      12 400 - 14 000 |     ~79 %    |
| Winter with `requestTimeout: Duration(seconds: 30)`            |      12 450 - 13 150 |     ~76 %    |

The same day, the code before the audits (`e8707db`) gave ~13 500 req/s (~80 %), alternating the
two executables six times. The audits left the pipeline as fast as before (the router and the ids
got faster, the new checks cost nothing measurable). Turning on `requestTimeout` costs a timer per
request, about **4 %** of an empty endpoint, nothing next to a real handler; that's why it is off
by default and each app turns it on.

The ratio is lower than in earlier measures (~85 %) because `dart:io` alone measured higher that
day; Winter's absolute numbers are the same or better.

The pipeline of every request: the route, the request scope (`Zone`) and its id, the filter chain,
the exception handler, the security headers, `X-Request-Id`, the check of the response headers
and writing the response.

**Before 1.0, Winter ran on shelf** (measured on the same machine at the start of phase 3.1, the
day's absolute numbers were lower): `dart:io` 6363 req/s, shelf alone 5561 (87 %), Winter on shelf
3984 (**63 %**). Moving to `dart:io` took Winter from 63 % to ~85 % of the ceiling.

## The pipeline in memory

No network: what Winter does for a request, measured in a loop.

| Benchmark                                                  | Requests per second |
|------------------------------------------------------------|--------------------:|
| `server_benchmark.dart`: the handler of `buildHandler`, 1 route |  ~620 000 - 640 000 |
| `router_benchmark.dart`: 31 routes, path params, JSON body |  ~415 000 - 445 000 |

Before the audits: ~490 000 - 530 000 and ~189 000. The router finds a static route by its path
in a map instead of trying the regex of every route (roadmap 10.10), and the ids of a request take
4 random bytes per call instead of one.

`server_benchmark.dart` also runs a real server with a client in the same process (sequential and
100 concurrent workers, ~6 000-7 000 req/s); the client shares the isolate, so it measures the
client as much as the server. Use `http_benchmark.dart` for the throughput.

## Object mapper

`benchmark/object_mapper_benchmark.dart`: a list of 1000 orders (a nested customer, a `DateTime`,
an enum and a list of lines; 291 KB of JSON), against the same work written by hand.

| Case                                              | Time    | Against by hand |
|---------------------------------------------------|---------|----------------:|
| encode: `jsonEncode(toJson())` by hand            | 3.55 ms |                 |
| encode: `om.encode`, `toJson()` found dynamically | 3.91 ms |           x1.10 |
| encode: `om.encode`, a `Serializer<Order>`        | 3.95 ms |           x1.11 |
| encode: a `Serializer` of a supertype, by hand    | 0.37 ms |                 |
| encode: `om.encode`, a `Serializer` of a supertype | 0.44 ms |          x1.20 |
| decode: `jsonDecode` + `fromJson` by hand         | 3.16 ms |                 |
| decode: `om.decode<List<Order>>`                  | 3.26 ms |           x1.03 |

The check that rejects a number too big for a `double` (`1e400`) at any depth costs nothing
measurable here: a typed body was already checked field by field, and an untyped one (a
`Map<String, dynamic>`) gets one more pass over its values.

A response and a request are bytes. Winter writes and reads them in UTF-8 directly (the same
1000 orders, two runs):

| Case                                     | Against the String in between |
|------------------------------------------|------------------------------:|
| `om.encodeBytes(orders)`, what a response does | x0.78 - x0.79            |
| `om.decodeBytes(bytes)`, what `body<T>()` does | x0.80 - x0.81            |

Indenting (`prettyPrint`, on by default) costs: writing these orders indented took about 5 times
as long as compact, in a separate measure. Turn it off in production for big responses.

The mapper converts what `toJson()` returns (dates, enums, nested objects) in the same pass as
`jsonEncode`, and caches the rule of each type, so it costs about a tenth more than writing the
JSON by hand.

## When a change touches the pipeline

Measure before and after with `http_benchmark.dart`, alternating the two executables a few times
(the noise between runs is a few percent). The check of the response headers, for example, was
first written with regular expressions (about 2 % slower) and then as a loop over the characters
(within the noise). `requestTimeout` was measured the same way: three alternated pairs show
little, six show its ~4 %.
