# Push Notifications & In-App Alerts - Quick Reference

## Files Modified/Created

### New Files
- ✅ `lib/app/shared/services/push_notification_service.dart` - FCM/APNs integration
- ✅ `lib/app/shared/services/notification_coordinator.dart` - Event coordination
- ✅ `lib/app/shared/widgets/in_app_alert_widget.dart` - UI components
- ✅ `PUSH_NOTIFICATIONS_IMPLEMENTATION.md` - Full documentation

### Modified Files
- ✅ `pubspec.yaml` - Added firebase_core, firebase_messaging, flutter_local_notifications
- ✅ `lib/app/seller/support/support_screen.dart` - Integrated notifications for sellers
- ✅ `lib/app/admin/moderation/moderation_dashboard.dart` - Integrated notifications for admins

## Quick Setup (5 Minutes)

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Firebase Configuration

#### Android
```bash
# Place google-services.json in android/app/
# Add to android/build.gradle.kts:
classpath("com.google.gms:google-services:4.4.0")

# Add to android/app/build.gradle.kts:
plugins {
    id("com.google.gms.google-services")
}
```

#### iOS
```bash
# Place GoogleService-Info.plist in ios/Runner/
# Enable Push Notifications capability in Xcode
# Enable Background Modes > Remote notifications
```

### 3. Initialize in Main App

```dart
// In main.dart or app initialization
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );
  
  runApp(const MyApp());
}
```

## Notification Types

### For Sellers

| Event | Notification Title | Color | Auto-Dismiss |
|-------|-------------------|-------|--------------|
| Moderator Reply | "New Reply on Your Ticket" | Blue | 4s |
| Status Change | "Ticket Status Updated" | Green/Orange | 4s |
| Escalated | "Ticket Escalated" | Orange | 4s |

### For Admins

| Event | Notification Title | Color | Badge | Persistent |
|-------|-------------------|-------|-------|------------|
| New Ticket | "New Ticket in Queue" | Blue | Yes | No |
| Assigned | "Ticket Assigned to You" | Green | No | No |
| SLA Warning | "SLA Warning" | Orange | No | No |
| SLA Breach | "SLA Breached" | Red | Yes | Yes |

## Testing Checklist

### Seller Testing
- [ ] Create ticket
- [ ] Admin replies → Push notification received
- [ ] Admin replies → In-app snackbar shown
- [ ] Tap "View" → Opens ticket detail
- [ ] Status changes → Notification received
- [ ] Escalate ticket → Notification sent

### Admin Testing
- [ ] New ticket created → Push notification
- [ ] New ticket → Badge counter increments
- [ ] Assign ticket → Notification to assigned admin
- [ ] SLA approaching → Warning notification
- [ ] SLA breached → Urgent notification (red)
- [ ] Multiple alerts → Queue properly (no stack)
- [ ] View ticket → Badge clears

### Background Testing
- [ ] App in background → System notification
- [ ] App terminated → System notification
- [ ] Tap notification → Opens to correct ticket
- [ ] App in foreground → Snackbar only (no system notification)

### Platform Testing
- [ ] Android: Notification channel created
- [ ] Android: Permission requested on Android 13+
- [ ] iOS: APNs token received
- [ ] iOS: Badge numbers work
- [ ] Both: Sound/vibration work
- [ ] Both: Deep linking works

## Code Snippets

### Initialize for Seller
```dart
final pushService = PushNotificationService(Supabase.instance.client);
final coordinator = NotificationCoordinator(
  pushService: pushService,
  realtimeService: realtimeService,
  userId: currentUserId,
  isAdmin: false,
);
coordinator.startForSeller(vendorId);
```

### Initialize for Admin
```dart
final pushService = PushNotificationService(Supabase.instance.client);
final coordinator = NotificationCoordinator(
  pushService: pushService,
  realtimeService: realtimeService,
  userId: currentUserId,
  isAdmin: true,
);
coordinator.startForAdmin();
```

### Show In-App Alert
```dart
InAppAlertWidget.showAsSnackbar(
  context,
  InAppAlert(
    type: InAppAlertType.info,
    title: 'New Message',
    message: 'You have a new ticket reply',
    ticketId: ticketId,
    action: InAppAlertAction.viewTicket,
  ),
  onAction: () {
    // Open ticket detail
  },
);
```

### Check Notification Token
```dart
final token = await FirebaseMessaging.instance.getToken();
print('FCM Token: $token');

// Verify in database
final tokens = await supabase
  .from('device_tokens')
  .select()
  .eq('user_id', userId);
```

## Backend Edge Function

Deploy this function to send actual push notifications:

```bash
# Create function
mkdir -p supabase/functions/send-push-notification

# Add code (see full implementation guide)

# Deploy
supabase functions deploy send-push-notification

# Set environment variables
supabase secrets set FCM_SERVER_KEY=your-fcm-key
```

## Troubleshooting

### No Push Notifications
1. Check FCM token exists: `FirebaseMessaging.instance.getToken()`
2. Verify token in database: `SELECT * FROM device_tokens WHERE user_id = ?`
3. Test with FCM Console direct message
4. Check Android/iOS permissions granted

### No In-App Alerts
1. Verify stream subscription active
2. Check `mounted` is true when showing
3. Ensure ScaffoldMessenger in widget tree
4. Check coordinator started (startForSeller/startForAdmin)

### Notifications Stack Up
1. AlertQueue should prevent stacking
2. Check auto-dismiss timing (4 seconds default)
3. Verify only one alert showing at a time
4. Check throttling logic (5-minute window)

### Deep Links Don't Work
1. Verify payload includes `ticket_id`
2. Check `onNotificationTapped` stream listener
3. Ensure ticket exists in local list
4. Verify dialog opens correctly

## Environment Variables Needed

Add to `.env` or Supabase secrets:

```env
# Firebase
FCM_SERVER_KEY=your-fcm-server-key-here
FIREBASE_PROJECT_ID=your-project-id

# Supabase
SUPABASE_URL=your-supabase-url
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

## Production Checklist

- [ ] Firebase project configured (production)
- [ ] APNs certificates uploaded (production)
- [ ] Edge function deployed
- [ ] FCM server key configured
- [ ] Device tokens table has RLS policies
- [ ] Notifications table has RLS policies
- [ ] User preference table created (optional)
- [ ] Throttling limits configured
- [ ] Analytics tracking added (optional)
- [ ] Error monitoring enabled (Sentry, etc.)

## Performance Targets

- **Push Delivery**: < 2 seconds
- **In-App Display**: < 100ms
- **Battery Impact**: < 1% per day
- **Network Usage**: < 1MB per day
- **Memory Usage**: < 10MB overhead

## Support

For issues or questions:
1. Check full implementation guide: `PUSH_NOTIFICATIONS_IMPLEMENTATION.md`
2. Review Firebase Console logs
3. Check Supabase Edge Function logs
4. Enable debug logging in services

## Next Steps

After basic implementation:
1. Add user notification preferences UI
2. Implement rich notifications (images, actions)
3. Add notification history view
4. Set up analytics and monitoring
5. Configure advanced throttling rules
6. Add email/SMS channels
7. Implement notification templates
8. Add localization support
