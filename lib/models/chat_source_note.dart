class ChatSourceNote {
  final int id;
  final String title;
  final String label;

  const ChatSourceNote({required this.id, required this.title, this.label = ''});

  bool get hasLabel => label.trim().isNotEmpty;

  @override
  String toString() => 'ChatSourceNote(id: $id, title: $title, label: $label)';
}
