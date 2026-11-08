import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/presence_service.dart';

/// ⚠️ Mobile uniquement (APK / IPA). Ne modifie pas la PWA.

/// Relie le cycle de vie de l'application au suivi de présence.
///
/// Règle : **la présence n'est jamais déduite de l'état de notre propre
/// application**. Passer en arrière-plan ne rend personne « hors ligne », et
/// revenir au premier plan ne rend personne « en ligne ». Ces transitions
/// pilotent uniquement la *fréquence d'interrogation du backend* :
///
///   • arrière-plan → le rafraîchissement périodique est suspendu
///     (économie de batterie), l'état confirmé reste affiché ;
///   • premier plan → le suivi redémarre et une resynchronisation immédiate
///     est demandée au backend, sans attendre le prochain tour de timer.
class PresenceCycleDeVie extends StatefulWidget {
  const PresenceCycleDeVie({super.key, required this.child});

  final Widget child;

  @override
  State<PresenceCycleDeVie> createState() => _PresenceCycleDeVieState();
}

class _PresenceCycleDeVieState extends State<PresenceCycleDeVie>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    final presence = context.read<PresenceService>();

    switch (etat) {
      case AppLifecycleState.resumed:
        // Retour au premier plan : resynchronisation immédiate.
        unawaited(presence.reprendre());
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Arrière-plan : on cesse d'interroger, sans rien conclure.
        presence.mettreEnPause();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // Transitoire (appel entrant, partage) : aucun changement.
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
