import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:slugify_string/slugify_string.dart';
import 'package:stack_trace/stack_trace.dart';
// We need Invoker access for automatic naming of cassettes
// ignore: implementation_imports
import 'package:test_api/src/backend/invoker.dart';
// ignore: implementation_imports
import 'package:test_api/src/backend/live_test.dart';

import 'src/cassette_fs.dart';
import 'src/collection_util.dart';
import 'src/http/http_intercepting_client.dart';
import 'src/interceptor.dart';
import 'src/playback_interceptor.dart';
import 'src/recording_interceptor.dart';

export 'src/cassette_fs.dart' show CassetteFs;

/// Use with [Betamax.configureSuite] to set betamax to either playback
/// previously generated HTTP fixtures, or to record them.
enum Mode {
  recording,
  playback,
}

/// Responsible for configuring the recording/playback system, and vends out
/// HTTP clients tied to a specific test's lifecycle.
class Betamax {
  static String? suiteName;
  static Mode? mode;
  static String? cassettePath;
  static bool get isConfigured => mode != null && cassettePath != null;

  /// Responsible for reading and writing [Cassette]s (HTTP fixtures).
  @internal
  static CassetteFs cassetteFs = JsonIoCassetteFs();

  static HttpInterceptingClient? _activeClient;

  /// Configures Betamax for a test suite (generally a file).
  ///
  /// [relativeCassettePath] is a `/test` relative path where cassettes (HTTP
  /// fixtures) are stored.
  static void configureSuite({
    required String suiteName,
    required Mode mode,
    String relativeCassettePath = 'http_fixtures',
  }) {
    Betamax.suiteName = suiteName;
    Betamax.mode = mode;
    Betamax.cassettePath =
        absolute(join(_getTestDirectory(), relativeCassettePath));
  }

  /// Creates a new HTTP client, configured for playback or recording.
  ///
  /// Must be called in a test (either test body or `setUp()`).
  ///
  /// The returned client is configured according to [configureSuite]. It will be
  /// freed automatically when the test completes.
  static http.Client clientForTest({bool setCassetteFromTestName = true}) {
    assert(Betamax.isConfigured);
    assert(_activeClient == null);

    final liveTest = Invoker.current?.liveTest;
    assert(liveTest != null,
        'clientForTest() must be called from a running test (body, or setUp)');

    final interceptor = Betamax.mode == Mode.recording
        ? RecordingInterceptor()
        : PlaybackInterceptor();

    liveTest!.onComplete.then((value) {
      _activeClient = null;
    });

    _activeClient = HttpInterceptingClient(
        inner: HttpClient()..findProxy = HttpClient.findProxyFromEnvironment,
        interceptor: interceptor);

    if (setCassetteFromTestName) {
      Betamax.setCassette(cassettePathFromTest(liveTest));
    }

    return _activeClient!;
  }

  @visibleForTesting
  static List<String> cassettePathFromTest(LiveTest liveTest) {
    final pathPartNames = [
      ...liveTest.groups
          // Skip root group
          .skip(1)
          .map((g) => g.name),
      liveTest.individualName,
    ];

    // Child groups include the names of their parents, so we strip out the
    // parent prefixes for each
    return pathPartNames.indexed.map((g) {
      final i = g.index;
      final name = g.element;
      final prevName =
          1 <= i && i < pathPartNames.length ? pathPartNames[i - 1] : '';
      return name
          .replaceFirst(RegExp('^${RegExp.escape(prevName)}'), '')
          .trim();
    }).toList();
  }

  /// Explicitly set the cassette used by the last client returned by
  /// [clientForTest].
  ///
  /// This is not required if [clientForTest] was called with
  /// `setCassetteFromTestName: true`.
  static void setCassette(List<String> cassettePathParts) async {
    final cassettePath = '${joinAll(
      [
        suiteName,
        ...cassettePathParts,
      ].map((part) => Slugify(part!.trim(), delimiter: '_')),
    )}.json';

    final interceptor = _activeClient!.interceptor as BetamaxInterceptor;
    interceptor.insertCassette(cassettePath);

    unawaited(
      Invoker.current!.liveTest.onComplete
          .then((value) => interceptor.ejectCassette()),
    );
  }
}

/// Returns the package's test directory path
///
/// The directory returned by [Directory.current] is inconsistent in tests.
/// Sometimes it's the project root, other times it's the project directory,
/// depending on how the tests are invoked.
String _getTestDirectory() {
  final filePathInTest = Trace.current()
      .frames
      .firstWhere((frame) => dirname(frame.location).endsWith('test'))
      .location;
  return dirname(filePathInTest);
}
