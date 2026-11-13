import 'package:flutter/material.dart';
import 'package:athletix_data/services/reglages.dart';

/// Accessibilité et mode adapté (pistes de la rencontre avec la patiente atteinte de sclérose en plaques).
class ReglagesScreen extends StatelessWidget {
  const ReglagesScreen({super.key});

  Widget _interrupteur(ValueNotifier<bool> reglage, IconData icone, String titre, String detail) {
    return ValueListenableBuilder<bool>(
      valueListenable: reglage,
      builder: (context, valeur, _) => Card(
        color: Colors.grey[900],
        child: SwitchListTile(
          secondary: Icon(icone, color: Colors.orange),
          title: Text(titre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          subtitle: Text(detail, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          value: valeur,
          activeThumbColor: Colors.orange,
          onChanged: (v) => Reglages.changer(reglage, v),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('RÉGLAGES'), backgroundColor: Colors.blueGrey[900], centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('ACCESSIBILITÉ', style: TextStyle(color: Colors.white54, letterSpacing: 1, fontSize: 12)),
          const SizedBox(height: 6),
          _interrupteur(Reglages.grandsCaracteres, Icons.text_increase, 'Grands caractères',
              'Texte et boutons agrandis dans toute l\'application.'),
          _interrupteur(Reglages.alertesVibration, Icons.vibration, 'Alertes par vibration',
              'Le téléphone vibre à chaque alerte d\'effort intense.'),
          _interrupteur(Reglages.alertesVoix, Icons.record_voice_over, 'Alertes à voix haute',
              'L\'alerte est annoncée (« Effort intense »), utile si l\'écran est difficile à lire.'),
          const SizedBox(height: 18),
          const Text('OBJECTIF', style: TextStyle(color: Colors.white54, letterSpacing: 1, fontSize: 12)),
          const SizedBox(height: 6),
          ValueListenableBuilder<int>(
            valueListenable: Reglages.objectifSeances,
            builder: (context, n, _) => Card(
              color: Colors.grey[900],
              child: ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.orange),
                title: Text('$n séance${n > 1 ? 's' : ''} par semaine',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text("Affiché sur l'accueil.", style: TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: 'Moins',
                    onPressed: n > 1 ? () => Reglages.changerObjectif(n - 1) : null,
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.white70),
                  ),
                  IconButton(
                    tooltip: 'Plus',
                    onPressed: n < 14 ? () => Reglages.changerObjectif(n + 1) : null,
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text('CARTE', style: TextStyle(color: Colors.white54, letterSpacing: 1, fontSize: 12)),
          const SizedBox(height: 6),
          _interrupteur(Reglages.fondDeCarte, Icons.map_outlined, 'Fond de carte sous le parcours',
              'Affiche les rues (OpenStreetMap) sous le tracé. Les images de la carte sont demandées aux serveurs '
                  "d'OpenStreetMap pour la zone du parcours (sans compte ni nom). Désactivé : tracé seul, rien n'est envoyé."),
          const SizedBox(height: 18),
          const Text('MODE ADAPTÉ', style: TextStyle(color: Colors.white54, letterSpacing: 1, fontSize: 12)),
          const SizedBox(height: 6),
          _interrupteur(
            Reglages.modeAdapte,
            Icons.favorite_border,
            'Mode adapté (fatigue, chaleur)',
            'Alerte plus tôt (${Reglages.seuilHautAdapte} % au lieu de 75 %), pause conseillée toutes les '
                '${Reglages.pauseToutesLesMinutes} minutes, avertissement s\'il fait plus de 25 °C. '
                'Pensé à partir de la rencontre avec une patiente atteinte de sclérose en plaques.',
          ),
          const SizedBox(height: 12),
          const Text(
            "Ces réglages sont des aides au confort : ils ne remplacent pas les conseils d'un médecin "
            "ou d'un kinésithérapeute. Athletix-Data n'est pas un dispositif médical.",
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
