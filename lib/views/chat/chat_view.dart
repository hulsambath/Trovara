import 'package:flutter/material.dart';
import 'package:trovara/core/base/view_model_provider.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/services/chat_service.dart';
import 'package:trovara/models/chat_message.dart';
import 'package:trovara/models/chat_thread.dart';

import 'chat_view_model.dart';

part 'chat_content.dart';
part 'widgets/chat_bubble.dart';
part 'widgets/chat_drawer.dart';
part 'widgets/chat_input_field.dart';
part 'widgets/source_attribution.dart';
part 'widgets/suggested_questions.dart';

/// Chat view for asking questions about your notes (RAG Step 6).
///
/// When [embedded] is true the view is shown inside the main tab bar
/// and uses `root: false` so it doesn't re-create providers at the root.
class ChatView extends StatelessWidget {
  const ChatView({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) => ViewModelProvider<ChatViewModel>(
    create: (context) => ChatViewModel(),
    root: !embedded,
    builder: (context, viewModel, child) => _ChatContent(viewModel, embedded: embedded),
  );
}
