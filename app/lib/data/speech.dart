import 'package:flutter_tts/flutter_tts.dart';

/// Prononciation avec la voix anglaise du téléphone (synthèse vocale du système).
/// Les enregistrements du Wiktionnaire viendront avec le pack audio (phase 5).
class Speech {
  FlutterTts? _tts;
  String? _langue;

  /// [accent] : 'us' ou 'uk'. Renvoie false si aucune voix anglaise n'est disponible.
  Future<bool> speak(String text, {String accent = 'us'}) async {
    final langue = accent == 'uk' ? 'en-GB' : 'en-US';
    try {
      final tts = _tts ??= FlutterTts();
      if (_langue != langue) {
        final dispo = await tts.isLanguageAvailable(langue);
        if (dispo != true && dispo != 1) return false;
        await tts.setLanguage(langue);
        await tts.setSpeechRate(0.45);
        _langue = langue;
      }
      await tts.stop();
      await tts.speak(text);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final Speech speech = Speech();
