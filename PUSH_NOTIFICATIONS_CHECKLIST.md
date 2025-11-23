# Push Notifications - Implementation Checklist

Use this checklist to implement and deploy the push notification system.

## Phase 1: Dependencies & Setup ✅

- [x] Add firebase_core to pubspec.yaml
- [x] Add firebase_messaging to pubspec.yaml  
- [x] Add flutter_local_notifications to pubspec.yaml
- [ ] Run `flutter pub get`
- [ ] Verify no dependency conflicts

## Phase 2: Firebase Configuration 🔧

### Create Firebase Project
- [ ] Go to https://console.firebase.google.com
- [ ] Create new project or select existing
- [ ] Enable Google Analytics (optional)
- [ ] Note project ID: _________________

### Android Setup
- [ ] Add Android app to Firebase project
- [ ] Download google-services.json
- [ ] Place in `android/app/google-services.json`
- [ ] Update `android/build.gradle.kts`:
  - [ ] Add classpath("com.google.gms:google-services:4.4.0")
- [ ] Update `android/app/build.gradle.kts`:
  - [ ] Add plugin: id("com.google.gms.google-services")
  - [ ] Add dependency: implementation("com.google.firebase:firebase-messaging:23.4.0")
- [ ] Update `android/app/src/main/AndroidManifest.xml`:
  - [ ] Add POST_NOTIFICATIONS permission
  - [ ] Add FirebaseMessagingService
- [ ] Test Android build: `flutter build apk`

### iOS Setup
- [ ] Add iOS app to Firebase project
- [ ] Download GoogleService-Info.plist
- [ ] Add to `ios/Runner/GoogleService-Info.plist`
- [ ] Open `ios/Runner.xcworkspace` in Xcode
- [ ] Select Runner target → Signing & Capabilities
- [ ] Add "Push Notifications" capability
- [ ] Add "Background Modes" capability
  - [ ] Check "Remote notifications"
- [ ] Update `ios/Runner/AppDelegate.swift`:
  - [ ] Import Firebase modules
  - [ ] Configure Firebase in didFinishLaunchingWithOptions
- [ ] Generate APNs key in Apple Developer Portal
- [ ] Upload APNs key to Firebase Console
- [ ] Test iOS build: `flutter build ios`

## Phase 3: Backend Setup 🖥️

### Supabase Edge Function
- [ ] Create function directory: `mkdir -p supabase/functions/send-push-notification`
- [ ] Copy edge function code (see PUSH_NOTIFICATIONS_IMPLEMENTATION.md)
- [ ] Install Supabase CLI: `npm install -g supabase`
- [ ] Login: `supabase login`
- [ ] Deploy function: `supabase functions deploy send-push-notification`
- [ ] Get FCM Server Key from Firebase Console
- [ ] Set secret: `supabase secrets set FCM_SERVER_KEY=your-key-here`
- [ ] Test function with curl/Postman
- [ ] Verify function logs: `supabase functions logs send-push-notification`

### Database Trigger (Optional)
- [ ] Create trigger function (see implementation guide)
- [ ] Test trigger by inserting notification record
- [ ] Verify push sent to device

## Phase 4: Code Integration ✅

### Main App Initialization
- [ ] Update `lib/main.dart`:
  - [ ] Import firebase_core
  - [ ] Import firebase_initializer
  - [ ] Add Firebase.initializeApp() in main()
  - [ ] Register background message handler
- [ ] Test app launches without errors

### Auth Wrapper Integration
- [ ] Create/update auth wrapper
- [ ] Request notification permissions after login
- [ ] Initialize PushNotificationService
- [ ] Test permission dialog shows
- [ ] Verify FCM token obtained and logged

### Seller Support Screen
- [ ] Already integrated in support_screen.dart ✅
- [ ] Initialize NotificationCoordinator
- [ ] Start coordinator for seller: startForSeller(vendorId)
- [ ] Listen to inAppAlerts stream
- [ ] Handle notification taps
- [ ] Test notifications display

### Admin Dashboard
- [ ] Already integrated in moderation_dashboard.dart ✅
- [ ] Initialize NotificationCoordinator
- [ ] Start coordinator for admin: startForAdmin()
- [ ] Add badge counter to app bar
- [ ] Show persistent alerts for SLA breaches
- [ ] Test notifications display

## Phase 5: Testing 🧪

### Permission Testing
- [ ] Fresh install shows permission dialog
- [ ] Accepting permission enables notifications
- [ ] Denying permission disables notifications
- [ ] Permission can be changed in device settings

### Seller Flow Testing
- [ ] Create support ticket
- [ ] Admin replies → Seller receives push notification
- [ ] Admin replies → Seller sees in-app snackbar
- [ ] Snackbar shows correct ticket ID
- [ ] "View" button opens correct ticket
- [ ] Snackbar auto-dismisses after 4 seconds
- [ ] Status change → Notification received
- [ ] Escalation → Notification received

