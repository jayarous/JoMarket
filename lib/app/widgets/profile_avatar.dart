import 'package:flutter/material.dart';

/// A small reusable avatar that prefers a network avatar URL but falls back
/// to rendering the initial letter (or an icon) when loading fails or when
/// no URL is available. Uses [errorBuilder] to avoid image exceptions.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    required this.size,
    this.avatarUrl,
    this.initial,
    this.backgroundColor,
    super.key,
  });

  final double size;
  final String? avatarUrl;
  final String? initial;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.primary;

    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: bg.withValues(alpha: 0.04),
        foregroundImage: NetworkImage(avatarUrl!),
        onForegroundImageError: (_, __) {},
        child: Text(
          initial ?? '',
          style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
        ),
      );
    }

    final letter = (initial ?? '').isNotEmpty ? initial! : '?';
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: bg,
      child: Text(
        letter,
        style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
      ),
    );
  }
}
