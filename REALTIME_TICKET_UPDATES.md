# Realtime Ticket Updates Implementation Guide

## Overview

This document describes the implementation of Supabase Realtime subscriptions for live ticket updates in the JoMarket support and moderation system.

## Architecture

### Components

1. **TicketRealtimeService** (`lib/app/shared/services/ticket_realtime_service.dart`)
   - Central service for managing Supabase Realtime subscriptions
   - Handles multiple subscription types (single ticket, vendor tickets, moderation queue)
   - Provides broadcast streams for UI components to listen to changes

2. **Seller Support Screen** (`lib/app/seller/support/support_screen.dart`)
   - Subscribes to all tickets for a specific vendor
   - Updates UI in realtime when ticket status changes
   - Shows notifications for important events (escalations, resolutions)

3. **Admin Moderation Dashboard** (`lib/app/admin/moderation/moderation_dashboard.dart`)
   - Subscribes to entire moderation queue
   - Updates dashboard when tickets are added, modified, or removed
   - Shows notifications for new tickets and assignments

4. **Ticket Detail Dialog** (`lib/app/admin/moderation/ticket_detail_dialog.dart`)
   - Subscribes to a specific ticket for live updates
   - Updates details when status, messages, or moderation changes occur
   - Shows notifications for new messages and status changes

## How It Works

### 1. Service Initialization

```dart
// Create service instance with Supabase client
final realtimeService = TicketRealtimeService(Supabase.instance.client);
```

### 2. Subscription Types

#### Subscribe to Single Ticket
```dart
// Get stream of updates for a specific ticket
final stream = realtimeService.subscribeToTicket(ticketId);

stream.listen((event) {
  if (event.isStatusChange) {
    // Handle status change
  }
  if (event.isNewMessage) {
    // Handle new message
  }
});
```

#### Subscribe to Vendor Tickets
```dart
// Get stream of all ticket updates for a vendor
final stream = realtimeService.subscribeToVendorTickets(vendorId);

stream.listen((event) {
  if (event.isEscalated) {
    // Handle escalation
  }
});
```

#### Subscribe to Moderation Queue
```dart
// Get stream of all moderation queue changes
final stream = realtimeService.subscribeToModerationQueue();

stream.listen((event) {
  if (event.isInsert) {
    // Handle new ticket in queue
  }
  if (event.isAssignmentChange) {
    // Handle ticket assignment
  }
});
```

### 3. Event Types

#### TicketRealtimeEvent
- `eventType`: Type of change ('INSERT', 'UPDATE', 'DELETE', 'new_message', 'moderation_*')
- `ticketId`: ID of the affected ticket
- `status`, `priority`, `escalated`: Updated ticket fields
- `queueStatus`, `assignedAdminId`: Moderation queue fields
- `messageId`, `messageBody`: New message fields

**Helper Properties:**
- `isTicketUpdate`: True for ticket table changes
- `isModerationUpdate`: True for moderation queue changes
- `isNewMessage`: True for new messages
- `isStatusChange`: True when status changed
- `isEscalated`: True when ticket was escalated

#### ModerationQueueRealtimeEvent
- `eventType`: 'INSERT', 'UPDATE', or 'DELETE'
- `queueItemId`: Moderation queue item ID
- `ticketId`: Related ticket ID
- `status`, `priority`, `severity`: Queue item fields

### 4. Cleanup

Always dispose of services and cancel subscriptions:

```dart
@override
void dispose() {
  _realtimeSubscription?.cancel();
  _realtimeService.dispose();
  super.dispose();
}
```

## Database Triggers

The realtime updates are triggered by database changes. Ensure these tables have proper broadcast configuration:

- `support_tickets`: Broadcasts all changes
- `moderation_queue`: Broadcasts all changes
- `ticket_messages`: Broadcasts inserts

## Testing

### 1. Test with Multiple Clients

1. Open the app on two devices/browsers
2. Log in as a seller on one device
3. Log in as an admin on another device
4. Make changes on one device and verify updates appear on the other

### 2. Test Scenarios

**Seller View:**
- Create a new ticket → Admin should see it appear in queue
- Escalate a ticket → Admin should see escalation notification
- Admin resolves ticket → Seller should see status update

**Admin View:**
- Assign ticket to self → Other admins should see assignment
- Add internal note → Notes should update for other admins viewing same ticket
- Change ticket status → Seller should see status change
- Add reply → Seller should see new message

### 3. Test with Supabase CLI

Run the SLA monitor function to trigger status updates:

```powershell
# Start the function locally
supabase functions serve sla-monitor

# Trigger it
Invoke-RestMethod -Uri "http://localhost:54321/functions/v1/sla-monitor" -Method POST
```

## Performance Considerations

### Memory Management
- Service automatically cleans up channels on unsubscribe
- Use broadcast streams to allow multiple listeners
- Dispose of services when screens are closed

### Network Usage
- Realtime uses WebSocket connection (efficient)
- Only subscribed events are received
- Filters applied at database level reduce bandwidth

### Scaling
- Each channel has a unique name to avoid conflicts
- Vendor-specific subscriptions reduce unnecessary updates
- Admins receive all queue updates (use filters to optimize)

## Troubleshooting

### No Updates Received

1. **Check Supabase Realtime Configuration**
   ```sql
   -- Verify realtime is enabled for tables
   SELECT tablename FROM pg_publication_tables 
   WHERE pubname = 'supabase_realtime';
   ```

2. **Check RLS Policies**
   - Users must have SELECT permission on tables
   - Realtime respects RLS policies

3. **Check WebSocket Connection**
   - Verify app is authenticated
   - Check network connectivity
   - Look for connection errors in logs

### Duplicate Events

- Ensure you're not creating multiple subscriptions
- Use `_controllers.containsKey()` check in service
- Dispose of old subscriptions before creating new ones

### Memory Leaks

- Always call `dispose()` on service
- Cancel stream subscriptions in `dispose()`
- Use broadcast streams for multiple listeners

## Best Practices

1. **Subscribe Early**
   - Subscribe in `initState()`
   - Ensures no missed events during screen setup

2. **Dispose Properly**
   - Always dispose in widget `dispose()` method
   - Cancel subscriptions before disposing service

3. **Handle Errors**
   - Wrap event handlers in try-catch
   - Log errors for debugging
   - Show user-friendly error messages

4. **Optimize Updates**
   - Batch UI updates when possible
   - Avoid rebuilding entire screen on every event
   - Use targeted `setState()` calls

5. **User Notifications**
   - Show snackbars for important changes
   - Don't spam users with notifications
   - Use appropriate colors and icons

## Future Enhancements

- [ ] Typing indicators for ticket messages
- [ ] Presence tracking (who's viewing which ticket)
- [ ] Optimistic updates with rollback
- [ ] Offline queue with sync on reconnect
- [ ] Push notifications integration
- [ ] Batch update optimization for high-volume scenarios

## Related Files

- Service: `lib/app/shared/services/ticket_realtime_service.dart`
- Seller UI: `lib/app/seller/support/support_screen.dart`
- Admin Dashboard: `lib/app/admin/moderation/moderation_dashboard.dart`
- Ticket Detail: `lib/app/admin/moderation/ticket_detail_dialog.dart`
- Models: `lib/app/admin/moderation/moderation_models.dart`
- Repository: `lib/app/admin/moderation/moderation_repository.dart`

## References

- [Supabase Realtime Documentation](https://supabase.com/docs/guides/realtime)
- [Flutter StreamController](https://api.flutter.dev/flutter/dart-async/StreamController-class.html)
- [Support & Moderation Guide](./SUPPORT_MODERATION_GUIDE.md)
