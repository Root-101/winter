import '../../winter/winter.dart';

void main() => Winter.run(
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
              return ResponseEntity.ok(body: 'Response from any other source');
            },
          ),
        ],
      ),
    );
