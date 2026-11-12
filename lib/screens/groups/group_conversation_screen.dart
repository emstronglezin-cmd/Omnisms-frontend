import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/omni_design.dart';
import '../../theme/omni_motion.dart';
import '../../utils/user_messages.dart';
import '../../widgets/common/etats_v3.dart';
import '../../widgets/common/avatar_image.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/groups_service.dart';

class GroupConversationScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupConversationScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupConversationScreen> createState() => _GroupConversationScreenState();
}

class _GroupConversationScreenState extends State<GroupConversationScreen> {
  final GroupsService _groupsService = GroupsService();
  final AuthService _authService = AuthService();

  /// Utilisé pour ouvrir le clavier depuis l'état vide : « Écrire » doit
  /// faire exactement ce que son libellé promet, pas seulement décorer.
  final FocusNode _focusMessage = FocusNode();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<MessageModel> _messages = [];
  final Map<String, String> _memberNames = {};
  /// Photos des membres, telles que renvoyées par le serveur (même contrat
  /// que les utilisateurs : `avatar`, souvent une URI de données).
  final Map<String, String> _memberPhotos = {};
  Timer? _pollTimer;
  String? _currentUserId;
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  Future<void> _initScreen() async {
    _currentUserId = await _authService.getUserId();
    await _loadMembers();
    await _loadMessages(showLoader: true);
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _loadMessages();
    });
  }

  Future<void> _loadMembers() async {
    final members = await _groupsService.getGroupMembers(widget.groupId);
    if (!mounted) return;
    setState(() {
      for (final m in members) {
        final uid = m['uid']?.toString();
        final name = m['name']?.toString();
        if (uid != null && name != null && name.isNotEmpty) {
          _memberNames[uid] = name;
        }
        // Le backend renvoie l'avatar du membre (groups.js) : on le garde
        // pour l'afficher, sans jamais fabriquer d'URL.
        final avatar = m['avatar']?.toString();
        if (uid != null && avatar != null && avatar.isNotEmpty) {
          _memberPhotos[uid] = avatar;
        }
      }
    });
  }

  Future<void> _loadMessages({bool showLoader = false}) async {
    try {
      final messages =
          await _groupsService.getGroupMessages(widget.groupId);
      if (!mounted) return;

      setState(() {
        _error = null;
        _isLoading = false;
        final existingIds = _messages.map((m) => m.id).toSet();
        _messages.addAll(
          messages.where((m) => !existingIds.contains(m.id)),
        );
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      if (showLoader) {
        setState(() {
          _isLoading = false;
          _error = 'Impossible de charger les messages';
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final content = _textController.text.trim();
    if (content.isEmpty || _isSending) return;

    _textController.clear();
    final currentUserId = _currentUserId ?? '';

    final optimistic = MessageModel(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.groupId,
      senderId: currentUserId,
      type: MessageType.text,
      content: content,
      status: MessageStatus.sending,
      timestamp: DateTime.now(),
      isMe: true,
    );

    setState(() {
      _isSending = true;
      _messages.add(optimistic);
    });
    _scrollToBottom();

    final sent = await _groupsService.sendGroupMessage(
      groupId: widget.groupId,
      content: content,
    );

    if (!mounted) return;
    setState(() {
      _isSending = false;
      final idx = _messages.indexWhere((m) => m.id == optimistic.id);
      if (sent != null) {
        final confirmed = sent.copyWith(
          isMe: sent.senderId == currentUserId || sent.senderId.isEmpty,
          senderId: sent.senderId.isEmpty ? currentUserId : sent.senderId,
          conversationId:
              sent.conversationId.isEmpty ? widget.groupId : sent.conversationId,
        );
        if (idx >= 0) {
          _messages[idx] = confirmed;
        } else {
          _messages.add(confirmed);
        }
      } else if (idx >= 0) {
        _messages[idx] = optimistic.copyWith(status: MessageStatus.failed);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Échec de l'envoi du message"),
            backgroundColor: OmniPalette.erreur,
          ),
        );
      }
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _focusMessage.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.groupName,
              style: OmniTypo.sousTitre.copyWith(
                color: OmniCouleurs.of(context).texte,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_memberNames.length} membres',
              style: OmniTypo.micro.copyWith(
                color: OmniCouleurs.of(context).texteSecondaire,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Appel de groupe (bientôt disponible)')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showGroupInfo(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const OmniEtatChargement(nombreLignes: 6);
    }

    if (_error != null) {
      return OmniEtatErreur(
        message: userMessage(_error),
        onReessayer: () {
          setState(() => _isLoading = true);
          _loadMessages(showLoader: true);
        },
      );
    }

    if (_messages.isEmpty) {
      return OmniEtatVide(
        icone: Icons.forum_rounded,
        titre: 'Messages de groupe',
        message: 'Envoyez votre premier message à ce groupe.',
        libelleAction: 'Écrire un message',
        onAction: () => _focusMessage.requestFocus(),
      );
    }

    // L'apparition est appliquée à la liste entière, une seule fois, et non
    // à chaque bulle : dans une conversation, les bulles sont recréées à
    // chaque défilement, et une animation par bulle se rejouerait sans fin
    // au moindre geste.
    return OmniApparition(
      duree: OmniMouvement.entree,
      child: RefreshIndicator(
      onRefresh: () => _loadMessages(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          final isMe = message.isMe ||
              message.senderId == _currentUserId;
          final senderName =
              _memberNames[message.senderId] ?? message.senderName;
          return _buildBubble(message, isMe, senderName);
        },
      ),
      ),
    );
  }

  Widget _buildBubble(MessageModel message, bool isMe, String? senderName) {
    final alignment =
        isMe ? Alignment.centerRight : Alignment.centerLeft;
    final c = OmniCouleurs.of(context);
    final bubbleColor = isMe ? c.bulleSortante : c.bulleEntrante;
    final textColor = isMe ? c.bulleSortanteTexte : c.bulleEntranteTexte;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!isMe && senderName != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 2),
              child: Text(
                senderName,
                style: OmniTypo.etiquette.copyWith(
                  color: OmniCouleurs.of(context).accent,
                ),
              ),
            ),
          Align(
            alignment: alignment,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: isMe
                    ? OmniRayon.bulleSortante
                    : OmniRayon.bulleEntrante,
              ),
              child: Text(
                message.content ?? '',
                style: OmniTypo.corps.copyWith(color: textColor),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 12, right: 12),
            child: Text(
              _formatTime(message.timestamp),
              style: OmniTypo.micro.copyWith(
                color: OmniCouleurs.of(context).texteEstompe,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime ts) {
    return '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildInputBar() {
    final c = OmniCouleurs.of(context);

    return Container(
      padding: const EdgeInsets.all(OmniEspace.s),
      decoration: BoxDecoration(
        color: c.fond,
        border: Border(top: BorderSide(color: c.contour)),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: c.surfaceVariante,
                  borderRadius: OmniRayon.champ,
                  border: Border.all(color: c.contour),
                ),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusMessage,
                  onSubmitted: (_) => _sendMessage(),
                  maxLines: 5,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Message…',
                    hintStyle: OmniTypo.corps.copyWith(color: c.texteEstompe),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: OmniEspace.m,
                      vertical: OmniEspace.m,
                    ),
                  ),
                  style: OmniTypo.corps.copyWith(color: c.texte),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ),
            const SizedBox(width: OmniEspace.s),
            // Le bouton montre l'état d'envoi : un envoi en cours silencieux
            // pousse l'utilisateur à renvoyer, donc à créer un doublon.
            OmniPression(
              borderRadius: OmniRayon.pill,
              onTap: _isSending ? null : _sendMessage,
              actif: !_isSending,
              child: AnimatedContainer(
                duration: OmniMouvement.rapide,
                curve: OmniMouvement.standard,
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: c.degradeAccent,
                  shape: BoxShape.circle,
                ),
                child: AnimatedSwitcher(
                  duration: OmniMouvement.rapide,
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          key: const ValueKey<String>('envoyer'),
                          color: c.surAccent,
                          size: 22,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        final entries = _memberNames.entries.toList();
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                widget.groupName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '${entries.length} membres',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const Divider(height: 24),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Chargement des membres...'),
                )
              else
                ...entries.map(
                  (e) => ListTile(
                    leading: UserAvatar(
                      imageUrl: _memberPhotos[e.key],
                      name: e.value,
                      size: 36,
                      fallback: Text(e.value.isNotEmpty
                          ? e.value[0].toUpperCase()
                          : '?'),
                    ),
                    title: Text(e.value),
                    dense: true,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
