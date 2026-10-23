/// OmniSMS — Liquid Glass Widget Library
/// Inspired by iOS 26 / visionOS frosted glass effects
/// Adapts the PWA CSS glass tokens to Flutter widgets
///
/// Usage:
///   LiquidGlassCard(child: ...)
///   LiquidGlassAppBar(...)
///   OmniGradientText(text: 'OmniSMS')
///   OmniAvatarWidget(initials: 'AB', size: 44)

library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../providers/theme_provider.dart';
import 'avatar_image.dart';

// ─── LiquidGlassCard ──────────────────────────────────────────────────────────
/// Carte avec effet Liquid Glass (frosted glass + reflet)
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double blurStrength;
  final Color? background;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.blurStrength = 20.0,
    this.background,
    this.border,
    this.boxShadow,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    final bg = background ?? const Color(0xB80E1118); // glass-bg token

    Widget content = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurStrength, sigmaY: blurStrength),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: border ??
                Border.all(
                  color: OmniColors.glassBorder,
                  width: 1,
                ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.04),
                Colors.transparent,
              ],
              stops: const [0.0, 0.6],
            ),
            boxShadow: boxShadow ??
                [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.025),
                    blurRadius: 0,
                    offset: const Offset(0, 1),
                    spreadRadius: 0,
                  ),
                ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      content = GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap!();
        },
        child: content,
      );
    }

    return content;
  }
}

// ─── LiquidGlassAppBar ────────────────────────────────────────────────────────
/// AppBar avec effet Liquid Glass
class LiquidGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  const LiquidGlassAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: AppBar(
          backgroundColor: const Color(0xB80E1118),
          foregroundColor: OmniColors.textPrimary,
          title: Text(title),
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: leading,
          automaticallyImplyLeading: automaticallyImplyLeading,
          actions: actions,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: OmniColors.glassBorder, width: 1),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0x0AFFFFFF),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarBrightness: Brightness.dark,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
      ),
    );
  }
}

// ─── OmniGradientText ─────────────────────────────────────────────────────────
/// Texte avec gradient accent OmniSMS (cyan → deep blue)
class OmniGradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const OmniGradientText({
    super.key,
    required this.text,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => OmniColors.accentGradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        style: (style ?? const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))
            .copyWith(color: Colors.white),
      ),
    );
  }
}

// ─── OmniAvatarWidget ─────────────────────────────────────────────────────────
/// Avatar OmniSMS avec gradient ou image
class OmniAvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final String? initials;
  final double size;
  final bool showOnlineDot;

  const OmniAvatarWidget({
    super.key,
    this.imageUrl,
    this.initials,
    this.size = 44,
    this.showOnlineDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: UserAvatar(
        imageUrl: imageUrl,
        name: initials ?? '',
        size: size,
        fallback: _buildInitialsAvatar(),
      ),
    );

    if (showOnlineDot) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            bottom: 1,
            right: 1,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: OmniColors.success,
                shape: BoxShape.circle,
                border: Border.all(
                  color: OmniColors.bgPrimary,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return child;
  }

  Widget _buildInitialsAvatar() {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: OmniColors.accentGradient,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          (initials ?? '?').substring(0, initials != null && initials!.length > 1 ? 2 : 1).toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.36,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─── OmniGradientButton ───────────────────────────────────────────────────────
/// Bouton principal avec gradient cyan→blue OmniSMS
class OmniGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  const OmniGradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: onPressed == null ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: onPressed != null ? OmniColors.accentGradient : null,
          color: onPressed == null ? OmniColors.bgCard2 : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: onPressed != null
              ? [
                  BoxShadow(
                    color: OmniColors.accentGlow,
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed != null && !isLoading
                ? () {
                    HapticFeedback.lightImpact();
                    onPressed!();
                  }
                : null,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.01,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── OmniMessageBubble ────────────────────────────────────────────────────────
/// Bulle de message avec Liquid Glass (messages reçus)
class OmniMessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String? time;
  final String? senderName;

  const OmniMessageBubble({
    super.key,
    required this.text,
    required this.isMe,
    this.time,
    this.senderName,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: isMe ? _buildSentBubble() : _buildReceivedBubble(),
      ),
    );
  }

  Widget _buildSentBubble() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        gradient: OmniColors.accentGradient,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: OmniColors.accent.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(text,
              style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.45)),
          if (time != null) ...[
            const SizedBox(height: 3),
            Text(time!,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _buildReceivedBubble() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(4),
        bottomRight: Radius.circular(16),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xD01A1E2E),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(color: OmniColors.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (senderName != null) ...[
                Text(senderName!,
                    style: const TextStyle(
                        color: OmniColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
              ],
              Text(text,
                  style: const TextStyle(
                      color: OmniColors.textPrimary, fontSize: 14.5, height: 1.45)),
              if (time != null) ...[
                const SizedBox(height: 3),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(time!,
                      style: const TextStyle(
                          color: OmniColors.textSecondary, fontSize: 11)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
