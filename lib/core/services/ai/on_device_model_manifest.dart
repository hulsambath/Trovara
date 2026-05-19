/// Pinned manifest for the on-device embedding model bundle.
///
/// Encoder: `intfloat/multilingual-e5-small` INT8 ONNX (`model_qint8_avx512_vnni.onnx`).
/// Tokenizer: the matching `sentencepiece.bpe.model`. Both pulled from a pinned
/// HuggingFace commit so a model swap is always an explicit code change.
///
/// Bumping [version] invalidates every stored embedding by way of
/// `EmbeddingService.isNoteStale` (which compares `modelVersion`), so the
/// existing re-embed path picks up the new model on next launch.
class OnDeviceModelManifest {
  static const String version = 'multilingual-e5-small-int8-v1';
  static const int embeddingDim = 384;
  static const int maxSequenceTokens = 512;

  /// HuggingFace repo commit pinned for reproducibility.
  /// Source: https://huggingface.co/api/models/intfloat/multilingual-e5-small
  static const String _hfCommit = '614241f622f53c4eeff9890bdc4f31cfecc418b3';

  static const String encoderUrl =
      'https://huggingface.co/intfloat/multilingual-e5-small/resolve/$_hfCommit/onnx/model_qint8_avx512_vnni.onnx';
  static const String encoderSha256 = 'dd476dd0c2514e9b9be83aeb3853fac0763e0bdf4a71645407587d77c48a2d88';
  static const int encoderApproxBytes = 113 * 1024 * 1024;

  static const String tokenizerUrl =
      'https://huggingface.co/intfloat/multilingual-e5-small/resolve/$_hfCommit/sentencepiece.bpe.model';
  static const String tokenizerSha256 = 'cfc8146abe2a0488e9e2a0c56de7952f7c11ab059eca145a0a727afce0db2865';
  static const int tokenizerApproxBytes = 5 * 1024 * 1024;

  const OnDeviceModelManifest._();
}
