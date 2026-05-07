import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/ai/rag_chat_memory.dart';
import 'package:trovara/models/chat_message.dart';

ChatMessageEntity _e({required String role, required String content}) =>
    ChatMessageEntity(threadId: 1, role: role, content: content);

RagChatTurn _t(String role, String content) => RagChatTurn(role: role, content: content);

void main() {
  group('RagChatMemory.turnsFromEntities', () {
    test('keeps only user/assistant, trims/lowercases role and trims content', () {
      final turns = RagChatMemory.turnsFromEntities([
        _e(role: ' user ', content: '  hello  '),
        _e(role: 'ASSISTANT', content: '  hi there '),
        _e(role: 'system', content: 'ignore me'),
        _e(role: 'tool', content: 'ignore me too'),
      ]);

      expect(turns, hasLength(2));
      expect(turns[0].role, 'user');
      expect(turns[0].content, 'hello');
      expect(turns[1].role, 'assistant');
      expect(turns[1].content, 'hi there');
    });

    test('drops empty/whitespace-only content', () {
      final turns = RagChatMemory.turnsFromEntities([
        _e(role: 'user', content: ''),
        _e(role: 'assistant', content: '   \n\t  '),
        _e(role: 'user', content: ' ok '),
      ]);

      expect(turns, hasLength(1));
      expect(turns.single.role, 'user');
      expect(turns.single.content, 'ok');
    });
  });

  group('RagChatMemory.truncate', () {
    test('keeps a suffix limited to maxPriorMessages (20)', () {
      final turns = List.generate(25, (i) => _t(i.isEven ? 'user' : 'assistant', 'm$i'));

      final truncated = RagChatMemory.truncate(turns);

      expect(truncated, hasLength(RagChatMemoryLimits.maxPriorMessages));
      expect(truncated.first.content, 'm5');
      expect(truncated.last.content, 'm24');
    });

    test('enforces maxPriorChars (6000) by dropping from the front', () {
      // 10 turns * 1000 chars = 10,000 chars; should drop to last 6 turns (6000 chars).
      final turns = List.generate(10, (i) => _t(i.isEven ? 'user' : 'assistant', 'a' * 1000));

      final truncated = RagChatMemory.truncate(turns);

      expect(truncated, hasLength(6));
      expect(truncated.fold<int>(0, (sum, t) => sum + t.content.length), RagChatMemoryLimits.maxPriorChars);
    });

    test('returns empty when even a single turn exceeds the char budget', () {
      final turns = [_t('user', 'a' * (RagChatMemoryLimits.maxPriorChars + 1))];
      expect(RagChatMemory.truncate(turns), isEmpty);
    });
  });

  group('RagChatMemory.formatForQueryRewrite', () {
    test('returns empty string for empty input', () {
      expect(RagChatMemory.formatForQueryRewrite(const []), '');
    });

    test('labels lines and has no trailing newline', () {
      final out = RagChatMemory.formatForQueryRewrite([_t('user', 'hello'), _t('assistant', 'hi')]);

      expect(out, 'User: hello\nAssistant: hi');
      expect(out.endsWith('\n'), isFalse);
    });
  });
}
