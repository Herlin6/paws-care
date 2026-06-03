import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    // Gunakan ikon default Android
    const AndroidInitializationSettings initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: initSettingsAndroid);

    await _notificationsPlugin.initialize(initSettings);
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
      if (user != null) {
        // Pantau post milik user yang sedang login
        FirebaseFirestore.instance
            .collection('posts')
            .where('userId', isEqualTo: user.uid)
            .snapshots()
            .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            // Hanya trigger notifikasi jika ada modifikasi
            if (change.type == DocumentChangeType.modified) {
              final data = change.doc.data();
              if (data != null) {
                final status = data['status'] ?? '';
                final title = data['title'] ?? 'Laporan';
                showNotification(
                  title: 'Update Laporan: $title',
                  body: 'Status laporan Anda berubah menjadi: $status',
                );
              }
            }
          }
        });
      }
    });
  }
}
