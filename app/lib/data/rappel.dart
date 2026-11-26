import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Rappel quotidien de révision : une alarme et une notification locales (Android seulement).
/// Rien n'est envoyé nulle part ; le code natif est dans tools/android/RappelPlugin.kt.
class Rappel {
  static const MethodChannel _canal = MethodChannel('dicoenfr/rappel');

  static bool get disponible => Platform.isAndroid;

  /// Demande l'autorisation d'afficher des notifications. Faux si refusée ou indisponible.
  static Future<bool> demanderPermission() async {
    if (!disponible) return false;
    try {
      return await _canal.invokeMethod<bool>('permission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> planifier(int minutes) async {
    if (!disponible) return false;
    try {
      return await _canal.invokeMethod<bool>(
              'planifier', {'heure': minutes ~/ 60, 'minute': minutes % 60}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> annuler() async {
    if (!disponible) return;
    try {
      await _canal.invokeMethod<bool>('annuler');
    } on PlatformException {
      // rien à faire
    } on MissingPluginException {
      // rien à faire
    }
  }
}
