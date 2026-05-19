import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:trovara/core/services/ai/on_device_model_manifest.dart';
import 'package:trovara/core/services/ai/on_device_model_service.dart';

// NOTE: Uses plain `test()` instead of the project's `patrolTest` wrapper.
// `patrolWidgetTest` runs the body inside a FakeAsync zone that does not drive
// real Dart Streams (e.g. from http.StreamedResponse), so awaiting a streamed
// download deadlocks. These tests do pure dart:io work and need a plain zone.

// ═══════════════════════════════════════════════════════════════════════════
//  Stub HTTP client
// ═══════════════════════════════════════════════════════════════════════════

class _StubClient extends http.BaseClient {
  final Map<String, List<int>> responses;
  final Set<String> failingUrls;
  int callCount = 0;

  _StubClient(this.responses, {this.failingUrls = const {}});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    callCount++;
    final url = request.url.toString();
    if (failingUrls.contains(url)) {
      throw const SocketException('stub network error');
    }
    final body = responses[url];
    if (body == null) {
      return http.StreamedResponse(Stream<List<int>>.fromIterable(const <List<int>>[]), 404);
    }
    final mid = body.length ~/ 2;
    final stream = Stream<List<int>>.fromIterable([body.sublist(0, mid), body.sublist(mid)]);
    return http.StreamedResponse(stream, 200, contentLength: body.length);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Helpers
// ═══════════════════════════════════════════════════════════════════════════

Future<Directory> _makeTempDocs() => Directory.systemTemp.createTemp('on_device_model_test_');

OnDeviceModelService _makeService(http.Client client, Directory docs) =>
    OnDeviceModelService(client: client, docsDirResolver: () async => docs);

Future<void> _seedExistingFiles({
  required Directory docs,
  required List<int> encoderBytes,
  required List<int> tokenizerBytes,
}) async {
  final modelDir = Directory(p.join(docs.path, 'embedding_models', OnDeviceModelManifest.version));
  await modelDir.create(recursive: true);
  await File(p.join(modelDir.path, 'encoder.onnx')).writeAsBytes(encoderBytes);
  await File(p.join(modelDir.path, 'tokenizer.spm')).writeAsBytes(tokenizerBytes);
}

// ═══════════════════════════════════════════════════════════════════════════
//  Tests
// ═══════════════════════════════════════════════════════════════════════════

void main() {
  final encoderBytes = utf8.encode('FAKE_ENCODER_BYTES_FOR_TEST');
  final tokenizerBytes = utf8.encode('FAKE_TOKENIZER_BYTES_FOR_TEST');

  group('OnDeviceModelService', () {
    test('SHA-256 mismatch throws OnDeviceModelException', () async {
      final docs = await _makeTempDocs();
      final stub = _StubClient({
        OnDeviceModelManifest.encoderUrl: encoderBytes,
        OnDeviceModelManifest.tokenizerUrl: tokenizerBytes,
      });
      final svc = _makeService(stub, docs);

      // Stub bytes hash to something that won't match the manifest's pinned hash,
      // so the service must raise after the download completes.
      await expectLater(svc.ensureReady(), throwsA(isA<OnDeviceModelException>()));
      expect(stub.callCount, greaterThan(0));

      svc.dispose();
      await docs.delete(recursive: true);
    });

    test('pre-existing files with mismatching SHA-256 trigger redownload', () async {
      final docs = await _makeTempDocs();
      await _seedExistingFiles(docs: docs, encoderBytes: encoderBytes, tokenizerBytes: tokenizerBytes);

      final stub = _StubClient({
        OnDeviceModelManifest.encoderUrl: encoderBytes,
        OnDeviceModelManifest.tokenizerUrl: tokenizerBytes,
      });
      final svc = _makeService(stub, docs);

      await expectLater(svc.ensureReady(), throwsA(isA<OnDeviceModelException>()));
      expect(stub.callCount, greaterThan(0), reason: 'must redownload when on-disk SHA-256 differs from manifest');

      svc.dispose();
      await docs.delete(recursive: true);
    });

    test('network error leaves no .part files behind', () async {
      final docs = await _makeTempDocs();
      final stub = _StubClient({}, failingUrls: {OnDeviceModelManifest.encoderUrl});
      final svc = _makeService(stub, docs);

      await expectLater(svc.ensureReady(), throwsA(isA<Object>()));

      final modelDir = Directory(p.join(docs.path, 'embedding_models', OnDeviceModelManifest.version));
      if (await modelDir.exists()) {
        final leftovers = await modelDir.list().where((e) => e.path.endsWith('.part')).toList();
        expect(leftovers, isEmpty);
      }

      svc.dispose();
      await docs.delete(recursive: true);
    });

    test('non-200 HTTP response surfaces OnDeviceModelException', () async {
      final docs = await _makeTempDocs();
      final stub = _StubClient({}); // 404 for everything
      final svc = _makeService(stub, docs);

      await expectLater(
        svc.ensureReady(),
        throwsA(isA<OnDeviceModelException>().having((e) => e.message, 'message', contains('HTTP 404'))),
      );

      svc.dispose();
      await docs.delete(recursive: true);
    });

    test('progressStream emits at least one event during download', () async {
      final docs = await _makeTempDocs();
      final stub = _StubClient({
        OnDeviceModelManifest.encoderUrl: encoderBytes,
        OnDeviceModelManifest.tokenizerUrl: tokenizerBytes,
      });
      final svc = _makeService(stub, docs);

      final events = <DownloadProgress>[];
      final sub = svc.progressStream.listen(events.add);

      try {
        await svc.ensureReady();
      } catch (_) {
        // SHA mismatch expected — we only care that progress fired first.
      }

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      expect(events, isNotEmpty);
      expect(events.first.totalBytes, equals(encoderBytes.length));

      svc.dispose();
      await docs.delete(recursive: true);
    });

    test('ensureReady starts unready and exposes null cached paths', () async {
      final svc = OnDeviceModelService(docsDirResolver: _makeTempDocs);
      expect(svc.isReady, isFalse);
      expect(svc.cachedPaths, isNull);
      svc.dispose();
    });
  });
}
