import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/messaging_provider.dart';
import '../../theme/omni_design.dart';
import '../../widgets/common/avatar_image.dart';
import 'conversation_screen.dart';

/// ⚠️ Écran mobile (APK / IPA). La PWA conserve sa propre interface.

/// Liste des conversations — écran d'accueil de la messagerie.
///
/// Source des données : `GET /api/messages` via [MessagingProvider].
/// Chaque ligne affiche l'avatar, le nom, l'aperçu du dernier message,
/// l'horodatage et le compteur de non-lus. Un appui ouvre
/// [ConversationScreen] et marque la conversation comme lue.
///
/// Refonte 2026 : recherche locale, hiérarchie typographique, états de
/// chargement / vide / erreur soignés, aucune couleur codée en dur.
class MessagesListPage extends StatefulWidget {
  const MessagesListPage({super.key});

  @override
  State<MessagesListPage> createState() => _MessagesListPageState();
}

class _MessagesListPageState extends State<MessagesListPage> {
  final TextEditingController _rechercheController = TextEditingController();
  String _filtre = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MessagingProvider>().loadConversations();
      }
    });
  }

  @override
  void dispose() {
    _rechercheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);
    final estLarge = kIsWeb && MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: c.fond,
      body: SafeArea(
        child: Column(
          children: [
            _EnTete(
              controller: _rechercheController,
              onChanged: (v) => setState(() => _filtre = v.trim().toLowerCase()),
              onEffacer: () {
                _rechercheController.clear();
                setState(() => _filtre = '');
              },
            ),
            Expanded(
              child: Consumer<MessagingProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoadingConversations &&
                      provider.conversations.isEmpty) {
                    return const _ChargementListe();
                  }

                  if (provider.conversationsError != null &&
                      provider.conversations.isEmpty) {
                    return _ErreurListe(
                      message: provider.conversationsError!,
                      onReessayer: provider.loadConversations,
                    );
                  }

                  final conversations = _filtrer(provider.conversations);

                  if (provider.conversations.isEmpty) {
                    return _VideListe(onRafraichir: provider.loadConversations);
                  }

                  if (conversations.isEmpty) {
                    return _AucunResultat(filtre: _filtre);
                  }

                  return RefreshIndicator(
                    color: c.accent,
                    backgroundColor: c.surface,
                    onRefresh: () => provider.loadConversations(),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(
                        bottom: estLarge ? 24 : 8,
                        top: 4,
                      ),
                      itemCount: conversations.length,
                      itemBuilder: (context, index) => _LigneConversation(
                        conversation: conversations[index],
                        onTap: () => _ouvrirConversation(context, conversations[index]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Filtre local (nom, nom du groupe, aperçu du dernier message).
  List<ConversationModel> _filtrer(List<ConversationModel> source) {
    if (_filtre.isEmpty) return source;
    return source.where((conv) {
      final nom = conv.displayName.toLowerCase();
      final apercu = (conv.lastMessage ?? '').toLowerCase();
      return nom.contains(_filtre) || apercu.contains(_filtre);
    }).toList();
  }

  void _ouvrirConversation(BuildContext context, ConversationModel conv) {
    final provider = context.read<MessagingProvider>();
    provider.setActiveConversation(conv.id);
    provider.markConversationAsRead(conv.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          conversationId: conv.id,
          contactId: conv.otherUserId,
          contactName: conv.displayName,
          contactImageUrl: conv.otherUserPhotoUrl,
          isGroup: conv.isGroup,
        ),
      ),
    ).then((_) {
      // La conversation n'est plus active : on libère l'état.
      if (mounted) context.read<MessagingProvider>().setActiveConversation(null);
    });
  }
}

// ─── En-tête (titre, compteur, recherche) ──────────────────────────────────
class _EnTete extends StatelessWidget {
  const _EnTete({
    required this.controller,
    required this.onChanged,
    required this.onEffacer,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onEffacer;

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);

    return Container(
      decoration: BoxDecoration(
        color: c.fond,
        border: Border(bottom: BorderSide(color: c.contour)),
      ),
      padding: const EdgeInsets.fromLTRB(
        OmniEspace.l,
        OmniEspace.m,
        OmniEspace.l,
        OmniEspace.m,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Messages', style: OmniTypo.display.copyWith(color: c.texte)),
              ),
              Consumer<MessagingProvider>(
                builder: (context, provider, _) {
                  final nonLus = provider.conversations.fold<int>(
                    0,
                    (total, conv) => total + conv.unreadCount,
                  );
                  if (nonLus == 0) {
                    return IconButton(
                      onPressed: provider.isLoadingConversations
                          ? null
                          : provider.loadConversations,
                      icon: provider.isLoadingConversations
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: c.accent,
                              ),
                            )
                          : Icon(Icons.refresh_rounded, color: c.texteSecondaire),
                      tooltip: 'Actualiser',
                    );
                  }
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: c.accentDoux,
                          borderRadius: OmniRayon.pill,
                        ),
                        child: Text(
                          '$nonLus non lu${nonLus > 1 ? 's' : ''}',
                          style: OmniTypo.micro.copyWith(color: c.accent),
                        ),
                      ),
                      IconButton(
                        onPressed: provider.isLoadingConversations
                            ? null
                            : provider.loadConversations,
                        icon: Icon(Icons.refresh_rounded, color: c.texteSecondaire),
                        tooltip: 'Actualiser',
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: OmniEspace.m),
          // ── Recherche ──
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, valeur, _) {
              final actif = valeur.text.isNotEmpty;
              return TextField(
                controller: controller,
                onChanged: onChanged,
                style: OmniTypo.corps.copyWith(color: c.texte),
                cursorColor: c.accent,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Rechercher une conversation',
                  hintStyle: OmniTypo.corps.copyWith(color: c.texteEstompe),
                  filled: true,
                  fillColor: c.surfaceVariante,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: c.texteEstompe, size: 20),
                  suffixIcon: actif
                      ? IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: c.texteEstompe, size: 18),
                          onPressed: onEffacer,
                          tooltip: 'Effacer',
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: OmniRayon.champ,
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: OmniRayon.champ,
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: OmniRayon.champ,
                    borderSide: BorderSide(color: c.accent, width: 1.4),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Ligne de conversation ─────────────────────────────────────────────────
class _LigneConversation extends StatelessWidget {
  const _LigneConversation({required this.conversation, required this.onTap});

  final ConversationModel conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);
    final nonLu = conversation.unreadCount > 0;
    final apercu = conversation.lastMessage?.trim().isNotEmpty == true
        ? conversation.lastMessage!.trim()
        : 'Aucun message pour l’instant';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: c.accentDoux,
        highlightColor: c.accentDoux,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: OmniEspace.l,
            vertical: 11,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              UserAvatar(
                imageUrl: conversation.otherUserPhotoUrl,
                name: conversation.displayName,
                size: 56,
                isGroup: conversation.isGroup,
              ),
              const SizedBox(width: OmniEspace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OmniTypo.corpsGras.copyWith(
                              color: c.texte,
                              fontWeight:
                                  nonLu ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: OmniEspace.s),
                        Text(
                          _formatHorodatage(conversation.lastMessageTime),
                          style: OmniTypo.micro.copyWith(
                            color: nonLu ? c.accent : c.texteEstompe,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          _iconeCanal(conversation.channel),
                          size: 13,
                          color: nonLu ? c.accent : c.texteEstompe,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            apercu,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OmniTypo.secondaire.copyWith(
                              color: nonLu ? c.texte : c.texteSecondaire,
                              fontWeight:
                                  nonLu ? FontWeight.w500 : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (nonLu) ...[
                          const SizedBox(width: OmniEspace.s),
                          Container(
                            constraints: const BoxConstraints(minWidth: 22),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: c.accent,
                              borderRadius: OmniRayon.pill,
                            ),
                            child: Text(
                              conversation.unreadCount > 99
                                  ? '99+'
                                  : '${conversation.unreadCount}',
                              textAlign: TextAlign.center,
                              style: OmniTypo.micro.copyWith(
                                color: c.surAccent,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Icône du canal d'origine du dernier message (donnée réelle du backend).
  IconData _iconeCanal(String canal) {
    switch (canal.toLowerCase()) {
      case 'sms':
        return Icons.sms_rounded;
      case 'whatsapp':
        return Icons.chat_rounded;
      case 'email':
        return Icons.mail_rounded;
      default:
        return Icons.forum_rounded;
    }
  }

  /// « 14:32 » aujourd'hui, « Hier », le jour de la semaine, puis la date.
  String _formatHorodatage(DateTime? date) {
    if (date == null) return '';
    final maintenant = DateTime.now();
    final aujourdhui = DateTime(maintenant.year, maintenant.month, maintenant.day);
    final jourMessage = DateTime(date.year, date.month, date.day);
    final ecart = aujourdhui.difference(jourMessage).inDays;

    if (ecart == 0) {
      final h = date.hour.toString().padLeft(2, '0');
      final m = date.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    if (ecart == 1) return 'Hier';
    if (ecart < 7) {
      const jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      return jours[date.weekday - 1];
    }
    final j = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$j/$m/${date.year.toString().substring(2)}';
  }
}

// ─── Chargement : squelette shimmer léger ──────────────────────────────────
class _ChargementListe extends StatelessWidget {
  const _ChargementListe();

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);
    return ListView.builder(
      padding: const EdgeInsets.only(top: OmniEspace.s),
      itemCount: 7,
      itemBuilder: (context, index) => _LigneSquelette(
        couleurBase: c.surfaceVariante,
        couleurBrillance: c.contour.withValues(alpha: 0.5),
        delai: index * 90,
      ),
    );
  }
}

class _LigneSquelette extends StatefulWidget {
  const _LigneSquelette({
    required this.couleurBase,
    required this.couleurBrillance,
    required this.delai,
  });

  final Color couleurBase;
  final Color couleurBrillance;
  final int delai;

  @override
  State<_LigneSquelette> createState() => _LigneSqueletteState();
}

class _LigneSqueletteState extends State<_LigneSquelette>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controleur;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controleur = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0.35, end: 1).animate(
      CurvedAnimation(parent: _controleur, curve: Curves.easeInOut),
    );
    Future<void>.delayed(Duration(milliseconds: widget.delai), () {
      if (mounted) _controleur.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: OmniEspace.l,
        vertical: 11,
      ),
      child: Row(
        children: [
          FadeTransition(
            opacity: _animation,
            child: CircleAvatar(radius: 28, backgroundColor: widget.couleurBase),
          ),
          const SizedBox(width: OmniEspace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeTransition(
                  opacity: _animation,
                  child: Container(
                    height: 13,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: widget.couleurBase,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                FadeTransition(
                  opacity: _animation,
                  child: Container(
                    height: 11,
                    width: MediaQuery.of(context).size.width * 0.55,
                    decoration: BoxDecoration(
                      color: widget.couleurBrillance,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Aucun résultat de recherche ───────────────────────────────────────────
class _AucunResultat extends StatelessWidget {
  const _AucunResultat({required this.filtre});

  final String filtre;

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(OmniEspace.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 52, color: c.texteEstompe),
            const SizedBox(height: OmniEspace.l),
            Text(
              OmniEtats.aucunResultat,
              style: OmniTypo.sousTitre.copyWith(color: c.texte),
            ),
            const SizedBox(height: OmniEspace.s),
            Text(
              'Aucune conversation ne contient « $filtre ».',
              textAlign: TextAlign.center,
              style: OmniTypo.secondaire.copyWith(color: c.texteSecondaire),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── État vide ─────────────────────────────────────────────────────────────
class _VideListe extends StatelessWidget {
  const _VideListe({required this.onRafraichir});

  final Future<void> Function() onRafraichir;

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(OmniEspace.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: c.accentDoux,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.forum_rounded, size: 44, color: c.accent),
            ),
            const SizedBox(height: OmniEspace.xl),
            Text(
              'Aucune conversation',
              style: OmniTypo.sousTitre.copyWith(color: c.texte),
            ),
            const SizedBox(height: OmniEspace.s),
            Text(
              'Vos échanges apparaîtront ici dès qu’un message '
              'sera envoyé ou reçu.',
              textAlign: TextAlign.center,
              style: OmniTypo.secondaire.copyWith(color: c.texteSecondaire),
            ),
            const SizedBox(height: OmniEspace.xxl),
            OutlinedButton.icon(
              onPressed: onRafraichir,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Actualiser'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Erreur ────────────────────────────────────────────────────────────────
class _ErreurListe extends StatelessWidget {
  const _ErreurListe({required this.message, required this.onReessayer});

  final String message;
  final Future<void> Function() onReessayer;

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(OmniEspace.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: OmniPalette.erreur.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 44, color: OmniPalette.erreur),
            ),
            const SizedBox(height: OmniEspace.xl),
            Text(
              'Impossible de charger les conversations',
              textAlign: TextAlign.center,
              style: OmniTypo.sousTitre.copyWith(color: c.texte),
            ),
            const SizedBox(height: OmniEspace.s),
            Text(
              message,
              textAlign: TextAlign.center,
              style: OmniTypo.secondaire.copyWith(color: c.texteSecondaire),
            ),
            const SizedBox(height: OmniEspace.xxl),
            FilledButton.icon(
              onPressed: onReessayer,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(OmniEtats.reessayer),
            ),
          ],
        ),
      ),
    );
  }
}
