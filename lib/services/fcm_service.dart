import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paws_care/models/post_model.dart';

/// Top-level function for handling background FCM messages.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are automatically shown as system notifications
  // by FCM on Android. No extra handling needed here.
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _isInitialized = false;
  String? _currentToken;

  String? get currentToken => _currentToken;

  /// Initialize FCM: request permission, get token, setup listeners
  Future<void> init() async {
    if (_isInitialized) return;

    // Request notification permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    // Setup local notifications for foreground messages (Android only)
    if (!kIsWeb) {
      await _setupLocalNotifications();
    }

    // Get FCM token
    try {
      if (kIsWeb) {
        _currentToken = await _messaging.getToken();
      } else {
        _currentToken = await _messaging.getToken();
      }

      print('FCM TOKEN: $_currentToken');
    } catch (e) {
      print('FCM ERROR: $e');
    }

    if (_currentToken != null) {
      await _saveTokenToFirestore(_currentToken!);
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _currentToken = newToken;
      _saveTokenToFirestore(newToken);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle message opened app (user tapped notification while in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // NOTE: onBackgroundMessage is registered in main.dart (top-level requirement).
    // Do NOT register it here again to avoid duplicate handling.

    _isInitialized = true;
  }

  /// Setup Flutter Local Notifications for foreground display
  Future<void> _setupLocalNotifications() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'paws_care_fcm_channel',
      'Paws Care FCM Notifications',
      description: 'Notifikasi dari Paws & Care',
      importance: Importance.max,
      playSound: true,
    );

    // Create the channel on Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(initSettings);
  }

  /// Save FCM token to Firestore users collection
  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _db.collection('users').doc(user.uid).update({
        'fcmToken': token,
      }).catchError((_) {
        // If document doesn't exist yet, set will be called later
      });
    }
  }

  /// Save token for a specific user (called after login)
  Future<void> saveTokenForUser(String uid) async {
    if (_currentToken != null) {
      await _db.collection('users').doc(uid).update({
        'fcmToken': _currentToken,
      }).catchError((_) {});
    }
  }

  /// Clear FCM token for a user (called on logout)
  Future<void> clearTokenForUser(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'fcmToken': '',
      });
    } catch (_) {
      // Ignore errors during token cleanup
    }
  }

  /// Handle foreground FCM message — show local notification
  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    // On Web, the browser handles foreground notifications natively.
    if (kIsWeb) return;

    _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification.title ?? 'Paws & Care',
      notification.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'paws_care_fcm_channel',
          'Paws Care FCM Notifications',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: message.data['postId'],
    );
  }

  /// Handle message opened app (user tapped notification)
  void _handleMessageOpenedApp(RemoteMessage message) {
    // Navigation can be handled here if needed in the future
  }

  // ============================================================
  // TOPIC MANAGEMENT
  // ============================================================

  /// Subscribe to a FCM topic
  Future<void> subscribeToTopic(String topic) async {
    final sanitized = _sanitizeTopicName(topic);
    try {
      await _messaging.subscribeToTopic(sanitized);
    } catch (e) {
      // subscribeToTopic is not supported on Web — ignore gracefully
    }
  }

  /// Unsubscribe from a FCM topic
  Future<void> unsubscribeFromTopic(String topic) async {
    final sanitized = _sanitizeTopicName(topic);
    try {
      await _messaging.unsubscribeFromTopic(sanitized);
    } catch (e) {
      // unsubscribeFromTopic is not supported on Web — ignore gracefully
    }
  }

  /// Sanitize topic name: FCM topics must match [a-zA-Z0-9-_.~%]+
  String _sanitizeTopicName(String topic) {
    return topic
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9\-_.~%]'), '');
  }

  // ============================================================
  // NOTIFICATION PREFERENCES
  // ============================================================

  /// Save notification preferences to Firestore
  Future<void> saveNotificationPreferences({
    required String uid,
    required Map<String, dynamic> prefs,
  }) async {
    await _db.collection('users').doc(uid).update({
      'notificationPrefs': prefs,
    });
  }

  /// Get notification preferences from Firestore
  Future<Map<String, dynamic>> getNotificationPreferences(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists && doc.data()!.containsKey('notificationPrefs')) {
      return Map<String, dynamic>.from(doc.data()!['notificationPrefs']);
    }
    return _defaultPreferences();
  }

  /// Default notification preferences
  Map<String, dynamic> _defaultPreferences() {
    return {
      'enabled': true,
      'receiveAll': true,
      'categories': <String>[],
      'animalTypes': <String>[],
      'commentOnOwnPost': true,
      'commentOnVolunteerPost': true,
    };
  }

  /// Sync topic subscriptions based on preferences.
  /// Uses PostModel.availableCategories and PostModel.availableAnimalTypes
  /// as the single source of truth (no hardcoded lists).
  Future<void> syncTopicSubscriptions(Map<String, dynamic> prefs) async {
    final bool enabled = prefs['enabled'] ?? true;
    final bool receiveAll = prefs['receiveAll'] ?? true;
    final List<String> categories =
        List<String>.from(prefs['categories'] ?? []);
    final List<String> animalTypes =
        List<String>.from(prefs['animalTypes'] ?? []);

    // Use PostModel as single source of truth
    final allCategories = PostModel.availableCategories;
    final allAnimalTypes = PostModel.availableAnimalTypes;

    if (!enabled) {
      // Unsubscribe from all topics
      for (final cat in allCategories) {
        await unsubscribeFromTopic('category_$cat');
      }
      for (final type in allAnimalTypes) {
        await unsubscribeFromTopic('animal_$type');
      }
      return;
    }

    if (receiveAll) {
      // Subscribe to all topics
      for (final cat in allCategories) {
        await subscribeToTopic('category_$cat');
      }
      for (final type in allAnimalTypes) {
        await subscribeToTopic('animal_$type');
      }
    } else {
      // Subscribe/unsubscribe based on selections
      for (final cat in allCategories) {
        if (categories.contains(cat)) {
          await subscribeToTopic('category_$cat');
        } else {
          await unsubscribeFromTopic('category_$cat');
        }
      }
      for (final type in allAnimalTypes) {
        if (animalTypes.contains(type)) {
          await subscribeToTopic('animal_$type');
        } else {
          await unsubscribeFromTopic('animal_$type');
        }
      }
    }
  }

  /// Sync preferences for a user after login.
  /// Loads stored preferences from Firestore and subscribes to topics accordingly.
  Future<void> syncPreferencesForUser(String uid) async {
    try {
      final prefs = await getNotificationPreferences(uid);
      await syncTopicSubscriptions(prefs);
    } catch (_) {
      // If no preferences exist yet, subscribe to all by default
      await syncTopicSubscriptions(_defaultPreferences());
    }
  }
}
