import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service untuk berkomunikasi dengan backend notifikasi REST API
class NotificationApiService {
  static final NotificationApiService _instance =
      NotificationApiService._internal();
  factory NotificationApiService() => _instance;
  NotificationApiService._internal();

  static const String _baseUrl = 'https://paws-care-rest-api.vercel.app';

  /// Send notification to a specific device token
  Future<bool> sendNotification({
    required String token,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/send-notification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'title': title,
          'body': body,
          if (data != null) 'data': data,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Send multicast notification to multiple device tokens
  Future<bool> sendMulticastNotification({
    required List<String> tokens,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/send-multicast'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tokens': tokens,
          'title': title,
          'body': body,
          if (data != null) 'data': data,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Send notification to a FCM topic
  Future<bool> sendToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/send-to-topic'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'topic': topic,
          'title': title,
          'body': body,
          if (data != null) 'data': data,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Subscribe a token to a topic via backend
  Future<bool> subscribeTopic({
    required String token,
    required String topic,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/subscribe-to-topic'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'topic': topic,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Unsubscribe a token from a topic via backend
  Future<bool> unsubscribeTopic({
    required String token,
    required String topic,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/unsubscribe-from-topic'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'topic': topic,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
