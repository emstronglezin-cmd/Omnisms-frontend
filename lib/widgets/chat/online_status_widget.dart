import 'package:flutter/material.dart';

/// Widget pour afficher le statut en ligne d'un utilisateur
class OnlineStatusIndicator extends StatelessWidget {
  final bool isOnline;
  final double size;
  final bool showBorder;

  const OnlineStatusIndicator({
    super.key,
    required this.isOnline,
    this.size = 12,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? Colors.green : Colors.grey[400],
        border: showBorder
            ? Border.all(
                color: Colors.white,
                width: size * 0.15,
              )
            : null,
        boxShadow: isOnline
            ? [
                BoxShadow(
                  color: Colors.green.withOpacity(0.4),
                  blurRadius: size * 0.5,
                  spreadRadius: size * 0.1,
                ),
              ]
            : null,
      ),
    );
  }
}

/// Widget pour afficher le statut avec texte (En ligne / Hors ligne / Dernière connexion)
class OnlineStatusText extends StatelessWidget {
  final bool isOnline;
  final DateTime? lastSeen;
  final TextStyle? style;

  const OnlineStatusText({
    super.key,
    required this.isOnline,
    this.lastSeen,
    this.style,
  });

  String _getStatusText() {
    if (isOnline) {
      return 'En ligne';
    } else if (lastSeen != null) {
      final now = DateTime.now();
      final difference = now.difference(lastSeen!);
      
      if (difference.inMinutes < 1) {
        return 'À l\'instant';
      } else if (difference.inMinutes < 60) {
        return 'Il y a ${difference.inMinutes} min';
      } else if (difference.inHours < 24) {
        return 'Il y a ${difference.inHours}h';
      } else if (difference.inDays < 7) {
        return 'Il y a ${difference.inDays}j';
      } else {
        return 'Hors ligne';
      }
    }
    return 'Hors ligne';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _getStatusText(),
      style: style ??
          TextStyle(
            fontSize: 12,
            color: isOnline ? Colors.green : Colors.grey[600],
            fontWeight: isOnline ? FontWeight.w500 : FontWeight.normal,
          ),
    );
  }
}

/// Avatar avec indicateur de statut en ligne
class AvatarWithStatus extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final bool isOnline;
  final double size;
  final bool showStatusIndicator;

  const AvatarWithStatus({
    super.key,
    this.imageUrl,
    required this.name,
    required this.isOnline,
    this.size = 48,
    this.showStatusIndicator = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Avatar
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Color(0xFF667eea),
                  Color(0xFF764ba2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildInitialsAvatar();
                      },
                    ),
                  )
                : _buildInitialsAvatar(),
          ),
          
          // Online status indicator
          if (showStatusIndicator)
            Positioned(
              right: 0,
              bottom: 0,
              child: OnlineStatusIndicator(
                isOnline: isOnline,
                size: size * 0.25,
                showBorder: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInitialsAvatar() {
    final initials = name.isNotEmpty
        ? name.substring(0, 1).toUpperCase()
        : '?';
    
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Widget combiné pour l'en-tête de conversation avec avatar et statut
class ConversationHeader extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final bool isOnline;
  final DateTime? lastSeen;
  final VoidCallback? onTap;

  const ConversationHeader({
    super.key,
    this.imageUrl,
    required this.name,
    required this.isOnline,
    this.lastSeen,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          AvatarWithStatus(
            imageUrl: imageUrl,
            name: name,
            isOnline: isOnline,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                OnlineStatusText(
                  isOnline: isOnline,
                  lastSeen: lastSeen,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
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
