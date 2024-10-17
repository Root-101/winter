import '../../winter/winter.dart';

void main() => Winter.run(
      config: ServerConfig(port: 9090),
      globalFilterConfig: FilterConfig(
        [
          RemoveQueryParamsFilter(),
        ],
      ),
      router: HRouter(
        config: RouterConfig(
          onInvalidUrl: OnInvalidUrl.fail(),
        ),
        routes: [
          HRoute(
            path: '/test-1',
            method: HttpMethod.get,
            handler: (request) => ResponseEntity.ok(
              body: request.queryParams,
            ),
          ),
          ParentRoute(
            path: '/fc',
            filterConfig: FilterConfig(
              [
                RateLimiterFilter(
                  onRequest: (request) =>
                      request.headers['X-Request-ID'] ?? 'unknown',
                  rateLimiter: RateLimiter(
                    1,
                    const Duration(minutes: 1),
                  ),
                  log: (request, requestId) {
                    print('Rate limiter fail for request ${request.requestedUri}');
                  },
                ),
              ],
            ),
            routes: [
              HRoute(
                path: '/filter-chain-1',
                method: HttpMethod.get,
                handler: (request) => ResponseEntity.ok(
                  body: request.queryParams,
                ),
              ),
              HRoute(
                path: '/filter-chain-2',
                method: HttpMethod.get,
                handler: (request) => ResponseEntity.ok(
                  body: request.queryParams,
                ),
                filterConfig: FilterConfig(
                  [
                    LogsFilter(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

class RemoveQueryParamsFilter implements Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    request.queryParams.clear();
    return await chain.doFilter(request);
  }
}
