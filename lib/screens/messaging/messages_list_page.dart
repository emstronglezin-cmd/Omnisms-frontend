import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/messaging_provider.dart';
import '../../models/models.dart';
import 'conversation_screen.dart';
import '../../widgets/common/avatar_image.dart';

/// MessagesListPage — WhatsApp-style conversations list.
///
/// Loaded from GET /api/messages via MessagingProvider.
/// Each tile shows: avatar, name, last message preview, timestamp, unread badge.
/// Tapping opens ConversationScreen(conversationId, contactName).
class MessagesListPage extends StatefulWidget {
  const MessagesListPage({super.key});

  @override
  State<MessagesListPage> createState() => _MessagesListPageState();
}

class _MessagesListPageState extends State<MessagesListPage> {
  @override
  void initState() {
    super.initState();
    // Load conversations when screen first appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MessagingProvider>().loadConversations();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb && MediaQuery.of(context).size.width >= 768;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isWeb ? const Color(0xFF080c14) : theme.scaffoldBackgroundColor,
      appBar: isWeb
          ? null
          : AppBar(
              elevation: 0,
              backgroundColor: theme.scaffoldBackgroundColor,
              title: const Text(
                'Messages',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    // TODO: search conversations
                  },
                  tooltip: 'Rechercher',
                ),
                Consumer<MessagingProvider>(
                  builder: (ctx, provider, _) => IconButton(
                    icon: provider.isLoadingConversations
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    onPressed: provider.isLoadingConversations
                        ? null
                        : () => provider.loadConversations(),
                    tooltip: 'Actualiser',
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
      body: Consumer<MessagingProvider>(
        builder: (context, provider, _) {
          // Loading state
          if (provider.isLoadingConversations &&
              provider.conversations.isEmpty) {
            return _buildLoadingView(isDark);
          }

          // Error state with no conversations
          if (provider.conversationsError != null &&
              provider.conversations.isEmpty) {
            return _buildErrorView(provider, isDark);
          }

          // Empty state
          if (provider.conversations.isEmpty) {
            return _buildEmptyView(isDark);
          }

          // Conversations list
          return RefreshIndicator(
            onRefresh: () => provider.loadConversations(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: provider.conversations.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 76,
                color: isDark
                    ? Colors.white10
                    : Colors.grey.withOpacity(0.2),
              ),
              itemBuilder: (context, index) {
                final conv = provider.conversations[index];
                return _ConversationTile(
                  conversation: conv,
                  isDark: isDark,
                  onTap: () => _openConversation(context, conv),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _openConversation(BuildContext context, ConversationModel conv) {
    context.read<MessagingProvider>().setActiveConversation(conv.id);
    context.read<MessagingProvider>().markConversationAsRead(conv.id);
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
      // Clear active conversation when returning
      context.read<MessagingProvider>().setActiveConversation(null);
    });
  }

  Widget _buildLoadingView(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: isDark ? const Color(0xFF00D4FF) : null,
          ),
          const SizedBox(height: 24),
          Text(
            'Chargement des messages...',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? const Color(0xFF6b7a96) : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(MessagingProvider provider, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 72,
              color: isDark ? Colors.red[300] : Colors.red[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Impossible de charger les messages',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFe8edf5) : null,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              provider.conversationsError ?? 'Erreur réseau',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? const Color(0xFF6b7a96) : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => provider.loadConversations(),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF00D4FF).withOpacity(0.08)
                    : Colors.blue.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 72,
                color: isDark
                    ? const Color(0xFF00D4FF).withOpacity(0.6)
                    : Colors.blue[300],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Aucune conversation',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFe8edf5) : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Ajoutez un contact et envoyez\nvotre premier message.',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? const Color(0xFF6b7a96) : Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Conversation Tile ─────────────────────────────────────────────────────────
class _ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final bool isDark;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;
    final name = conversation.displayName;
    final lastMsg = conversation.lastMessage ?? '';
    final timeStr = _formatTime(conversation.lastMessageTime);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            _ConversationAvatar(
              name: name,
              imageUrl: conversation.otherUserPhotoUrl,
              isGroup: conversation.isGroup,
              isDark: isDark,
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: hasUnread
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: isDark
                                ? const Color(0xFFe8edf5)
                                : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timeStr.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: hasUnread
                                ? (isDark
                                    ? const Color(0xFF00D4FF)
                                    : Theme.of(context).primaryColor)
                                : (isDark
                                    ? const Color(0xFF6b7a96)
                                    : Colors.grey[500]),
                            fontWeight: hasUnread
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMsg.isNotEmpty
                              ? lastMsg
                              : 'Démarrer une conversation',
                          style: TextStyle(
                            fontSize: 14,
                            color: hasUnread
                                ? (isDark
                                    ? const Color(0xFFe8edf5)
                                    : Colors.black87)
                                : (isDark
                                    ? const Color(0xFF6b7a96)
                                    : Colors.grey[600]),
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        _UnreadBadge(count: conversation.unreadCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final local = dt.toLocal();

    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      // Today — show time
      final h = local.hour.toString().padLeft(2, '0');
      final m = local.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } else if (now.difference(local).inDays < 7) {
      // Within 7 days — show day name
      const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      return days[local.weekday - 1];
    } else {
      // Older — show date
      final d = local.day.toString().padLeft(2, '0');
      final mo = local.month.toString().padLeft(2, '0');
      return '$d/$mo';
    }
  }
}

// ── Avatar Widget ─────────────────────────────────────────────────────────────
class _ConversationAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final bool isGroup;
  final bool isDark;

  const _ConversationAvatar({
    required this.name,
    this.imageUrl,
    required this.isGroup,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty
        ? (name.trim().split(' ').length >= 2
            ? '${name.trim().split(' ')[0][0]}${name.trim().split(' ')[1][0]}'
                .toUpperCase()
            : name[0].toUpperCase())
        : '?';

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return UserAvatar(
        imageUrl: imageUrl,
        name: name,
        size: 56,
        isGroup: isGroup,
        fallback: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.transparent,
          child: isGroup
              ? Icon(
                  Icons.group,
                  size: 26,
                  color: isDark ? const Color(0xFF00D4FF) : Colors.blue,
                )
              : Text(
                  initials,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF00D4FF) : Colors.green[700],
                  ),
                ),
        ),
      );
    }

    return CircleAvatar(
      radius: 28,
      backgroundColor: isGroup
          ? (isDark
              ? const Color(0xFF1a3a5c)
              : Colors.blue.withOpacity(0.15))
          : (isDark
              ? const Color(0xFF1a4a3a)
              : Colors.green.withOpacity(0.15)),
      child: isGroup
          ? Icon(
              Icons.group,
              size: 26,
              color: isDark ? const Color(0xFF00D4FF) : Colors.blue,
            )
          : Text(
              initials,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFF00D4FF) : Colors.green[700],
              ),
            ),
    );
  }
}

// ── Unread Badge ──────────────────────────────────────────────────────────────
class _UnreadBadge extends StatelessWidget {
  final int count;
  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : count.toString();
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
