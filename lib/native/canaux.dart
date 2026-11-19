import 'package:flutter/services.dart';

/// Point d'accès unique au code natif.
class CanauxNatifs {
  static const _alerte = MethodChannel('alerte/notifier');
  static const _sync = MethodChannel('sync/planifier');
  static const _service = MethodChannel('service/surveillance');

  static Future<bool> demanderPermissionNotif() async =>
      await _alerte.invokeMethod<bool>('demanderPermission') ?? false;

  static Future<int?> notifier(String titre, String texte) =>
      _alerte.invokeMethod<int>('notifier', {'titre': titre, 'texte': texte});

  // Démarrage à froid : Dart demande
  static Future<Map<String, dynamic>?> actionInitiale() =>
      _alerte.invokeMapMethod<String, dynamic>('actionInitiale');

  // Application ouverte : Kotlin prévient
  static void ecouterActions(void Function(Map<String, dynamic>) traiter) {
    _alerte.setMethodCallHandler((call) async {
      if (call.method == 'surAction') {
        traiter(Map<String, dynamic>.from(call.arguments as Map));
      }
    });
  }

  // Étape 3 : WorkManager
  static Future<void> planifier(int seuil) =>
      _sync.invokeMethod('planifier', {'seuil': seuil});

  static Future<void> verifierMaintenant(int seuil) =>
      _sync.invokeMethod('maintenant', {'seuil': seuil});

  static Future<void> annulerPlanification() => _sync.invokeMethod('annuler');

  // Étape 4 : Foreground Service
  static Future<void> demarrerSurveillance(double seuil) =>
      _service.invokeMethod('demarrer', {'seuil': seuil});

  static Future<void> arreterSurveillance() => _service.invokeMethod('arreter');

  // Exercice 2 : vérifier si le service est actif
  static Future<bool> estActif() async =>
      await _service.invokeMethod<bool>('estActif') ?? false;
}
