import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../dashboard/dashboard_repository.dart';
import '../../profile/profile_models.dart';
import 'seller_models.dart';
import 'seller_repository.dart';
import 'catalog/catalog_screen.dart';
import 'orders/orders_screen.dart';
import 'support/support_screen.dart';
import 'analytics/analytics_screen.dart';
import 'settings/staff_management_screen.dart';
import 'settings/kyc_management_screen.dart';

/// Main shell for seller workspace with tab navigation
class SellerHubShell extends StatefulWidget {
  const SellerHubShell({
    required this.vendorId,
    required this.vendorName,
    required this.assignment,
    required this.userId,
    super.key,
  });

  final String vendorId;
  final String vendorName;
  final RoleAssignment assignment;
  final String userId;

  @override
  State<SellerHubShell> createState() => _SellerHubShellState();
}

class _SellerHubShellState extends State<SellerHubShell> {
  late final DashboardRepository _dashboardRepository;
  late final SellerRepository _sellerRepository;
  late Future<SellerPermissions> _permissionsFuture;
  late Future<SellerStats> _statsFuture;

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _dashboardRepository = DashboardRepository(Supabase.instance.client);
    _sellerRepository = SellerRepository(Supabase.instance.client);
    _loadData();
  }

  void _loadData() {
    setState(() {
      _permissionsFuture = _sellerRepository.getPermissions(
        widget.vendorId,
        widget.userId,
      );
      _statsFuture = _sellerRepository.getSellerStats(widget.vendorId);
    });
  }

  void _navigateToSettings(String setting) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          switch (setting) {
            case 'staff':
              return StaffManagementScreen(
                vendorId: widget.vendorId,
                vendorName: widget.vendorName,
                repository: _sellerRepository,
              );
            case 'kyc':
              return KycManagementScreen(
                vendorId: widget.vendorId,
                vendorName: widget.vendorName,
                repository: _sellerRepository,
              );
            default:
              return const Scaffold(
                body: Center(child: Text('Unknown setting')),
              );
          }
        },
      ),
    );
  }

  List<_NavItem> _getAvailableTabs(SellerPermissions permissions) {
    final tabs = <_NavItem>[];

    if (permissions.catalogRead) {
      tabs.add(
        const _NavItem(
          label: 'Catalog',
          icon: Icons.inventory_2,
          tab: SellerTab.catalog,
        ),
      );
    }

    if (permissions.ordersRead) {
      tabs.add(
        const _NavItem(
          label: 'Orders',
          icon: Icons.shopping_bag,
          tab: SellerTab.orders,
        ),
      );
    }

    if (permissions.supportRead) {
      tabs.add(
        const _NavItem(
          label: 'Support',
          icon: Icons.support_agent,
          tab: SellerTab.support,
        ),
      );
    }

    if (permissions.analyticsRead) {
      tabs.add(
        const _NavItem(
          label: 'Analytics',
          icon: Icons.analytics,
          tab: SellerTab.analytics,
        ),
      );
    }

    return tabs;
  }

  Widget _buildScreen(SellerTab tab, SellerPermissions permissions) {
    switch (tab) {
      case SellerTab.catalog:
        return CatalogScreen(
          vendorId: widget.vendorId,
          vendorName: widget.vendorName,
          permissions: permissions,
          repository: _dashboardRepository,
        );
      case SellerTab.orders:
        return OrdersScreen(
          vendorId: widget.vendorId,
          vendorName: widget.vendorName,
          permissions: permissions,
          repository: _dashboardRepository,
        );
      case SellerTab.support:
        return SupportScreen(
          vendorId: widget.vendorId,
          vendorName: widget.vendorName,
          permissions: permissions,
          repository: _sellerRepository,
        );
      case SellerTab.analytics:
        return AnalyticsScreen(
          vendorId: widget.vendorId,
          vendorName: widget.vendorName,
          permissions: permissions,
          repository: _dashboardRepository,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SellerPermissions>(
      future: _permissionsFuture,
      builder: (context, permSnapshot) {
        if (permSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (permSnapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading permissions: ${permSnapshot.error}'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final permissions = permSnapshot.data!;
        final tabs = _getAvailableTabs(permissions);

        if (tabs.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text('${widget.vendorName} - Seller Hub')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock, size: 64),
                  const SizedBox(height: 16),
                  const Text('You do not have access to any seller modules.'),
                  const SizedBox(height: 8),
                  Text(
                    'Contact the vendor owner to request permissions.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        }

        // Ensure current index is valid
        if (_currentIndex >= tabs.length) {
          _currentIndex = 0;
        }

        final currentTab = tabs[_currentIndex].tab;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.vendorName),
                Text(
                  'Seller Hub - ${widget.assignment.role == AppUserRole.vendorOwner ? "Owner" : "Staff"}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            actions: [
              // Stats indicator
              FutureBuilder<SellerStats>(
                future: _statsFuture,
                builder: (context, statsSnapshot) {
                  if (statsSnapshot.hasData) {
                    return _StatsIndicator(stats: statsSnapshot.data!);
                  }
                  return const SizedBox.shrink();
                },
              ),
              // Settings menu (Owner only)
              if (widget.assignment.role == AppUserRole.vendorOwner)
                PopupMenuButton(
                  icon: const Icon(Icons.settings),
                  tooltip: 'Settings',
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'staff',
                      child: ListTile(
                        leading: Icon(Icons.people),
                        title: Text('Staff Management'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'kyc',
                      child: ListTile(
                        leading: Icon(Icons.verified_user),
                        title: Text('KYC & Compliance'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  onSelected: _navigateToSettings,
                ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _loadData,
              ),
            ],
          ),
          body: _buildScreen(currentTab, permissions),
          bottomNavigationBar: tabs.length > 1
              ? NavigationBar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  destinations: tabs
                      .map(
                        (item) => NavigationDestination(
                          icon: Icon(item.icon),
                          label: item.label,
                        ),
                      )
                      .toList(),
                )
              : null,
        );
      },
    );
  }
}

class _NavItem {
  const _NavItem({required this.label, required this.icon, required this.tab});

  final String label;
  final IconData icon;
  final SellerTab tab;
}

class _StatsIndicator extends StatelessWidget {
  const _StatsIndicator({required this.stats});

  final SellerStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAlerts = stats.pendingOrders > 0 || stats.openSupportTickets > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: hasAlerts
                ? theme.colorScheme.errorContainer
                : theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (stats.pendingOrders > 0) ...[
                Icon(
                  Icons.shopping_bag,
                  size: 16,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 4),
                Text(
                  '${stats.pendingOrders}',
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
              if (stats.pendingOrders > 0 && stats.openSupportTickets > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Container(
                    width: 1,
                    height: 12,
                    color: theme.colorScheme.onErrorContainer.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              if (stats.openSupportTickets > 0) ...[
                Icon(
                  Icons.support_agent,
                  size: 16,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 4),
                Text(
                  '${stats.openSupportTickets}',
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
              if (!hasAlerts) ...[
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 4),
                Text(
                  'All clear',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
