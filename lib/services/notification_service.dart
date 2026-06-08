import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paws_care/services/fcm_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  StreamSubscription? _postSubscription;

  Future<void> init() async {
    if (_isInitialized) return;

    // Gunakan ikon default Android
    const AndroidInitializationSettings initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: initSettingsAndroid);

    await _notificationsPlugin.initialize(initSettings);

    // Create notification channel for Firestore-based notifications
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'paws_care_channel',
            'Paws Care Notifications',
            description: 'Notifikasi update status laporan',
            importance: Importance.max,
          ),
        );

    _isInitialized = true;

    // Mulai mendengarkan perubahan Firestore
    _startFirestoreListener();
  }

  Future<void> showNotification({required String title, required String body}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'paws_care_channel', // id channel
      'Paws Care Notifications', // nama channel
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    
    await _notificationsPlugin.show(
      DateTime.now().millisecond, // id unik per notifikasi
      title,
      body,
      platformDetails,
    );
  }

  void _startFirestoreListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      // Cancel previous Firestore subscription to prevent memory leaks
      _postSubscription?.cancel();
      _postSubscription = null;

      if (user != null) {
        // Pantau post milik user yang sedang login
        bool isFirstSnapshot = true;
        _postSubscription = FirebaseFirestore.instance
            .collection('posts')
            .where('userId', isEqualTo: user.uid)
            .snapshots()
            .listen((snapshot) {
          // Skip the initial snapshot (contains all existing docs as "added")
          if (isFirstSnapshot) {
            isFirstSnapshot = false;
            return;
          }

          // Skip snapshots served from cache (e.g. on reconnection)
          if (snapshot.metadata.isFromCache) return;

          for (var change in snapshot.docChanges) {
            // Hanya trigger notifikasi jika ada modifikasi
            if (change.type == DocumentChangeType.modified) {
              final data = change.doc.data();
              if (data != null) {
                // Jangan notifikasi jika yang update adalah pemilik sendiri
                final updatedByUid = data['updatedByUid'] as String?;
                if (updatedByUid == user.uid) continue;

                // Cek preferensi notifikasi
                FcmService().getNotificationPreferences(user.uid).then((prefs) {
                  final bool enabled = prefs['enabled'] ?? true;
                  if (!enabled) return;

                  final status = data['status'] ?? '';
                  final title = data['title'] ?? 'Laporan';
                  showNotification(
                    title: 'Update Laporan: $title',
                    body: 'Status laporan Anda berubah menjadi: $status',
                  );
                });
              }
            }
          }
        });
      }
    });
  }
}
