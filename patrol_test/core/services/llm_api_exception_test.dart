import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/ai/llm_api_exception.dart';

/// Regression coverage for [LlmApiException] classification.
///
/// Locks in the distinction between an HTTP error *response* and a
/// connectivity failure that never reached the server — the latter must be
/// flagged as a network error, not a generic 500 / `firebase_error`.
void main() {
  group('LlmApiException', () {
    group('network', () {
      test('factory produces a network error with status 0', () {
        final e = LlmApiException.network('Failed host lookup: api.openai.com');

        expect(e.isNetworkError, isTrue);
        expect(e.statusCode, 0);
        expect(e.code, 'network_error');
        expect(e.type, 'network_error');
      });

      test('is not classified as an insufficient-quota error', () {
        final e = LlmApiException.network('SocketException');

        expect(e.isInsufficientQuota, isFalse);
      });
    });

    group('isNetworkError', () {
      test('false for an HTTP error response', () {
        final e = LlmApiException.fromHttp(statusCode: 500, body: '{"error":{"message":"boom","code":"internal"}}');

        expect(e.isNetworkError, isFalse);
      });

      test('false for a quota error', () {
        final e = LlmApiException(statusCode: 429, message: 'quota', code: 'insufficient_quota');

        expect(e.isNetworkError, isFalse);
        expect(e.isInsufficientQuota, isTrue);
      });
    });

    group('toString', () {
      test('includes status, type and code', () {
        final e = LlmApiException.network('Failed host lookup');

        expect(e.toString(), contains('LLM API error (0)'));
        expect(e.toString(), contains('type=network_error'));
        expect(e.toString(), contains('code=network_error'));
      });
    });
  });
}
