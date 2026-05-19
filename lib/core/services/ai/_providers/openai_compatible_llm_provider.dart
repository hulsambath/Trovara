import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:trovara/core/services/ai/_providers/llm_chat_backend.dart';
import 'package:trovara/core/services/ai/llm_api_exception.dart';

/// LLM provider for any OpenAI-compatible chat completions endpoint
/// (OpenAI, OpenRouter, self-hosted proxies).
class OpenAiCompatibleLlmProvider implements LlmChatBackend {
  final String apiKey;
  final String baseUrl;
  final String modelName;
  final String? siteUrl;
  final String? appName;
  final double temperature;
  final double topP;
  final int maxOutputTokens;

  final http.Client _client = http.Client();
  final Logger _logger = Logger();

  OpenAiCompatibleLlmProvider({
    required this.apiKey,
    required this.baseUrl,
    required this.modelName,
    this.siteUrl,
    this.appName,
    required this.temperature,
    required this.topP,
    required this.maxOutputTokens,
  });

  @override
  Future<String> generate({
    required String systemPrompt,
    required List<ChatTurn> history,
    required String userMessage,
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/chat/completions'),
      headers: _buildHeaders(),
      body: jsonEncode(_buildBody(systemPrompt, history, userMessage, stream: false)),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw LlmApiException.fromHttp(statusCode: res.statusCode, body: res.body);
    }

    final decoded = jsonDecode(res.body);
    final choices = (decoded is Map<String, dynamic>) ? decoded['choices'] : null;
    if (choices is! List || choices.isEmpty) {
      _logger.w('LLM returned no choices');
      return 'No response generated.';
    }

    final message = (choices.first as Map)['message'];
    final content = (message is Map) ? message['content'] : null;
    final text = content?.toString() ?? '';
    if (text.isEmpty) {
      _logger.w('LLM returned empty response');
      return 'No response generated.';
    }
    _logger.d('LLM generated ${text.length} chars');
    return text;
  }

  @override
  Stream<String> generateStream({
    required String systemPrompt,
    required List<ChatTurn> history,
    required String userMessage,
  }) async* {
    final req = http.Request('POST', Uri.parse('$baseUrl/chat/completions'))
      ..headers.addAll(_buildHeaders())
      ..body = jsonEncode(_buildBody(systemPrompt, history, userMessage, stream: true));

    final streamed = await _client.send(req);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final body = await streamed.stream.bytesToString();
      throw LlmApiException.fromHttp(statusCode: streamed.statusCode, body: body);
    }

    final lines = streamed.stream.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || !trimmed.startsWith('data:')) continue;
      final data = trimmed.substring('data:'.length).trim();
      if (data == '[DONE]') break;

      dynamic chunk;
      try {
        chunk = jsonDecode(data);
      } catch (_) {
        continue;
      }
      if (chunk is! Map) continue;
      final choices = chunk['choices'];
      if (choices is! List || choices.isEmpty) continue;
      final delta = (choices.first as Map)['delta'];
      final content = (delta is Map) ? delta['content'] : null;
      final text = content?.toString() ?? '';
      if (text.isNotEmpty) yield text;
    }
  }

  Map<String, dynamic> _buildBody(
    String systemPrompt,
    List<ChatTurn> history,
    String userMessage, {
    required bool stream,
  }) {
    final messages = <Map<String, dynamic>>[];
    final sys = systemPrompt.trim();
    if (sys.isNotEmpty) messages.add({'role': 'system', 'content': sys});
    for (final h in history) {
      messages.add({'role': h.role, 'content': h.content});
    }
    messages.add({'role': 'user', 'content': userMessage});

    final body = <String, dynamic>{
      'model': modelName,
      'messages': messages,
      'temperature': temperature,
      'top_p': topP,
      'max_tokens': maxOutputTokens,
    };
    if (stream) body['stream'] = true;
    return body;
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'};
    final site = siteUrl?.trim();
    final app = appName?.trim();
    if (site != null && site.isNotEmpty) headers['HTTP-Referer'] = site;
    if (app != null && app.isNotEmpty) headers['X-Title'] = app;
    return headers;
  }
}
