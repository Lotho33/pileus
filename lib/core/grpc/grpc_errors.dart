import 'package:grpc/grpc.dart';

bool isUnauthenticated(Object e) =>
    e is GrpcError && e.code == StatusCode.unauthenticated;
