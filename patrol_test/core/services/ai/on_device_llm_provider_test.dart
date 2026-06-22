import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/ai/_providers/on_device_llm_provider.dart';

import '../../test_support.dart';

void main() {
  patrolTest('generate returns the coming-soon sentinel', ($) async {
    final provider = OnDeviceLlmProvider();
    final answer = await provider.generate(systemPrompt: 's', history: const [], userMessage: 'hi');
    expect(answer, OnDeviceLlmProvider.comingSoonAnswer);
  });

  patrolTest('generateStream yields the sentinel as one chunk', ($) async {
    final provider = OnDeviceLlmProvider();
    final chunks = await provider
        .generateStream(systemPrompt: 's', history: const [], userMessage: 'hi')
        .toList();
    expect(chunks, [OnDeviceLlmProvider.comingSoonAnswer]);
  });
}
