// End-to-end on-device embedding test.
//
// Run on an emulator/device:
//   ./scripts/patrol_test.sh integration_test/on_device_embedding_test.dart
//
// First run downloads ~118 MB (encoder + tokenizer) from HuggingFace.
// Subsequent runs use the SHA-256-verified cache.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trovara/core/services/ai/_providers/onnx_embedding_provider.dart';
import 'package:trovara/core/services/ai/on_device_model_manifest.dart';
import 'package:trovara/core/services/ai/on_device_model_service.dart';

double _cosine(List<double> a, List<double> b) {
  assert(a.length == b.length, 'vectors must be same dim');
  var dot = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
  }
  // a and b are L2-normalized by the provider, so cosine == dot product.
  return dot;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('on-device embedding end-to-end', () {
    late OnDeviceModelService modelService;
    late OnnxEmbeddingProvider provider;

    setUpAll(() async {
      modelService = OnDeviceModelService();
      final paths = await modelService.ensureReady();
      provider = OnnxEmbeddingProvider(
        encoderPath: paths.encoder,
        tokenizerPath: paths.tokenizer,
        embeddingDim: OnDeviceModelManifest.embeddingDim,
        maxSequenceTokens: OnDeviceModelManifest.maxSequenceTokens,
      );
    });

    tearDownAll(() async {
      await provider.dispose();
      modelService.dispose();
    });

    testWidgets('produces a finite 384-dim unit vector for a query', (tester) async {
      final vec = await provider.embed('what is the meaning of life', isQuery: true);
      expect(vec, isNotNull);
      expect(vec!.length, OnDeviceModelManifest.embeddingDim);
      expect(vec.every((v) => v.isFinite), isTrue);
      final norm = math.sqrt(vec.fold<double>(0.0, (acc, x) => acc + x * x));
      expect(norm, closeTo(1.0, 1e-3));
    });

    testWidgets('cross-lingual EN→KM retrieval has non-trivial similarity', (tester) async {
      final query = await provider.embed('what is the meaning of life', isQuery: true);
      final relatedPassage = await provider.embed(
        'អត្ថន័យនៃជីវិតគឺជាការសិក្សា និងការរីកចម្រើន។', // "The meaning of life is learning and growth."
        isQuery: false,
      );
      final unrelatedPassage = await provider.embed(
        'ខ្ញុំចូលចិត្តញ៉ាំអាហារ។', // "I like to eat food."
        isQuery: false,
      );

      expect(query, isNotNull);
      expect(relatedPassage, isNotNull);
      expect(unrelatedPassage, isNotNull);

      final relatedSim = _cosine(query!, relatedPassage!);
      final unrelatedSim = _cosine(query, unrelatedPassage!);

      // Sanity threshold, not a quality bar. Real multilingual-e5-small
      // numbers are typically 0.7+ for related and 0.5- for unrelated.
      expect(relatedSim, greaterThan(0.3));
      expect(relatedSim, greaterThan(unrelatedSim));
    });
  });
}
