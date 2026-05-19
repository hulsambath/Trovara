/// One conversation turn (role + content).
///
/// Record-typed so provider files don't need to import `LlmChatMessage`
/// from `llm_client.dart` — that would create a circular import.
/// Two structurally-equivalent record typedefs refer to the same type
/// in Dart 3, so this is the canonical declaration.
typedef ChatTurn = ({String role, String content});
