import 'package:flutter/material.dart';
import '../services/notification_coordinator.dart';

/// Widget that displays in-app alerts as snackbars/toasts
class InAppAlertWidget extends StatelessWidget {
  const InAppAlertWidget({
    required this.alert,
    required this.onAction,
    super.key,
  });

  final InAppAlert alert;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: alert.color,
      elevation: 4,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(alert.icon, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    alert.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.message,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
            if (alert.action != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 51),
                ),
                child: Text(
                  alert.action == InAppAlertAction.viewTicket ? 'View' : 'Open',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Show alert as a snackbar
  static void showAsSnackbar(
    BuildContext context,
    InAppAlert alert, {
    VoidCallback? onAction,
  }) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(alert.icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  alert.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(alert.message),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: alert.color,
      behavior: SnackBarBehavior.floating,
      duration: alert.persistent
          ? const Duration(days: 1)
          : const Duration(seconds: 4),
      action: alert.action != null
          ? SnackBarAction(
              label: alert.action == InAppAlertAction.viewTicket
                  ? 'View'
                  : 'Open',
              textColor: Colors.white,
              onPressed: () {
                onAction?.call();
              },
            )
          : null,
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  /// Show alert as a persistent banner at the top
  static Widget buildBanner(
    BuildContext context,
    InAppAlert alert, {
    VoidCallback? onAction,
    VoidCallback? onDismiss,
  }) {
    return Container(
      color: alert.color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(alert.icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  alert.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  alert.message,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          if (alert.action != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                alert.action == InAppAlertAction.viewTicket ? 'View' : 'Open',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

/// Manages a queue of in-app alerts to prevent stacking
class AlertQueue {
  final List<InAppAlert> _queue = [];
  bool _isShowing = false;

  void add(InAppAlert alert) {
    // Check if similar alert already in queue
    final exists = _queue.any(
      (a) => a.ticketId == alert.ticketId && a.type == alert.type,
    );

    if (!exists) {
      _queue.add(alert);
    }
  }

  InAppAlert? getNext() {
    if (_queue.isEmpty) return null;
    return _queue.removeAt(0);
  }

  bool get hasAlerts => _queue.isNotEmpty;

  int get count => _queue.length;

  void clear() {
    _queue.clear();
  }

  void setShowing(bool showing) {
    _isShowing = showing;
  }

  bool get isShowing => _isShowing;
}
