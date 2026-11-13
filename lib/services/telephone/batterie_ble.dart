import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Service Bluetooth standard « Battery » (0x180F, caractéristique 0x2A19 = % de 0 à 100),
/// proposé par la plupart des ceintures cardio et des montres.
class BatterieBle {
  BatterieBle._();

  static const String uuidService = '0000180f-0000-1000-8000-00805f9b34fb';
  static const String uuidNiveau = '00002a19-0000-1000-8000-00805f9b34fb';

  /// Lit la valeur de 0x2A19 ; null si vide ou hors de 0–100.
  static int? lire(List<int> octets) {
    if (octets.isEmpty) return null;
    final v = octets[0];
    return v <= 100 ? v : null;
  }

  /// Lit le niveau puis suit ses changements ; renvoie l'abonnement (null si l'appareil n'a pas ce service).
  static Future<StreamSubscription<List<int>>?> suivre(List<BluetoothService> services, ValueNotifier<int?> cible) async {
    for (final s in services) {
      if (s.uuid != Guid(uuidService)) continue;
      for (final c in s.characteristics) {
        if (c.uuid != Guid(uuidNiveau)) continue;
        final abo = c.onValueReceived.listen((o) {
          final v = lire(o);
          if (v != null) cible.value = v;
        });
        try {
          final v = lire(await c.read());
          if (v != null) cible.value = v;
        } catch (_) {}
        try {
          await c.setNotifyValue(true);
        } catch (_) {/* certains appareils n'acceptent que la lecture */}
        return abo;
      }
    }
    return null;
  }
}

/// Icône de batterie par paliers (inconnue, alerte ≤ 10 %, puis 0 à 6 barres, pleine).
IconData iconeBatterie(int? niveau) {
  if (niveau == null) return Icons.battery_unknown;
  if (niveau <= 10) return Icons.battery_alert;
  if (niveau >= 95) return Icons.battery_full;
  const paliers = [
    Icons.battery_0_bar, Icons.battery_1_bar, Icons.battery_2_bar, Icons.battery_3_bar,
    Icons.battery_4_bar, Icons.battery_5_bar, Icons.battery_6_bar,
  ];
  return paliers[(niveau * 7 ~/ 100).clamp(0, 6)];
}

/// Couleur selon le niveau : rouge ≤ 15 %, orange ≤ 30 %, vert au-dessus.
Color couleurBatterie(int? niveau) {
  if (niveau == null) return Colors.white38;
  if (niveau <= 15) return Colors.redAccent;
  if (niveau <= 30) return Colors.orangeAccent;
  return Colors.lightGreenAccent;
}

/// Pastille « 🔋 72 % » réutilisée dans les écrans (brassard, montre, ceinture).
class PastilleBatterie extends StatelessWidget {
  const PastilleBatterie(this.niveau, {super.key, this.libelle});
  final int? niveau;
  final String? libelle;

  @override
  Widget build(BuildContext context) {
    final c = couleurBatterie(niveau);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withValues(alpha: 0.5))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(iconeBatterie(niveau), size: 15, color: c),
        const SizedBox(width: 4),
        Text('${libelle != null ? '$libelle ' : ''}${niveau == null ? '—' : '$niveau %'}', style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
