import 'package:flutter/foundation.dart';

/// Log só em modo debug. Em release nada é escrito no logcat/console do aparelho.
/// Nunca passe tokens, senhas ou conteúdo de mensagens.
void logDebug(String message) {
  if (kDebugMode) debugPrint(message);
}
