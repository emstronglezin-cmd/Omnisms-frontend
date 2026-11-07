import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/gateway_service.dart';

/// Écran « Passerelle SMS ».
///
/// Il montre l'état **réel** du service tel que le backend le publie. Rien
/// n'y est simulé : la passerelle est le service INfiniReach, piloté par le
/// serveur via un appareil Android relais. L'application n'envoie donc pas
/// les SMS par la SIM du téléphone de l'utilisateur — ce choix est affiché
/// clairement, avec ce qu'il reste à faire côté serveur.
class GatewayScreen extends StatefulWidget {
  const GatewayScreen({super.key});

  @override
  State<GatewayScreen> createState() => _GatewayScreenState();
}

class _GatewayScreenState extends State<GatewayScreen> {
  EtatPasserelleResultat? _etat;
  bool _chargement = false;

  @override
  void initState() {
    super.initState();
    _verifier();
  }

  Future<void> _verifier() async {
    if (_chargement) return;
    setState(() => _chargement = true);
    final etat = await GatewayService.instance.recupererEtat();
    if (!mounted) return;
    setState(() {
      _etat = etat;
      _chargement = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final etat = _etat;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Passerelle SMS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Revérifier',
            onPressed: _chargement ? null : _verifier,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _carteEtat(etat),
          const SizedBox(height: 16),
          _carteFonctionnement(),
          const SizedBox(height: 16),
          _carteEtatsAppareil(),
          if (etat != null && etat.etapesConfiguration.isNotEmpty) ...[
            const SizedBox(height: 16),
            _carteConfigurationServeur(etat.etapesConfiguration),
          ],
        ],
      ),
    );
  }

  Widget _carteEtat(EtatPasserelleResultat? etat) {
    if (_chargement && etat == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (etat == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Aucune vérification effectuée.'),
        ),
      );
    }

    final (couleur, icone) = switch (etat.etat) {
      EtatPasserelle.operationnelle => (Colors.green, Icons.check_circle),
      EtatPasserelle.nonConfiguree => (Colors.orange, Icons.build),
      EtatPasserelle.inactive => (Colors.orange, Icons.pause_circle),
      EtatPasserelle.injoignable => (Colors.red, Icons.cloud_off),
      EtatPasserelle.inconnue => (Colors.grey, Icons.help_outline),
    };

    final heure = DateFormat('dd/MM/yyyy à HH:mm').format(etat.horodatage);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, color: couleur),
                const SizedBox(width: 10),
                Text(
                  etat.libelle,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (etat.service != null) _ligne('Service', etat.service!),
            if (etat.implementation != null)
              _ligne('Fournisseur', etat.implementation!),
            if (etat.transport != null) _ligne('Transport', etat.transport!),
            if (etat.configuree != null)
              _ligne('Configurée', etat.configuree! ? 'oui' : 'non'),
            if (etat.active != null)
              _ligne('Transport actif', etat.active! ? 'oui' : 'non'),
            _ligne('Vérifié le', heure),
            if (etat.message != null) ...[
              const SizedBox(height: 12),
              Text(
                etat.message!,
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _ligne(String titre, String valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(titre, style: TextStyle(color: Colors.grey[600])),
          ),
          Expanded(child: Text(valeur)),
        ],
      ),
    );
  }

  Widget _carteFonctionnement() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comment fonctionne l’envoi',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Les SMS sont acheminés par le service INfiniReach, via un '
              'appareil Android relais enregistré auprès du compte, puis '
              'pilotés par le serveur OmniSMS. L’application de '
              'l’utilisateur n’envoie donc pas les messages par sa propre '
              'carte SIM : elle affiche l’état de la passerelle et signale '
              'les pannes.',
            ),
            const SizedBox(height: 8),
            Text(
              'Activer ou désactiver la passerelle se fait côté serveur '
              '(variable INFINIREACH_ENABLED). Aucun interrupteur factice '
              'n’est présenté dans l’application.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _carteEtatsAppareil() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'État de l’appareil relais',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hors ligne, éteint, sans crédit ou sans SIM : ces états ne '
              'sont pas encore publiés par le serveur. Ils seront affichés '
              'ici dès que le backend les exposera, plutôt que d’être '
              'devinés ou affichés à tort.',
            ),
            const SizedBox(height: 8),
            Text(
              'À faire côté serveur : publier l’état de l’appareil relais '
              '(dernière activité, solde, présence de SIM) dans le endpoint '
              'de statut.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _carteConfigurationServeur(List<String> etapes) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Étapes transmises par le serveur',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...etapes.map((etape) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• $etape'),
                )),
          ],
        ),
      ),
    );
  }
}
