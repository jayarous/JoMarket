part of 'package:jo_market/app/role_aware_home.dart';

class ShopperDashboard extends StatefulWidget {
  const ShopperDashboard({
    required this.profile,
    required this.repository,
    required this.profileRepository,
    required this.onReloadRequested,
    required this.roles,
    required this.activeRole,
    required this.onRoleChanged,
    this.userEmail,
    super.key,
  });

  final UserProfile profile;
  final DashboardRepository repository;
  final ProfileRepository profileRepository;
  final VoidCallback onReloadRequested;
  final List<RoleAssignment> roles;
  final RoleAssignment activeRole;
  final ValueChanged<RoleAssignment> onRoleChanged;
  final String? userEmail;

  @override
  State<ShopperDashboard> createState() => _ShopperDashboardState();
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.profile,
    required this.notificationCount,
    required this.onNotificationsPressed,
    this.userEmail,
  });

  final UserProfile profile;
  final int notificationCount;
  final String? userEmail;
  final VoidCallback onNotificationsPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmedName = profile.fullName?.trim();
    final fallbackSource = (trimmedName != null && trimmedName.isNotEmpty)
        ? trimmedName
        : (userEmail?.trim().isNotEmpty == true
              ? userEmail!.trim()
              : profile.userId);
    final greetingName = (fallbackSource.isNotEmpty ? fallbackSource : 'friend')
        .split(' ')
        .first;
    final avatarLetter = fallbackSource.isEmpty
        ? '?'
        : fallbackSource.substring(0, 1).toUpperCase();

    return Row(
      children: [
        ProfileAvatar(
          size: 56,
          avatarUrl: profile.avatarUrl,
          initial: avatarLetter,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi $greetingName!',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ready to continue shopping today?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Notifications',
              onPressed: onNotificationsPressed,
              icon: Icon(
                Icons.notifications_active_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (notificationCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${notificationCount.clamp(1, 9)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.focusNode,
    required this.isFocused,
    required this.controller,
    required this.onClear,
    this.onSubmitted,
    this.onAdvancedSearch,
  });

  final FocusNode focusNode;
  final bool isFocused;
  final TextEditingController controller;
  final VoidCallback onClear;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onAdvancedSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surface;
    final hasQuery = controller.text.trim().isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          width: 1.2,
          color: isFocused
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
        ),
        boxShadow: [
          if (isFocused)
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.25),
              blurRadius: 22,
              offset: const Offset(0, 6),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: 'Search products, brands...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: SizedBox(
            width: hasQuery ? 132 : 92,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasQuery) ...[
                  _SuffixIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Clear search',
                    onTap: onClear,
                  ),
                  const SizedBox(width: 4),
                ],
                _SuffixIconButton(
                  icon: Icons.tune_rounded,
                  tooltip: 'Advanced search',
                  onTap: onAdvancedSearch,
                ),
                const SizedBox(width: 4),
                const _SuffixIconButton(
                  icon: Icons.qr_code_scanner_rounded,
                  tooltip: 'Scan barcode',
                ),
              ],
            ),
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _SuffixIconButton extends StatelessWidget {
  const _SuffixIconButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        radius: 20,
        onTap: onTap ?? () {},
        child: Icon(icon, size: 20),
      ),
    );
  }
}

class _InlineNotificationBanner extends StatelessWidget {
  const _InlineNotificationBanner({
    required this.message,
    required this.onClose,
  });

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dismissible(
      key: const ValueKey('cart-notification'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onClose(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.shopping_bag, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet({
    required this.notifications,
    required this.isLoading,
    required this.readNotificationIds,
    this.errorMessage,
    this.onNotificationTap,
    this.onRefresh,
    this.onRetry,
    this.onMarkAllRead,
  });

  final List<UserNotification> notifications;
  final bool isLoading;
  final Set<String> readNotificationIds;
  final String? errorMessage;
  final ValueChanged<UserNotification>? onNotificationTap;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onRetry;
  final VoidCallback? onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUnread = notifications.any(
      (notification) => !readNotificationIds.contains(notification.id),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Text(
                'Notifications',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (hasUnread && onMarkAllRead != null)
                TextButton(
                  onPressed: onMarkAllRead,
                  child: const Text('Mark all read'),
                ),
            ],
          ),
        ),
        if (isLoading && notifications.isNotEmpty)
          const LinearProgressIndicator(minHeight: 2),
        if (errorMessage != null && notifications.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _NotificationErrorBanner(
              message: errorMessage!,
              onRetry: onRetry,
            ),
          ),
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (isLoading && notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null && notifications.isEmpty) {
      return _NotificationsEmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Unable to load notifications',
        message: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onAction: onRetry,
      );
    }

    if (notifications.isEmpty) {
      return const _NotificationsEmptyState(
        icon: Icons.notifications_off_rounded,
        title: 'No notifications yet',
        message: 'You\'ll see order updates and helpful tips here.',
      );
    }

    final listView = ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: notifications.length,
      physics: const AlwaysScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        final isUnread = !readNotificationIds.contains(notification.id);
        return _NotificationTile(
          notification: notification,
          isUnread: isUnread,
          onTap: () => onNotificationTap?.call(notification),
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 12),
    );

