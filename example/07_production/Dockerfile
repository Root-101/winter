# Build a native executable: a small image without the Dart SDK, that starts in milliseconds
FROM dart:stable AS build
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get
COPY . .
RUN dart compile exe lib/main.dart -o /app/server

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/server /app/server
COPY --from=build /app/.env.prod /app/.env.prod
WORKDIR /app
ENV WINTER_PROFILE=prod
EXPOSE 8080
# SIGTERM (docker stop, Kubernetes) shuts the server down gracefully
CMD ["/app/server"]