### Admin Flow Testing
- [ ] New ticket created → Admin receives push notification
- [ ] New ticket → Badge counter increments
- [ ] New ticket → In-app snackbar shown
- [ ] Assign ticket → Assigned admin receives notification
- [ ] SLA warning → Notification 30 min before deadline
- [ ] SLA breach → Urgent notification with persistent alert
- [ ] View ticket → Badge counter clears

### Background Testing
- [ ] App in foreground → In-app snackbar only
- [ ] App in background → System notification shown
- [ ] App terminated → System notification shown
- [ ] Tap notification → Opens app to correct ticket
- [ ] Notification sound plays
- [ ] Notification vibration works

### Edge Cases
- [ ] Multiple rapid notifications → Throttled correctly
- [ ] Similar notifications → Queued, shown one at a time
- [ ] Network offline → Notifications queued and sent when online
- [ ] Low battery → Notifications still received
- [ ] Do Not Disturb mode → Critical alerts override (iOS)

### Platform-Specific Testing
#### Android
- [ ] Notification channel created ("Support Tickets")
- [ ] Channel settings editable in system settings
- [ ] Notifications on Android 13+ work
- [ ] Battery optimization doesn't break notifications
- [ ] Sound and vibration customizable

#### iOS
- [ ] APNs token received
- [ ] Badge numbers work correctly
- [ ] Critical alerts bypass Do Not Disturb
- [ ] Notification grouping works
- [ ] Sound and haptics work

## Phase 6: Production Deployment 🚀

### Pre-Deployment Checklist
- [ ] All tests passing
- [ ] Firebase project in production mode
- [ ] APNs production certificates configured
- [ ] Edge function deployed to production
- [ ] Environment variables set (FCM_SERVER_KEY)
- [ ] Error monitoring enabled (Sentry, etc.)
- [ ] Analytics tracking configured (optional)

### Deployment Steps
- [ ] Build production Android APK/AAB
- [ ] Test on real Android devices
- [ ] Build production iOS IPA
- [ ] Test on real iOS devices
- [ ] Submit to Play Store (if applicable)
- [ ] Submit to App Store (if applicable)

### Post-Deployment Monitoring
- [ ] Monitor FCM console for delivery metrics
- [ ] Check Supabase logs for edge function errors
- [ ] Monitor device_tokens table growth
- [ ] Track notification open rates
- [ ] Monitor battery usage reports
- [ ] Collect user feedback

## Phase 7: Optional Enhancements 🎁

### User Preferences
- [ ] Create notification_preferences table
- [ ] Add preferences UI screen
- [ ] Allow users to enable/disable types
- [ ] Allow channel selection (push/email/in-app)
- [ ] Add quiet hours configuration

### Rich Notifications
- [ ] Add images to notifications
- [ ] Add action buttons (Reply, Dismiss, etc.)
- [ ] Implement inline reply (Android)
- [ ] Add notification grouping

### Analytics
- [ ] Track notification delivery rate
- [ ] Track notification open rate
- [ ] Track action button clicks
- [ ] A/B test notification copy
- [ ] Monitor user engagement

### Advanced Features
- [ ] Add notification history view
- [ ] Implement email notifications
- [ ] Add SMS notifications (Twilio)
- [ ] Create notification templates
- [ ] Add localization support
- [ ] Implement smart notification batching

## Phase 8: Documentation 📚

- [x] Implementation guide created ✅
- [x] Quick reference guide created ✅
- [x] Integration examples created ✅
- [x] Summary document created ✅
- [ ] Update main README.md
- [ ] Add API documentation
- [ ] Create troubleshooting FAQ
- [ ] Record demo video (optional)

## Troubleshooting Reference

### If notifications not received:
1. Check FCM token exists: `await FirebaseMessaging.instance.getToken()`
2. Verify token in database: Query device_tokens table
3. Test with FCM Console direct message
4. Check Android/iOS permissions granted
5. Verify edge function logs for errors
6. Check network connectivity

### If in-app alerts not showing:
1. Verify stream subscription active
2. Check `mounted` is true
3. Ensure ScaffoldMessenger in widget tree
4. Verify coordinator started (startForSeller/startForAdmin)
5. Check console for errors

### If deep links don't work:
1. Verify payload includes ticket_id
2. Check onNotificationTapped listener
3. Ensure ticket exists in local list
4. Verify navigation context available

## Sign-Off ✍️

### Development
- [ ] Code reviewed
- [ ] All features implemented
- [ ] All tests passing
- [ ] Documentation complete

**Developer:** ________________  **Date:** __________

### QA Testing
- [ ] All test cases executed
- [ ] Edge cases verified
- [ ] Platform-specific testing complete
- [ ] No blocking issues

**QA Lead:** ________________  **Date:** __________

### Deployment
- [ ] Production environment configured
- [ ] Deployment successful
- [ ] Post-deployment monitoring active
- [ ] Rollback plan ready

**DevOps:** ________________  **Date:** __________

---

**Project:** JoMarket Push Notifications  
**Version:** 1.0.0  
**Last Updated:** November 14, 2025
