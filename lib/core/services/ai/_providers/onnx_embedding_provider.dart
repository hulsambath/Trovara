import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart_sentencepiece_tokenizer/dart_sentencepiece_tokenizer.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:logger/logger.dart';

/// Function that runs the encoder forward pass given padded `input_ids` and
/// `attention_mask`, returning the `[seq_len, embeddingDim]` token outputs.
///
/// Wrapped so tests can swap in a stub without instantiating an OrtSession.
typedef EncoderRunner =
    Future<List<List<double>>> Function({required List<int> inputIds, required List<int> attentionMask});

/// On-device sentence embedding provider backed by an ONNX encoder
/// (multilingual-e5-small) + a pure-Dart SentencePiece tokenizer.
///
/// Returns `null` on any error so [EmbeddingService]'s pending-queue retry path
/// keeps working — mirrors [GeminiEmbeddingProvider] / [OpenAiCompatibleEmbeddingProvider].
class OnnxEmbeddingProvider {
  static const String queryPrefix = 'query: ';
  static const String passagePrefix = 'passage: ';

  final String encoderPath;
  final String tokenizerPath;
  final int embeddingDim;
  final int maxSequenceTokens;
  final Logger _logger = Logger();

  /// Inference runner. Defaults to a real [OrtSession]-backed implementation
  /// resolved lazily on first [embed] call; tests inject a fake.
  final EncoderRunner? _runnerOverride;

  /// Tokenizer override for tests; otherwise loaded from [tokenizerPath].
  final SentencePieceTokenizer? _tokenizerOverride;

  OrtSession? _session;
  SentencePieceTokenizer? _tokenizer;
  EncoderRunner? _runner;

  OnnxEmbeddingProvider({
    required this.encoderPath,
    required this.tokenizerPath,
    required this.embeddingDim,
    this.maxSequenceTokens = 512,
    EncoderRunner? runner,
    SentencePieceTokenizer? tokenizer,
  }) : _runnerOverride = runner,
       _tokenizerOverride = tokenizer;

  Future<List<double>?> embed(String text, {required bool isQuery}) async {
    try {
      await _ensureLoaded();
      final encoding = _tokenizer!.encode((isQuery ? queryPrefix : passagePrefix) + text);
      final ids = encoding.ids;
      final mask = encoding.attentionMask.map((b) => b.toInt()).toList(growable: false);
      final tokenOutputs = await _runner!(inputIds: ids, attentionMask: mask);
      final pooled = meanPool(tokenOutputs: tokenOutputs, attentionMask: mask, dim: embeddingDim);
      return l2Normalize(pooled);
    } catch (e, st) {
      _logger.e('ONNX embedding error: $e\n$st');
      return null;
    }
  }

  Future<void> _ensureLoaded() async {
    _tokenizer ??= _tokenizerOverride ?? await SentencePieceTokenizer.fromModelFile(tokenizerPath);
    _tokenizer!
      ..enableTruncation(maxLength: maxSequenceTokens)
      ..enablePadding(length: maxSequenceTokens);
    if (_runnerOverride != null) {
      _runner ??= _runnerOverride;
      return;
    }
    _session ??= await OnnxRuntime().createSession(encoderPath);
    _runner ??= _buildOrtRunner(_session!, embeddingDim);
  }

  // ignore: prefer_expression_function_bodies
  static EncoderRunner _buildOrtRunner(OrtSession session, int embeddingDim) {
    return ({required List<int> inputIds, required List<int> attentionMask}) async {
      final seqLen = inputIds.length;
      final ids = Int64List.fromList(inputIds);
      final mask = Int64List.fromList(attentionMask);
      final idsTensor = await OrtValue.fromList(ids, [1, seqLen]);
      final maskTensor = await OrtValue.fromList(mask, [1, seqLen]);
      try {
        // E5 / XLM-R encoder takes input_ids + attention_mask; some exports
        // require token_type_ids. Provide it as zeros if the model declares it.
        final inputs = <String, OrtValue>{'input_ids': idsTensor, 'attention_mask': maskTensor};
        if (session.inputNames.contains('token_type_ids')) {
          inputs['token_type_ids'] = await OrtValue.fromList(Int64List(seqLen), [1, seqLen]);
        }
        final outputs = await session.run(inputs);
        final outputName = session.outputNames.firstWhere(
          (n) => n.toLowerCase().contains('last_hidden_state') || n.toLowerCase().contains('hidden'),
          orElse: () => session.outputNames.first,
        );
        final tensor = outputs[outputName]!;
        final flat = (await tensor.asFlattenedList()).cast<num>();
        // Reshape [1, seq_len, embeddingDim] → List<List<double>> of [seq_len][embeddingDim]
        final result = List<List<double>>.generate(
          seqLen,
          (t) => List<double>.generate(embeddingDim, (i) => flat[t * embeddingDim + i].toDouble(), growable: false),
          growable: false,
        );
        for (final v in outputs.values) {
          await v.dispose();
        }
        return result;
      } finally {
        await idsTensor.dispose();
        await maskTensor.dispose();
      }
    };
  }

  Future<void> dispose() async {
    await _session?.close();
    _session = null;
  }

  // ── Pure helpers (exposed for tests) ───────────────────────────────────────

  /// Mean-pool token-level outputs, weighting by [attentionMask] (so padding
  /// tokens don't dilute the average). E5 reference behavior.
  static List<double> meanPool({
    required List<List<double>> tokenOutputs,
    required List<int> attentionMask,
    required int dim,
  }) {
    final pooled = List<double>.filled(dim, 0.0);
    var valid = 0;
    for (var t = 0; t < tokenOutputs.length; t++) {
      if (t >= attentionMask.length || attentionMask[t] == 0) continue;
      valid++;
      final row = tokenOutputs[t];
      for (var i = 0; i < dim; i++) {
        pooled[i] += row[i];
      }
    }
    if (valid == 0) return pooled;
    for (var i = 0; i < dim; i++) {
      pooled[i] /= valid;
    }
    return pooled;
  }

  /// L2-normalize so cosine similarity == dot product, matching the
  /// invariant `VectorSearchService._cosineSimilarity` already assumes.
  static List<double> l2Normalize(List<double> v) {
    var sumSq = 0.0;
    for (final x in v) {
      sumSq += x * x;
    }
    final norm = math.sqrt(sumSq);
    if (norm == 0.0) return v;
    return List<double>.generate(v.length, (i) => v[i] / norm, growable: false);
  }
}
