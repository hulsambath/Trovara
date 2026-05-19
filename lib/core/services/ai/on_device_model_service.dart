import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:trovara/core/services/ai/on_device_model_manifest.dart';

class DownloadProgress {
  final String fileName;
  final int receivedBytes;
  final int totalBytes;
  const DownloadProgress({required this.fileName, required this.receivedBytes, required this.totalBytes});

  double get fraction => totalBytes <= 0 ? 0.0 : (receivedBytes / totalBytes).clamp(0.0, 1.0);
}

class ResolvedModelPaths {
  final String encoder;
  final String tokenizer;
  const ResolvedModelPaths({required this.encoder, required this.tokenizer});
}

class OnDeviceModelException implements Exception {
  final String message;
  OnDeviceModelException(this.message);
  @override
  String toString() => 'OnDeviceModelException: $message';
}

/// Ensures the on-device embedding model + tokenizer are present on disk and
/// SHA-256-verified. Streams download progress for the Settings UI.
///
/// Lifecycle: [ensureReady] is idempotent; once it succeeds in a session the
/// resolved paths are cached. The files live under
/// `<app_documents>/embedding_models/<version>/` so a version bump always
/// downloads into a fresh directory instead of mutating in place.
class OnDeviceModelService {
  final http.Client _client;
  final Future<Directory> Function() _docsDirResolver;
  final Logger _logger = Logger();
  final _progress = StreamController<DownloadProgress>.broadcast();

  ResolvedModelPaths? _cached;

  Stream<DownloadProgress> get progressStream => _progress.stream;
  bool get isReady => _cached != null;
  ResolvedModelPaths? get cachedPaths => _cached;

  OnDeviceModelService({http.Client? client, Future<Directory> Function()? docsDirResolver})
    : _client = client ?? http.Client(),
      _docsDirResolver = docsDirResolver ?? getApplicationDocumentsDirectory;

  Future<ResolvedModelPaths> ensureReady() async {
    if (_cached != null) return _cached!;

    final root = await _modelDir();
    final encoder = File(p.join(root, 'encoder.onnx'));
    final tokenizer = File(p.join(root, 'tokenizer.spm'));

    await _ensureFile(
      target: encoder,
      url: OnDeviceModelManifest.encoderUrl,
      expectedSha: OnDeviceModelManifest.encoderSha256,
      approxBytes: OnDeviceModelManifest.encoderApproxBytes,
    );
    await _ensureFile(
      target: tokenizer,
      url: OnDeviceModelManifest.tokenizerUrl,
      expectedSha: OnDeviceModelManifest.tokenizerSha256,
      approxBytes: OnDeviceModelManifest.tokenizerApproxBytes,
    );

    _cached = ResolvedModelPaths(encoder: encoder.path, tokenizer: tokenizer.path);
    _logger.i('On-device model ready (version=${OnDeviceModelManifest.version})');
    return _cached!;
  }

  Future<String> _modelDir() async {
    final docs = await _docsDirResolver();
    final dir = Directory(p.join(docs.path, 'embedding_models', OnDeviceModelManifest.version));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<void> _ensureFile({
    required File target,
    required String url,
    required String expectedSha,
    required int approxBytes,
  }) async {
    if (await _isValid(target, expectedSha)) return;
    if (await target.exists()) await target.delete();

    final tmp = File('${target.path}.part');
    if (await tmp.exists()) await tmp.delete();

    _logger.i('Downloading ${p.basename(target.path)} from $url');
    final res = await _client.send(http.Request('GET', Uri.parse(url)));
    if (res.statusCode != 200) {
      throw OnDeviceModelException('HTTP ${res.statusCode} downloading $url');
    }

    final total = res.contentLength ?? approxBytes;
    final sink = tmp.openWrite();
    var received = 0;
    try {
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        _progress.add(DownloadProgress(fileName: p.basename(target.path), receivedBytes: received, totalBytes: total));
      }
      await sink.flush();
      await sink.close();
    } catch (e) {
      await sink.close();
      if (await tmp.exists()) await tmp.delete();
      throw OnDeviceModelException('Download failed for ${p.basename(target.path)}: $e');
    }

    if (!await _isValid(tmp, expectedSha)) {
      await tmp.delete();
      throw OnDeviceModelException('SHA-256 mismatch for ${p.basename(target.path)}');
    }
    await tmp.rename(target.path);
  }

  Future<bool> _isValid(File f, String expectedSha) async {
    if (!await f.exists()) return false;
    final bytes = await f.readAsBytes();
    return sha256.convert(bytes).toString() == expectedSha;
  }

  void dispose() {
    _progress.close();
    _client.close();
  }
}
