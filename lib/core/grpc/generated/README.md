# gRPC generated files

Generated from `proto/auth.proto` and `proto/media.proto`. Regenerate with
`protoc` (available in the devcontainer):

```bash
protoc --dart_out=grpc:lib/core/grpc/generated \
  -I proto \
  proto/auth.proto \
  proto/media.proto
```

Files actually used by the app:

- `auth.pb.dart`, `auth.pbgrpc.dart`
- `media.pb.dart`, `media.pbgrpc.dart`

The current `protoc-gen-dart` inlines the message/enum descriptors, so no
separate `*.pbjson.dart` / `*.pbenum.dart` files are needed. If your
generator version still emits them, they are unused — safe to delete after a
regen.
