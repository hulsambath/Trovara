import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/ai/chat_tier.dart';
import 'package:trovara/core/services/ai/retrieval_depth.dart';

import '../../test_support.dart';

void main() {
  patrolTest('free preset is shallow', ($) async {
    const d = RetrievalDepth.free;
    expect(d.fusionPoolSizePerQuery, 5);
    expect(d.topKChunks, 3);
    expect(d.expansionCount, 1);
  });

  patrolTest('pro preset is deeper', ($) async {
    const d = RetrievalDepth.pro;
    expect(d.fusionPoolSizePerQuery, 8);
    expect(d.topKChunks, 5);
    expect(d.expansionCount, 3);
  });

  patrolTest('forTier maps tier to preset', ($) async {
    expect(RetrievalDepth.forTier(ChatTier.free), same(RetrievalDepth.free));
    expect(RetrievalDepth.forTier(ChatTier.pro), same(RetrievalDepth.pro));
  });
}
