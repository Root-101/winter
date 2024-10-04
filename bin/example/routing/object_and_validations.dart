import '../../winter/winter.dart';

void main() => WinterServer(
      config: ServerConfig(port: 9090),
      router: WinterRouter(
        config: RouterConfig(
          onInvalidUrl: OnInvalidUrl.fail(),
        ),
        routes: [
          Route(
            path: '/test',
            method: HttpMethod.get,
            handler: (request) => ResponseEntity.ok(
              body: 'hello-world',
            ),
          ),
          Route(
            path: '/object',
            method: HttpMethod.post,
            handler: (request) async {
              HiWorldRequest? body = await request.body<HiWorldRequest>();

              body?.validate(throwExceptionOnFail: true);

              return ResponseEntity.ok(
                body: HiWorldResponse(body!.hi),
              );
            },
          ),
        ],
      ),
    ).start();

class HiWorldRequest {
  @NotEmpty()
  @NotBlank()
  String? hi;

  HiWorldRequest();

  @override
  String toString() {
    return 'HiWorldRequest{hi: $hi}';
  }
}

class HiWorldResponse {
  String? hi;

  HiWorldResponse(this.hi);

  @override
  String toString() {
    return 'HiWorldResponse{hi: $hi}';
  }
}