    if (onRefresh != null) {
      return RefreshIndicator(
        onRefresh: onRefresh!,
        edgeOffset: 20,
        child: listView,
      );
    }

    return listView;
  }
}

class _NotificationsEmptyState extends StatelessWidget {
  const _NotificationsEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationErrorBanner extends StatelessWidget {
  const _NotificationErrorBanner({
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.isUnread,
    this.onTap,
  });

  final UserNotification notification;
  final bool isUnread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = _colorForNotificationType(
      theme,
      notification.type,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUnread
              ? accentColor.withValues(alpha: 0.08)
              : theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread
                ? accentColor.withValues(alpha: 0.4)
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconForNotificationType(notification.type),
                color: accentColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatRelativeTimestamp(notification.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isUnread)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(left: 8, top: 6),
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const List<String> _monthLabels = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatRelativeTimestamp(DateTime timestamp) {
  final local = timestamp.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);

  if (diff.inMinutes < 1) {
    return 'Just now';
  } else if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  } else if (diff.inHours < 24) {
    return '${diff.inHours}h ago';
  } else if (diff.inDays < 7) {
    return '${diff.inDays}d ago';
  } else if (diff.inDays < 365) {
    final month = _monthLabels[local.month - 1];
    return '$month ${local.day}';
  } else {
    final month = _monthLabels[local.month - 1];
    return '$month ${local.day}, ${local.year}';
  }
}

IconData _iconForNotificationType(String type) {
  final normalized = type.toLowerCase();
  switch (normalized) {
    case 'ticket_reply':
    case 'ticketreply':
      return Icons.mark_chat_unread_outlined;
    case 'ticket_status_change':
    case 'ticketstatuschange':
      return Icons.sync_rounded;
    case 'ticket_escalated':
    case 'ticketescalated':
      return Icons.warning_amber_rounded;
    case 'ticket_assigned':
    case 'ticketassigned':
      return Icons.assignment_ind_rounded;
    case 'new_ticket':
    case 'newticket':
      return Icons.support_agent_rounded;
    case 'sla_warning':
    case 'slawarning':
      return Icons.hourglass_bottom_rounded;
    case 'sla_breached':
    case 'slabreached':
      return Icons.report_problem_outlined;
    default:
      return Icons.notifications_active_rounded;
  }
}

Color _colorForNotificationType(ThemeData theme, String type) {
  final normalized = type.toLowerCase();
  switch (normalized) {
    case 'ticket_reply':
    case 'ticketreply':
      return theme.colorScheme.primary;
    case 'ticket_status_change':
    case 'ticketstatuschange':
      return theme.colorScheme.secondary;
    case 'ticket_escalated':
    case 'ticketescalated':
    case 'sla_warning':
    case 'slawarning':
      return theme.colorScheme.error;
    case 'sla_breached':
    case 'slabreached':
      return theme.colorScheme.error;
    case 'ticket_assigned':
    case 'ticketassigned':
    case 'new_ticket':
    case 'newticket':
      return theme.colorScheme.tertiary;
    default:
      return theme.colorScheme.primary;
  }
}

class _PromoCarousel extends StatelessWidget {
  const _PromoCarousel({
    required this.banners,
    required this.controller,
    required this.activeIndex,
    this.onCtaPressed,
  });

  final List<_PromoBannerData> banners;
  final PageController controller;
  final int activeIndex;
  final void Function(_PromoBannerData data)? onCtaPressed;

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 140,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: PageView.builder(
          controller: controller,
          itemCount: banners.length,
          itemBuilder: (context, index) {
            final banner = banners[index];
            return _PromoCard(
              data: banner,
              isActive: index == activeIndex,
              onCtaPressed: onCtaPressed == null
                  ? null
                  : () => onCtaPressed!(banner),
            );
          },
        ),
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({
    required this.data,
    required this.isActive,
    this.onCtaPressed,
  });

