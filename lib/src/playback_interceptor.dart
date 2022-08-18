import 'dart:async';

import 'package:http/io_client.dart';
import 'package:test/test.dart';

import '../betamax.dart';
import 'http/http_intercepted_types.dart';
import 'http/http_interceptor.dart';
import 'interactions.dart';
import 'interceptor.dart';

class PlaybackInterceptor extends BetamaxInterceptor {
  /// The cassette being played back
  late Cassette cassette;

  @override
  void insertCassette(String cassetteFilePath) {
    super.insertCassette(cassetteFilePath);

    cassette = Betamax.cassetteFs.read(cassetteFilePath);
  }

  @override
  FutureOr<Cassette> ejectCassette() => cassette;

  @override
  Future<OverrideResponse> interceptRequest(
      InterceptedBaseRequest request, String correlator) async {
    final interaction =
        cassette.interactionsByRequestUrl[request.url.toString()];

    if (interaction == null) {
      fail('Unexpected request (${request.method} ${request.url})');
    }

    final storedReq = interaction.request!;
    if (request.method.toLowerCase() != storedReq.method) {
      fail('Wrong method. Expected ${storedReq.method} but got ${request.url}');
    }

    // The stream being drained is important, as it can have side effects
    // (like upload progress)
    await request.finalize().drain();

    final storedRes = interaction.response!;
    return OverrideResponse(
      IOStreamedResponse(
        Stream.fromIterable([storedRes.body!.string!.codeUnits]),
        storedRes.status!,
        headers: storedRes.headers!,
        request: request,
      ),
    );
  }

  @override
  void interceptStreamedResponse(
      InterceptedIOStreamedResponse response, String correlator) {}
}

class BetamaxPlaybackException implements Exception {
  BetamaxPlaybackException(this.message);

  final String message;

  @override
  String toString() => 'BetamaxPlaybackException: $message';
}
