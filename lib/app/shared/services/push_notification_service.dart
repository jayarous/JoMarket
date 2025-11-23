import 'dart:async';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';

/// Service for managing push notifications via Firebase Cloud Messaging (FCM)
/// and Apple Push Notification Service (APNs)
class PushNotificationService {
  PushNotificationService(this._client);

  static final Logger _logger = Logger('PushNotificationService');

  final SupabaseClient _client;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final _notificationStreamController =
      StreamController<NotificationPayload>.broadcast();

  /// Stream of notification payloads when user taps on a notification
  Stream<NotificationPayload> get onNotificationTapped =>
      _notificationStreamController.stream;

  bool _initialized = false;
  String? _currentDeviceToken;

  /// Initialize push notification service
  /// Should be called during app startup after authentication
  Future<void> initialize({
    required String userId,
    required Function(NotificationPayload) onNotificationReceived,
  }) async {
    if (_initialized) return;

    try {
      // Request notification permissions
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        _logger.warning('Push notification permission denied');
        return;
      }

      // Initialize local notifications for foreground display
      if (!kIsWeb) {
        await _initializeLocalNotifications();
      }

      // Get FCM token
      _currentDeviceToken = await _firebaseMessaging.getToken();
      if (_currentDeviceToken != null) {
        await _saveDeviceToken(userId, _currentDeviceToken!);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _currentDeviceToken = newToken;
        _saveDeviceToken(userId, newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleForegroundMessage(message, onNotificationReceived);
      });

      // Handle background message taps
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationTap(message);
      });

      // Check if app was opened from a terminated state via notification
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      _initialized = true;
      _logger.info('Push notification service initialized');
    } catch (e) {
      _logger.severe('Error initializing push notifications: $e');
      rethrow;
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          _notificationStreamController.add(
            NotificationPayload.fromJson(details.payload!),
          );
        }
      },
    );
  }

  Future<void> _saveDeviceToken(String userId, String token) async {
    try {
      // Upsert device token in database
      await _client.from('device_tokens').upsert({
        'user_id': userId,
        'provider': 'fcm',
        'token': token,
        'platform': _getPlatform(),
        'last_seen': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,token');

      _logger.info('Device token saved: $token');
    } catch (e) {
      _logger.severe('Error saving device token: $e');
    }
  }

  /// Remove the current device token for a given user from the database.
  /// This should be called on sign-out to avoid leaving stale tokens.
  Future<void> removeDeviceToken(String userId) async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token == null) return;

      await _client
          .from('device_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('token', token)
          .eq('provider', 'fcm');

      _logger.info('Device token removed: $token');
    } catch (e) {
      _logger.severe('Error removing device token: $e');
    }
  }

  String _getPlatform() {
    if (kIsWeb) {
      return 'web';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  void _handleForegroundMessage(
    RemoteMessage message,
    Function(NotificationPayload) onNotificationReceived,
  ) {
    final payload = NotificationPayload.fromRemoteMessage(message);

    // Show local notification
    _showLocalNotification(
      title: message.notification?.title ?? 'Notification',
      body: message.notification?.body ?? '',
      payload: payload,
    );

    // Notify the app
    onNotificationReceived(payload);
  }

  void _handleNotificationTap(RemoteMessage message) {
    final payload = NotificationPayload.fromRemoteMessage(message);
    _notificationStreamController.add(payload);
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required NotificationPayload payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'support_tickets',
      'Support Tickets',
      channelDescription: 'Notifications for support ticket updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      payload.hashCode,
      title,
      body,
      details,
      payload: payload.toJson(),
    );
  }

  /// Send a push notification to a specific user
  /// This creates a notification record and triggers the backend function to send FCM messages
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? payload,
  }) async {
    try {
      await _client.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'type': type,
        'channel': 'push',
        'payload': payload ?? {},
        'delivered': false,
      });

      // Trigger backend function to send FCM messages
      await _client.functions.invoke(
        'send-push-notification',
        body: {
          'userId': userId,
          'title': title,
          'body': body,
          'payload': payload ?? {},
        },
      );

      _logger.info('Notification sent to user: $userId');
    } catch (e) {
      _logger.severe('Error sending notification: $e');
    }
  }

  /// Check if user has specific notification preferences enabled
  Future<bool> shouldNotifyUser({
    required String userId,
    required NotificationType type,
  }) async {
    try {
      final response = await _client
          .from('user_notification_preferences')
          .select('enabled')
          .eq('user_id', userId)
          .eq('notification_type', type.name)
          .limit(1)
          .maybeSingle();

      // If no preference record exists, default to enabled (true)
      return response?['enabled'] ?? true;
    } catch (e) {
      _logger.severe('Error checking notification preferences: $e');
      // On error, default to enabled to ensure notifications aren't blocked
      return true;
    }
  }

  /// Throttle notifications to prevent spam
  /// Returns true if notification should be sent, false if throttled
  Future<bool> shouldThrottleNotification({
    required String userId,
    required String ticketId,
    required NotificationType type,
  }) async {
    try {
      // Check if we sent a similar notification recently
      final recentNotifications = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('type', type.name)
          .gte(
            'created_at',
            DateTime.now()
                .subtract(const Duration(minutes: 5))
                .toIso8601String(),
          )
          .like('payload->ticket_id', '%$ticketId%');

      // Don't send if we sent similar notification in last 5 minutes
      return recentNotifications.isNotEmpty;
    } catch (e) {
      _logger.severe('Error checking notification throttle: $e');
      return false;
    }
  }

  /// Clean up resources
  void dispose() {
    _notificationStreamController.close();
  }
}

/// Notification payload structure
class NotificationPayload {
  const NotificationPayload({
    required this.type,
    this.ticketId,
    this.status,
    this.message,
    this.priority,
    this.data,
  });

  final NotificationType type;
  final String? ticketId;
  final String? status;
  final String? message;
  final String? priority;
  final Map<String, dynamic>? data;

  factory NotificationPayload.fromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    return NotificationPayload(
      type: NotificationType.fromString(data['type'] as String? ?? 'unknown'),
      ticketId: data['ticket_id'] as String?,
      status: data['status'] as String?,
      message: data['message'] as String?,
      priority: data['priority'] as String?,
      data: data,
    );
  }

  factory NotificationPayload.fromJson(String json) {
    // Simple JSON parsing - in production use proper JSON decoding
    final parts = json.split('|');
    return NotificationPayload(
      type: NotificationType.fromString(parts[0]),
      ticketId: parts.length > 1 ? parts[1] : null,
      status: parts.length > 2 ? parts[2] : null,
      message: parts.length > 3 ? parts[3] : null,
    );
  }

  String toJson() {
    return '${type.name}|${ticketId ?? ''}|${status ?? ''}|${message ?? ''}';
  }
}

/// Types of notifications
enum NotificationType {
  ticketReply,
  ticketStatusChange,
  ticketEscalated,
  ticketAssigned,
  newTicket,
  slaWarning,
  slaBreached,
  unknown;

  static NotificationType fromString(String value) {
    switch (value) {
      case 'ticket_reply':
        return ticketReply;
      case 'ticket_status_change':
        return ticketStatusChange;
      case 'ticket_escalated':
        return ticketEscalated;
      case 'ticket_assigned':
        return ticketAssigned;
      case 'new_ticket':
        return newTicket;
      case 'sla_warning':
        return slaWarning;
      case 'sla_breached':
        return slaBreached;
      default:
        return unknown;
    }
  }
}

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final logger = Logger('FirebaseMessagingBackgroundHandler');
  logger.info('Background message received: ${message.messageId}');
  // Handle background message if needed
}
