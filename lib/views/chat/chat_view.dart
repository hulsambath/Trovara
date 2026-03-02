import 'package:flutter/material.dart';
import 'package:trovara/core/base/view_model_provider.dart';
import 'package:trovara/models/chat_message.dart';

import 'chat_view_model.dart';

part 'chat_content.dart';
part 'widgets/chat_bubble.dart';
part 'widgets/chat_input_field.dart';
part 'widgets/source_attribution.dart';
part 'widgets/suggested_questions.dart';

/// Chat view for asking questions about your notes (RAG Step 6).
///
/// Follows the same ViewModelProvider pattern as other screens in Trovara.
class ChatView extends StatelessWidget {
  const ChatView({super.key});

  @override
  Widget build(BuildContext context) => ViewModelProvider<ChatViewModel>(
    create: (context) => ChatViewModel(),
    root: true,
    builder: (context, viewModel, child) => _ChatContent(viewModel),
  );
}
