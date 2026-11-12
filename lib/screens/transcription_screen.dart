import 'package:flutter/material.dart';

import '../services/transcription_service.dart';
import '../theme/omni_design.dart';
import '../theme/omni_motion.dart';
import '../widgets/common/etats_v3.dart';

/// Transcription audio.
///
/// L'enregistrement est désactivé (voir le commentaire ci-dessous) : l'écran
/// n'a donc rien à afficher. C'est précisément le cas où un écran vide doit
/// **expliquer** au lieu de laisser un texte brut centré — sinon
/// l'utilisateur croit à un dysfonctionnement.
class TranscriptionScreen extends StatefulWidget {
  const TranscriptionScreen({Key? key}) : super(key: key);

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> {
  // Fonctionnalité d'enregistrement temporairement désactivée en raison de
  // problèmes de dépendances. La transcription reste affichée si elle a pu
  // être produite par un autre chemin.
  String? _transcription;

  Future<void> _transcribeAudio(String filePath) async {
    final transcription = await TranscriptionService().transcribeAudio(
      filePath,
    );
    if (!mounted) return;
    setState(() {
      _transcription = transcription;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Transcription audio',
          style: OmniTypo.sousTitre.copyWith(color: c.texte),
        ),
      ),
      body: _transcription == null
          ? const OmniEtatVide(
              icone: Icons.mic_off_rounded,
              titre: 'Enregistrement désactivé',
              message:
                  'La transcription audio n’est pas disponible pour le moment. '
                  'Le reste de l’application fonctionne normalement.',
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(OmniEspace.l),
              child: OmniApparition(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(OmniEspace.l),
                  decoration: BoxDecoration(
                    color: c.surfaceVariante,
                    borderRadius: OmniRayon.carte,
                    border: Border.all(color: c.contour),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transcription',
                        style: OmniTypo.etiquette.copyWith(
                          color: c.texteSecondaire,
                        ),
                      ),
                      const SizedBox(height: OmniEspace.s),
                      Text(
                        _transcription!,
                        style: OmniTypo.corps.copyWith(color: c.texte),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
