# Realtime Ticket Updates - Quick Reference

## Setup

```dart
// 1. Import service
import '../../shared/services/ticket_realtime_service.dart';

// 2. Create instance in State
late final TicketRealtimeService _realtimeService;
StreamSubscription<TicketRealtimeEvent>? _subscription;

// 3. Initialize in initState
@override
void initState() {
  super.initState();
  _realtimeService = TicketRealtimeService(Supabase.instance.client);
  _subscribeToUpdates();
}

// 4. Cleanup in dispose
@override
void dispose() {
  _subscription?.cancel();
  _realtimeService.dispose();
  super.dispose();
}
```

## Subscription Types

### Single Ticket
```dart
_subscription = _realtimeService
    .subscribeToTicket(ticketId)
    .listen(_handleEvent);
```

### Vendor's Tickets
```dart
_subscription = _realtimeService
    .subscribeToVendorTickets(vendorId)
    .listen(_handleEvent);
```

### Entire Moderation Queue
```dart
_subscription = _realtimeService
    .subscribeToModerationQueue()
    .listen(_handleModerationEvent);
```

## Event Handling

```dart
void _handleEvent(TicketRealtimeEvent event) {
  if (!mounted) return;

  // Check event type
  if (event.isStatusChange) {
    // Status changed
    final newStatus = event.status;
  }

  if (event.isNewMessage) {
    // New message added
    _refreshMessages();
  }

  if (event.isEscalated) {
    // Ticket escalated to admin
    _showNotification('Ticket escalated');
  }

  if (event.isModerationUpdate) {
    // Moderation queue updated
    final assignedTo = event.assignedAdminId;
  }

  // Update local state
  setState(() {
    // Update your data
  });
}
```

## Event Properties

### TicketRealtimeEvent
- `eventType` - 'INSERT', 'UPDATE', 'DELETE', 'new_message', 'moderation_*'
- `ticketId` - Affected ticket ID
- `status` - New status (if changed)
- `priority` - New priority (if changed)
- `escalated` - Escalation flag
- `slaStatus` - SLA status
- `queueStatus` - Moderation queue status
- `assignedAdminId` - Assigned admin
- `messageId` - New message ID (if message event)

### Helper Booleans
- `isTicketUpdate` - Ticket table changed
- `isModerationUpdate` - Moderation queue changed
- `isNewMessage` - New message added
- `isStatusChange` - Status field changed
- `isEscalated` - Escalated flag is true

## Show Notifications

```dart
void _showSnackBar(String message, IconData icon, Color color) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ),
  );
}
```

## Common Patterns

### Update List Item
```dart
final index = _items.indexWhere((item) => item.id == event.ticketId);
if (index >= 0) {
  setState(() {
    _items[index] = _items[index].copyWith(
      status: event.status ?? _items[index].status,
      priority: event.priority ?? _items[index].priority,
    );
  });
}
```

### Add New Item
```dart
if (event.eventType == 'INSERT') {
  _refreshData(); // Full refresh for new items
}
```

### Remove Item
```dart
if (event.eventType == 'DELETE') {
  setState(() {
    _items.removeWhere((item) => item.id == event.ticketId);
  });
}
```

## Testing Checklist

- [ ] Subscribe on screen open
- [ ] Unsubscribe on screen close
- [ ] Handle INSERT events
- [ ] Handle UPDATE events
- [ ] Handle DELETE events
- [ ] Show user notifications
- [ ] Update local state correctly
- [ ] Test with multiple clients
- [ ] Verify no memory leaks
- [ ] Check error handling

## Common Issues

### Issue: No updates received
**Fix:** Check Supabase Realtime is enabled and RLS policies allow SELECT

### Issue: Duplicate subscriptions
**Fix:** Check for existing subscription before creating new one

### Issue: Memory leak
**Fix:** Always call `_subscription?.cancel()` and `_realtimeService.dispose()`

### Issue: Events after dispose
**Fix:** Add `if (!mounted) return;` check in event handler

## Performance Tips

✅ **DO:**
- Use broadcast streams for multiple listeners
- Dispose subscriptions when done
- Use filters to reduce events
- Update only changed UI parts

❌ **DON'T:**
- Create multiple subscriptions to same data
- Forget to dispose services
- Rebuild entire screen on each event
- Subscribe without disposing

## Example: Complete Widget

```dart
class TicketScreen extends StatefulWidget {
  const TicketScreen({required this.ticketId, super.key});
  final String ticketId;

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  late final TicketRealtimeService _realtimeService;
  StreamSubscription<TicketRealtimeEvent>? _subscription;
  Ticket? _ticket;

  @override
  void initState() {
    super.initState();
    _realtimeService = TicketRealtimeService(Supabase.instance.client);
    _loadTicket();
    _subscribeToUpdates();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _realtimeService.dispose();
    super.dispose();
  }

  Future<void> _loadTicket() async {
    // Load ticket data
  }

  void _subscribeToUpdates() {
    _subscription = _realtimeService
        .subscribeToTicket(widget.ticketId)
        .listen((event) {
      if (!mounted) return;
      
      if (event.isStatusChange) {
        setState(() {
          _ticket = _ticket?.copyWith(status: event.status);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Build UI
  }
}
```

## Need Help?

See full documentation: [REALTIME_TICKET_UPDATES.md](./REALTIME_TICKET_UPDATES.md)