  final _PromoBannerData data;
  final bool isActive;
  final VoidCallback? onCtaPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isActive ? 1 : 0.96,
      duration: const Duration(milliseconds: 250),
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: data.colors),
          boxShadow: [
            BoxShadow(
              color: data.colors.last.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(data.icon, color: Colors.white, size: 24),
                const Spacer(),
                SizedBox(
                  height: 28,
                  child: FilledButton(
                    onPressed: onCtaPressed ?? () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: data.colors.first,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    child: Text(data.cta),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              data.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              data.subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingDeck extends StatelessWidget {
  const _TrendingDeck({
    required this.products,
    required this.userId,
    required this.favoritesSyncToken,
    required this.repository,
    this.onFavoriteStatusChanged,
  });

  final List<ProductSummary> products;
  final String userId;
  final int favoritesSyncToken;
  final DashboardRepository repository;
  final ValueChanged<bool>? onFavoriteStatusChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final product = products[index];
          final accent =
              Colors.primaries[index % Colors.primaries.length].shade400;
          return InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => ProductDetailScreen(
                    productId: product.id,
                    userId: userId,
                    repository: repository,
                    onFavoriteStatusChanged: onFavoriteStatusChanged,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withValues(alpha: 0.3)),
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Bestseller',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Flexible(
                        fit: FlexFit.tight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                product.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatPrice(product),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              height: 28,
                              child: FilledButton.tonal(
                                onPressed: () {},
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                                child: const Text('View deal'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _FavoriteButton(
                      productId: product.id,
                      userId: userId,
                      syncToken: favoritesSyncToken,
                      onStatusChanged: onFavoriteStatusChanged,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({
    required this.products,
    required this.isCompact,
    required this.userId,
    required this.favoritesSyncToken,
    required this.repository,
    this.onFavoriteStatusChanged,
    this.onAddToCart,
  });

  final List<ProductSummary> products;
  final bool isCompact;
  final String userId;
  final int favoritesSyncToken;
  final DashboardRepository repository;
  final ValueChanged<bool>? onFavoriteStatusChanged;
  final Future<void> Function(ProductSummary product)? onAddToCart;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = isCompact ? 2 : 3;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isCompact ? 0.55 : 0.65,
      ),
      itemBuilder: (context, index) {
        final product = products[index];
        final hash = product.id.hashCode;
        final rating = 3 + (hash.abs() % 20) / 10;
        final reviewCount = 50 + hash.abs() % 900;
        final hasPrime = hash.isEven;
        final shipsToday = hash % 3 == 0;
        final price = product.priceCents == null
            ? null
            : product.priceCents! / 100;
        final oldPrice = price == null
            ? null
            : (price * 1.2).clamp(0, double.infinity);

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.95, end: 1),
          duration: Duration(milliseconds: 250 + index * 30),
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => ProductDetailScreen(
                    productId: product.id,
                    userId: userId,
                    repository: repository,
                    onFavoriteStatusChanged: onFavoriteStatusChanged,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1.2,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          colors: [
                            Colors
                                .primaries[index % Colors.primaries.length]
                                .shade200,
                            Colors
                                .primaries[(index + 3) %
                                    Colors.primaries.length]
                                .shade100,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: _FavoriteButton(
                          productId: product.id,
                          userId: userId,
                          syncToken: favoritesSyncToken,
                          onStatusChanged: onFavoriteStatusChanged,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Make the middle content expand so the CTA stays anchored to the bottom
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 12,
                              color: Colors.amberAccent.shade700,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              rating.toStringAsFixed(1),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            Text(
                              ' ($reviewCount)',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: [
                            if (hasPrime)
                              _ProductBadge(
                                label: 'Prime',
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            if (shipsToday)
                              const _ProductBadge(
                                label: 'Ships today',
                                color: Color(0xFF10B981),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (price != null)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${product.currency} ${price.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (oldPrice != null)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Text(
                                    '${product.currency} ${oldPrice.toStringAsFixed(2)}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          decoration:
                                              TextDecoration.lineThrough,
                                          color: Colors.grey,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    height: 28,
                    child: FilledButton.tonalIcon(
                      onPressed: onAddToCart == null
                          ? null
                          : () => onAddToCart!(product),
                      icon: const Icon(
                        Icons.add_shopping_cart_rounded,
                        size: 14,
                      ),
                      label: const Text(
                        'Add to cart',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProductBadge extends StatelessWidget {
  const _ProductBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.items,
    required this.activeIndex,
    required this.onChanged,
    required this.cartItemCount,
    required this.favoritesCount,
  });

  final List<_NavItem> items;
  final int activeIndex;
  final ValueChanged<int> onChanged;
  final int cartItemCount;
  final int favoritesCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final background = colorScheme.surface;
    return LayoutBuilder(
      builder: (context, constraints) {
        final widthPerItem = constraints.maxWidth / items.length;
        final isCompact = widthPerItem < 88;
        final isUltraCompact = widthPerItem < 74;

        final EdgeInsets containerPadding = EdgeInsets.symmetric(
          horizontal: isUltraCompact
              ? 6
              : isCompact
              ? 8
              : 12,
          vertical: isUltraCompact ? 4 : 6,
        );

        final EdgeInsets itemPadding = EdgeInsets.symmetric(
          horizontal: isUltraCompact
              ? 4
              : isCompact
              ? 6
              : 10,
          vertical: isUltraCompact
              ? 4
              : isCompact
              ? 6
              : 8,
        );

        final double iconSize = isUltraCompact ? 20 : 24;
        final double labelFontSize = isUltraCompact ? 10 : 12;
        final double spacing = isUltraCompact ? 2 : 4;

        return Container(
          padding: containerPadding,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isActive = index == activeIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: itemPadding,
                    decoration: BoxDecoration(
                      color: isActive
                          ? colorScheme.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              item.icon,
                              size: iconSize,
                              color: isActive
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                            if (item.label == 'Favorites' && favoritesCount > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    favoritesCount > 9
                                        ? '9+'
                                        : favoritesCount.toString(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            if (item.label == 'Cart' && cartItemCount > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.error,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    cartItemCount > 9
                                        ? '9+'
                                        : cartItemCount.toString(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: spacing),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: labelFontSize,
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isActive
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _PromoBannerData {
  const _PromoBannerData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.colors,
    required this.icon,
    this.action,
  });

  final String id;
  final String title;
  final String subtitle;
  final String cta;
  final List<Color> colors;
  final IconData icon;
  final String? action;
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _ShopperDashboardState extends State<ShopperDashboard> {
  late Future<ShopperDashboardData> _future;
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  final PageController _promoController = PageController(viewportFraction: 1.0);
  bool _isSearchFocused = false;
  int _activePromoIndex = 0;
  Timer? _promoTimer;
  int _latestPromoCount = _defaultPromoBanners.length;
  bool _showCartReminder = true;
  int _activeFilterIndex = 0;
  int _activeNavIndex = 0;
  String _searchQuery = '';
  // Use ValueNotifier so counts can update independently without rebuilding
  // the whole dashboard FutureBuilder.
  final ValueNotifier<int> _cartItemCount = ValueNotifier<int>(0);
  final ValueNotifier<int> _favoritesCount = ValueNotifier<int>(0);
  int _favoritesStatusVersion = 0;
  Timer? _searchDebounce;
  List<UserNotification> _notifications = const <UserNotification>[];
  final Set<String> _acknowledgedNotificationIds = <String>{};
  bool _notificationsInitialized = false;
  bool _notificationLoading = false;
  String? _notificationError;

  // Filters are loaded from the server (categories) at runtime. The UI will
  // construct a local filter list from the categories returned by
  // `loadShopperData` (see build()).

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.home_filled, label: 'Home'),
    _NavItem(icon: Icons.favorite_rounded, label: 'Favorites'),
    _NavItem(icon: Icons.local_fire_department_rounded, label: 'Deals'),
    _NavItem(icon: Icons.shopping_cart_rounded, label: 'Cart'),
    _NavItem(icon: Icons.person_rounded, label: 'Profile'),
  ];

  int get _notificationBadgeCount {
    if (_notifications.isEmpty) {
      return 0;
    }
    return _notifications
        .where(
          (notification) =>
              !_acknowledgedNotificationIds.contains(notification.id),
        )
        .length;
  }

  static const List<_PromoBannerData> _defaultPromoBanners = [
    _PromoBannerData(
      id: 'flash',
      title: 'Weekend Flash',
      subtitle: '30% off daily essentials',
      cta: 'Shop now',
      colors: [Color(0xFFFF7750), Color(0xFFFFB347)],
      icon: Icons.bolt_rounded,
    ),
    _PromoBannerData(
      id: 'tech',
      title: 'Tech Upgrade',
      subtitle: 'Save on smart devices',
      cta: 'View deals',
      colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
      icon: Icons.devices_other_rounded,
    ),
    _PromoBannerData(
      id: 'arrivals',
      title: 'New Arrivals',
      subtitle: 'Fresh fits for fall',
      cta: 'Discover',
      colors: [Color(0xFF10B981), Color(0xFF34D399)],
      icon: Icons.eco_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadShopperData();
    _searchFocusNode.addListener(_handleSearchFocus);
    _searchController.addListener(_handleSearchTextChanged);
    _promoController.addListener(_handlePromoPosition);
    _startPromoAutoScroll();
    _loadCartCount();
    _loadFavoritesCount();
    _loadNotifications();
  }

  Future<void> _loadCartCount() async {
    try {
      final cart = await widget.repository.getOrCreateCart(
        widget.profile.userId,
      );
      if (mounted) {
        setState(() {
          _cartItemCount.value = cart.itemCount;
        });
      }
    } catch (e) {
      // Silently fail - cart count is not critical
      if (mounted) {
        setState(() {
          _cartItemCount.value = 0;
        });
      }
    }
  }

  Future<void> _loadFavoritesCount() async {
    try {
      final favorites = await widget.repository.getFavorites(
        widget.profile.userId,
      );
      if (mounted) {
        setState(() {
          _favoritesCount.value = favorites.length;
        });
      }
    } catch (e) {
      // Silently fail - favorites count is not critical
      if (mounted) {
        setState(() {
          _favoritesCount.value = 0;
        });
      }
    }
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() {
      _notificationLoading = true;
      _notificationError = null;
    });

    try {
      final notifications = await widget.repository.getRecentNotifications(
        userId: widget.profile.userId,
        limit: 20,
      );
      if (!mounted) return;
      final notificationIds =
          notifications.map((notification) => notification.id).toSet();
      setState(() {
        _notifications = notifications;
        _notificationLoading = false;
        _notificationsInitialized = true;
        _notificationError = null;
        _acknowledgedNotificationIds
            .removeWhere((id) => !notificationIds.contains(id));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _notificationError = e.toString();
        _notificationLoading = false;
        _notificationsInitialized = true;
      });
    }
  }

  Future<void> _refreshNotifications() {
    return _loadNotifications();
  }

  void _markNotificationAsRead(UserNotification notification) {
    if (_acknowledgedNotificationIds.contains(notification.id)) {
      return;
    }
    setState(() {
      _acknowledgedNotificationIds.add(notification.id);
    });
  }

  void _markAllNotificationsRead() {
    if (_notifications.isEmpty) return;
    setState(() {
      _acknowledgedNotificationIds
          .addAll(_notifications.map((notification) => notification.id));
    });
  }

  Future<void> _handleNotificationsPressed() async {
    if (!_notificationsInitialized && !_notificationLoading) {
      await _loadNotifications();
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            Future<void> refresh() async {
              final future = _refreshNotifications();
              if (!context.mounted) return;
              modalSetState(() {});
              await future;
              if (!context.mounted) return;
              modalSetState(() {});
            }

            void markRead(UserNotification notification) {
              if (_acknowledgedNotificationIds.contains(notification.id)) {
                return;
              }
              _markNotificationAsRead(notification);
              if (!context.mounted) return;
              modalSetState(() {});
            }

            void markAll() {
              _markAllNotificationsRead();
              if (!context.mounted) return;
              modalSetState(() {});
            }

            return FractionallySizedBox(
              heightFactor: 0.9,
              child: _NotificationsSheet(
                notifications: _notifications,
                isLoading: _notificationLoading,
                errorMessage: _notificationError,
                readNotificationIds: _acknowledgedNotificationIds,
                onNotificationTap: markRead,
                onRefresh: refresh,
                onRetry: () {
                  refresh();
                },
                onMarkAllRead: markAll,
              ),
            );
          },
        );
      },
    );
  }

  void _handleFavoriteStatusChanged(bool isFavorite) {
    if (!mounted) return;
    setState(() {
      if (isFavorite) {
        _favoritesCount.value += 1;
      } else if (_favoritesCount.value > 0) {
        _favoritesCount.value -= 1;
      }
    });
  }

  void _handleDetailFavoriteChanged(bool isFavorite) {
    _handleFavoriteStatusChanged(isFavorite);
    _favoritesStatusVersion += 1;
    _loadFavoritesCount();
  }

  Future<void> _handleAddToCart(ProductSummary product) async {
    if (product.priceCents == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Price unavailable for ${product.name}')),
      );
      return;
    }

    try {
      await widget.repository.addToCart(
        userId: widget.profile.userId,
        productId: product.id,
        quantity: 1,
        unitPriceCents: product.priceCents!,
        currency: product.currency,
      );

      await _loadCartCount();
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Added ${product.name} to cart'),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'View Cart',
              onPressed: () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute<void>(
                        builder: (context) => ShoppingCartScreen(
                          userId: widget.profile.userId,
                          repository: widget.repository,
                        ),
                      ),
                    )
                    .then((_) {
                      if (mounted) {
                        _loadCartCount();
                      }
                    });
              },
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add to cart: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _promoTimer?.cancel();
    _promoController
      ..removeListener(_handlePromoPosition)
      ..dispose();
    _searchFocusNode
      ..removeListener(_handleSearchFocus)
      ..dispose();
    _searchController
      ..removeListener(_handleSearchTextChanged)
      ..dispose();
    _searchDebounce?.cancel();
    _cartItemCount.dispose();
    _favoritesCount.dispose();
    super.dispose();
  }

  void _handleSearchFocus() {
    setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
  }

  void _handleSearchTextChanged() {
    final nextQuery = _searchController.text;
    if (nextQuery == _searchQuery) return;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _searchQuery = nextQuery);
    });
  }

  void _handleSearchSubmitted(String value) {
    final trimmed = value.trim();
    if (trimmed != value) {
      _searchController.value = TextEditingValue(
        text: trimmed,
        selection: TextSelection.collapsed(offset: trimmed.length),
      );
    }
    _searchFocusNode.unfocus();
  }

  void _clearSearch() {
    if (_searchController.text.isEmpty) return;
    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  void _handlePromoPosition() {
    final page = _promoController.page?.round() ?? 0;
    if (page != _activePromoIndex) {
      setState(() => _activePromoIndex = page);
    }
  }

  void _startPromoAutoScroll() {
    _promoTimer?.cancel();
    _promoTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_promoController.hasClients) return;
      if (_latestPromoCount <= 1) return;
      final nextPage = (_activePromoIndex + 1) % _latestPromoCount;
      _promoController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  List<ProductSummary> _filteredProducts(
    List<ProductSummary> products,
    List<CategorySummary> categories,
  ) {
    var filtered = products;

    // Build filter names from categories (All + category names)
    final filterNames = ['All', ...categories.map((c) => c.name)];
    final filterName =
        filterNames[_activeFilterIndex.clamp(0, filterNames.length - 1)];
    if (filterName != 'All') {
      filtered = filtered.where((product) {
        // Match filter name with category name (case-insensitive)
        return product.categoryName?.toLowerCase() == filterName.toLowerCase();
      }).toList();
    }

    // Apply search query
    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((product) {
        final nameMatch = product.name.toLowerCase().contains(query);
        final categoryMatch =
            product.categoryName?.toLowerCase().contains(query) ?? false;
        final priceLabel = _formatPrice(product).toLowerCase();
        final idMatch = product.id.toLowerCase().contains(query);
        return nameMatch ||
            categoryMatch ||
            idMatch ||
            priceLabel.contains(query);
      }).toList();
    }

    return filtered;
  }

  int _indexForCategory(String? categoryId, List<CategorySummary> categories) {
    if (categoryId == null) return 0;
    final idx = categories.indexWhere((cat) => cat.id == categoryId);
    if (idx == -1) return 0;
    return idx + 1;
  }

  List<_PromoBannerData> _promoBannersFrom(List<HomePromo> promos) {
    if (promos.isEmpty) {
      return _defaultPromoBanners;
    }
    final fallback = _defaultPromoBanners.first.colors;
    return promos
        .map(
          (promo) => _PromoBannerData(
            id: promo.id,
            title: promo.title,
            subtitle: promo.subtitle,
            cta: promo.ctaLabel,
            colors: [
              _promoColorFromHex(promo.primaryColorHex, fallback.first),
              _promoColorFromHex(
                promo.secondaryColorHex,
                fallback.length > 1 ? fallback[1] : fallback.first,
              ),
            ],
            icon: _promoIconFromName(promo.iconName),
            action: promo.ctaAction,
          ),
        )
        .toList();
  }

  Color _promoColorFromHex(String? value, Color fallback) {
    if (value == null) return fallback;
    var raw = value.trim();
    if (raw.isEmpty) return fallback;
    if (raw.startsWith('#')) raw = raw.substring(1);
    if (raw.startsWith('0x')) raw = raw.substring(2);
    int? colorInt = int.tryParse(raw);
    colorInt ??= int.tryParse(raw, radix: 16);
    if (colorInt == null) return fallback;
    if (raw.length <= 6) {
      colorInt |= 0xFF000000;
    }
    return Color(colorInt);
  }

  IconData _promoIconFromName(String? name) {
    switch (name?.toLowerCase()) {
      case 'flash':
      case 'bolt':
        return Icons.bolt_rounded;
      case 'tech':
      case 'device':
        return Icons.devices_other_rounded;
      case 'grocery':
      case 'basket':
        return Icons.shopping_basket_rounded;
      case 'delivery':
        return Icons.local_shipping;
      case 'eco':
      case 'leaf':
        return Icons.eco_rounded;
      default:
        return Icons.local_offer_rounded;
    }
  }

  void _reload() {
    setState(() {
      _future = widget.repository.loadShopperData();
    });
  }

  Future<void> _refresh() {
    final future = widget.repository.loadShopperData();
    setState(() {
      _future = future;
    });
    return future;
  }

  Future<void> _openFavorites() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => FavoritesScreen(userId: widget.profile.userId),
      ),
    );
    if (!mounted) return;
    setState(() {
      _activeNavIndex = 0;
      _favoritesStatusVersion += 1;
    });
    _loadFavoritesCount();
  }

  Future<void> _openCart() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ShoppingCartScreen(
          userId: widget.profile.userId,
          repository: widget.repository,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _activeNavIndex = 0);
    _loadCartCount();
  }

  Future<void> _openProfileFromNav() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProfileScreen(
          profile: widget.profile,
          repository: widget.profileRepository,
          dashboardRepository: widget.repository,
          email: widget.userEmail,
          roles: widget.roles,
          activeRole: widget.activeRole,
          onRoleChanged: widget.onRoleChanged,
          onReloadRequested: widget.onReloadRequested,
        ),
      ),
    );

    if (!mounted) return;
    setState(() => _activeNavIndex = 0);
  }

  void _handlePromoCta(_PromoBannerData data) {
    final action = data.action?.toLowerCase().trim();
    if (action == null || action.isEmpty) {
      _showPromoSnack('${data.title} is coming soon.');
      return;
    }
    if (action.contains('favorite')) {
      _openFavorites();
      return;
    }
    if (action.contains('cart')) {
      _openCart();
      return;
    }
    if (action.contains('profile')) {
      _openProfileFromNav();
      return;
    }
    _showPromoSnack('Promo action "$action" not wired yet.');
  }

  void _showPromoSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Allow the body to extend behind the custom navigation bar so it can
      // sit flush with the bottom system inset without an artificial gap.
      extendBody: true,
      // Keep the body driven by the existing FutureBuilder so loading/error
      // states remain unchanged, but place the navigation into the
      // Scaffold's bottomNavigationBar so it stays visible while scrolling.
      body: FutureBuilder<ShopperDashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _DashboardLoading();
          }
          if (snapshot.hasError) {
            return _DashboardError(
              message:
                  'Could not load featured products. Pull to refresh or try again.',
              error: snapshot.error.toString(),
              onRetry: _reload,
            );
          }
          final data = snapshot.data!;
          final promoBanners = _promoBannersFrom(data.promos);
          _latestPromoCount = promoBanners.length;
          final trendingProducts = data.featuredProducts.take(5).toList();
          final filteredProducts = _filteredProducts(
            data.featuredProducts,
            data.categories,
          );
          final hasSearchQuery = _searchQuery.trim().isNotEmpty;
          final activeQueryLabel = _searchController.text.trim();
          final theme = Theme.of(context);
          return RefreshIndicator(
            onRefresh: _refresh,
            displacement: 12,
            color: theme.colorScheme.primary,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 500;
                final textColor = theme.colorScheme.onSurface;
                final surfaceVariant = theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.8);

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HomeHeader(
                          profile: widget.profile,
                          notificationCount: _notificationBadgeCount,
                          onNotificationsPressed: _handleNotificationsPressed,
                          userEmail: widget.userEmail,
                        ),
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _showCartReminder
                              ? _InlineNotificationBanner(
                                  message:
                                      '4 items are waiting in your cart. Checkout now before they sell out.',
                                  onClose: () =>
                                      setState(() => _showCartReminder = false),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 20),
                        _PromoCarousel(
                          banners: promoBanners,
                          controller: _promoController,
                          activeIndex: _activePromoIndex,
                          onCtaPressed: _handlePromoCta,
                        ),
                        const SizedBox(height: 20),
                        _SectionHeader(
                          title: 'Trending now 🔥',
                          action: IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Reload deals',
                            onPressed: _reload,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (trendingProducts.isEmpty)
                          const _EmptyState(
                            message: 'No published products yet.',
                          )
                        else
                          _TrendingDeck(
                            products: trendingProducts,
                            userId: widget.profile.userId,
                            favoritesSyncToken: _favoritesStatusVersion,
                            repository: widget.repository,
                            onFavoriteStatusChanged:
                                _handleDetailFavoriteChanged,
                          ),
                        const SizedBox(height: 24),
                        _CategoryFilter(
                          categories: data.categories,
                          selectedCategoryId: _activeFilterIndex == 0
                              ? null
                              : data.categories[_activeFilterIndex - 1].id,
                          onCategorySelected: (categoryId) {
                            setState(() {
                              _activeFilterIndex =
                                  _indexForCategory(categoryId, data.categories);
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        _SectionHeader(title: 'Personalized picks'),
                        const SizedBox(height: 12),
                        _SearchField(
                          focusNode: _searchFocusNode,
                          isFocused: _isSearchFocused,
                          controller: _searchController,
                          onClear: _clearSearch,
                          onSubmitted: _handleSearchSubmitted,
                          onAdvancedSearch: () async {
                            final selectedCategoryId =
                                _activeFilterIndex == 0 ||
                                    _activeFilterIndex - 1 >=
                                        data.categories.length
                                ? null
                                : data.categories[_activeFilterIndex - 1].id;
                            final result = await Navigator.of(context)
                                .push<SearchResult?>(
                                  MaterialPageRoute<SearchResult?>(
                                    builder: (context) => ProductSearchScreen(
                                      userId: widget.profile.userId,
                                      categories: data.categories,
                                      initialQuery: _searchController.text,
                                      initialCategoryId: selectedCategoryId,
                                    ),
                                  ),
                                );

                            if (!mounted) return;
                            if (result == null) {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                                _activeFilterIndex = 0;
                              });
                              return;
                            }

                            setState(() {
                              _searchController.text = result.query;
                              _searchQuery = result.query;
                              _activeFilterIndex = _indexForCategory(
                                result.categoryId,
                                data.categories,
                              );
                            });
                          },
                        ),

                        const SizedBox(height: 12),
                        if (data.featuredProducts.isEmpty)
                          const _EmptyState(
                            message:
                                'No personalized products yet. Publish a product to preview the shopper view.',
                          )
                        else if (hasSearchQuery && filteredProducts.isEmpty)
                          _EmptyState(
                            message:
                                'No products found for "$activeQueryLabel". Try a different keyword or clear the search.',
                          )
                        else
                          _ProductGrid(
                            products: filteredProducts,
                            isCompact: isCompact,
                            userId: widget.profile.userId,
                            favoritesSyncToken: _favoritesStatusVersion,
                            repository: widget.repository,
                            onFavoriteStatusChanged:
                                _handleDetailFavoriteChanged,
                            onAddToCart: _handleAddToCart,
                          ),
                        const SizedBox(height: 24),
                        Text(
                          'Load time optimized with lazy content. Images stream after the first frame for faster perceived performance.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: textColor.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Navigation responds to device width: more than 600px swaps to a rail in the dedicated mobile shell.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: textColor.withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: surfaceVariant,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'ARIA labels and semantic regions included. Toasts use aria-live for voice-over support.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      // Remove the extra bottom padding so the bar rests directly on the
      // system inset (SafeArea provides required bottom spacing). This trims
      // the previously visible gap beneath the buttons.
      bottomNavigationBar: SafeArea(
        top: false,
        child: ValueListenableBuilder<int>(
          valueListenable: _cartItemCount,
          builder: (context, cartCount, _) {
            return ValueListenableBuilder<int>(
              valueListenable: _favoritesCount,
              builder: (context, favCount, _) {
                return _BottomNavBar(
                  items: _navItems,
                  activeIndex: _activeNavIndex,
                  cartItemCount: cartCount,
                  favoritesCount: favCount,
                  onChanged: (index) {
                    setState(() => _activeNavIndex = index);

                    if (index == 1) {
                      _openFavorites();
                      return;
                    }
                    if (index == 3) {
                      _openCart();
                      return;
                    }
                    if (index == 4) {
                      _openProfileFromNav();
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  final List<CategorySummary> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelected;

  // Map category names to icons
  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('electronic')) return Icons.laptop_chromebook;
    if (name.contains('fashion') || name.contains('cloth')) {
      return Icons.checkroom;
    }
    if (name.contains('home') || name.contains('furniture')) return Icons.home;
    if (name.contains('food') || name.contains('grocery')) {
      return Icons.restaurant;
    }
    if (name.contains('book')) return Icons.menu_book;
    if (name.contains('sport')) return Icons.sports_soccer;
    if (name.contains('toy')) return Icons.toys;
    if (name.contains('beauty') || name.contains('health')) return Icons.spa;
    return Icons.category; // Default icon
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Categories',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length + 1, // +1 for "All"
            itemBuilder: (context, index) {
              final isAll = index == 0;
              final category = isAll ? null : categories[index - 1];
              final isSelected = isAll
                  ? selectedCategoryId == null
                  : selectedCategoryId == category?.id;

              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _CategoryItem(
                  label: isAll ? 'All' : category!.name,
                  icon: isAll
                      ? Icons.grid_view
                      : _getCategoryIcon(category!.name),
                  isSelected: isSelected,
                  onTap: () => onCategorySelected(category?.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 32,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _FavoriteButton extends StatefulWidget {
  const _FavoriteButton({
    required this.productId,
    required this.userId,
    required this.syncToken,
    this.onStatusChanged,
  });

  final String productId;
  final String userId;
  final int syncToken;
  final ValueChanged<bool>? onStatusChanged;

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton>
    with SingleTickerProviderStateMixin {
  bool _isFavorite = false;
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadFavoriteStatus();
  }

  @override
  void didUpdateWidget(covariant _FavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.syncToken != oldWidget.syncToken) {
      _loadFavoriteStatus();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadFavoriteStatus() async {
    if (!_isLoading && mounted) {
      setState(() => _isLoading = true);
    } else {
      _isLoading = true;
    }
    try {
      final repository = DashboardRepository(Supabase.instance.client);
      final isFavorite = await repository.isFavorite(
        userId: widget.userId,
        productId: widget.productId,
      );
      if (mounted) {
        setState(() {
          _isFavorite = isFavorite;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final repository = DashboardRepository(Supabase.instance.client);
      final wasFavorite = _isFavorite;

      if (wasFavorite) {
        await repository.removeFavorite(
          userId: widget.userId,
          productId: widget.productId,
        );
      } else {
        await repository.addFavorite(
          userId: widget.userId,
          productId: widget.productId,
        );
        _animationController.forward().then((_) {
          _animationController.reverse();
        });
      }

      if (mounted) {
        final nextStatus = !wasFavorite;
        setState(() {
          _isFavorite = nextStatus;
          _isLoading = false;
        });
        widget.onStatusChanged?.call(nextStatus);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update favorite: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: IconButton(
        icon: Icon(
          _isFavorite ? Icons.favorite : Icons.favorite_border,
          size: 16,
        ),
        color: _isFavorite ? Colors.red : Colors.white,
        onPressed: _isLoading ? null : _toggleFavorite,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }
}
