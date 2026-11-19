import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'native/canaux.dart';

void main() => runApp(
  const MaterialApp(debugShowCheckedModeBanner: false, home: PageAlertes()),
);

class PageAlertes extends StatefulWidget {
  const PageAlertes({super.key});

  @override
  State<PageAlertes> createState() => _PageAlertesState();
}

class _PageAlertesState extends State<PageAlertes> {
  String _derniereAction = 'aucune';

  double _seuilBatterie = 20;

  // Étape 4 : Surveillance continue
  double _seuilTemp = 40;
  bool _surveillance = false;

  @override
  void initState() {
    super.initState();

    CanauxNatifs.ecouterActions(_traiterAction);

    CanauxNatifs.actionInitiale().then((a) {
      if (a != null) _traiterAction(a);
    });

    // Exercice 2 : récupérer l'état réel du service
    CanauxNatifs.estActif().then((actif) {
      if (!mounted) return;
      setState(() => _surveillance = actif);
    });
  }

  void _traiterAction(Map<String, dynamic> a) => setState(
    () => _derniereAction = '${a['action']} : ${a['titre']} (id ${a['id']})',
  );

  void _message(String texte) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(texte)));

  Future<void> _autoriser() async {
    final ok = await CanauxNatifs.demanderPermissionNotif();
    _message(ok ? 'Notifications autorisées' : 'Notifications refusées');
  }

  Future<void> _envoyerAlerte() async {
    try {
      final id = await CanauxNatifs.notifier(
        'Patient critique',
        'Fréquence cardiaque : 142 bpm',
      );
      _message('Alerte envoyée (id $id)');
    } on PlatformException catch (e) {
      _message('Erreur ${e.code} : ${e.message}');
    }
  }

  // Étape 4 : Démarrer ou arrêter le Foreground Service
  Future<void> _basculerSurveillance(bool actif) async {
    if (actif) {
      await CanauxNatifs.demarrerSurveillance(_seuilTemp);
    } else {
      await CanauxNatifs.arreterSurveillance();
    }
    setState(() => _surveillance = actif);
  }

  Widget _carte(String titre, List<Widget> contenu) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...contenu,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TP 4 – Alertes natives')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _carte('1. Notification native', [
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _autoriser,
                  child: const Text('Autoriser'),
                ),
                FilledButton(
                  onPressed: _envoyerAlerte,
                  child: const Text('Envoyer une alerte'),
                ),
              ],
            ),
          ]),

          _carte('2. Dernière action reçue de la notification', [
            Text(_derniereAction),
          ]),

          _carte('3. Vérification périodique (WorkManager)', [
            Text('Alerte si batterie ≤ ${_seuilBatterie.round()} %'),
            Slider(
              value: _seuilBatterie,
              min: 5,
              max: 100,
              divisions: 19,
              label: '${_seuilBatterie.round()} %',
              onChanged: (v) => setState(() => _seuilBatterie = v),
            ),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: () async {
                    await CanauxNatifs.planifier(_seuilBatterie.round());
                    _message('Vérification toutes les 15 min');
                  },
                  child: const Text('Planifier'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      CanauxNatifs.verifierMaintenant(_seuilBatterie.round()),
                  child: const Text('Vérifier maintenant'),
                ),
                TextButton(
                  onPressed: () async {
                    await CanauxNatifs.annulerPlanification();
                    _message('Planification annulée');
                  },
                  child: const Text('Annuler'),
                ),
              ],
            ),
          ]),

          // Étape 4 : Surveillance continue
          _carte('4. Surveillance continue (service au premier plan)', [
            Text('Alerte si température ≥ ${_seuilTemp.round()} °C'),
            Slider(
              value: _seuilTemp,
              min: 20,
              max: 50,
              divisions: 30,
              label: '${_seuilTemp.round()} °C',
              onChanged: (v) => setState(() => _seuilTemp = v),
              onChangeEnd: (v) {
                // service actif : on envoie le nouveau seuil
                if (_surveillance) CanauxNatifs.demarrerSurveillance(v);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Surveillance'),
              value: _surveillance,
              onChanged: _basculerSurveillance,
            ),
          ]),
        ],
      ),
    );
  }
}
