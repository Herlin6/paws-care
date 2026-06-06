import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String postId;
  final String userId;
  final String username;
  final String title;
  final String description;
  final String imageBase64;
  final List<String> categories;
  final String animalType;
  final String locationText;
  final String status;
  final DateTime createdAt;
  final double latitude;
  final double longitude;
  final List<String> favoriteBy;
  final List<String> handledBy;
  final String completionProofBase64;
  final String completionNote;
  final String completedByUid;

  /// Backward-compatible getter: returns first category or empty string
  String get category => categories.isNotEmpty ? categories.first : '';

  PostModel({
    required this.postId,
    required this.userId,
    required this.username,
    required this.title,
    required this.description,
    this.imageBase64 = '',
    this.categories = const [],
    this.animalType = '',
    this.locationText = '',
    this.status = 'Butuh Bantuan',
    this.latitude = 0.0,
    this.longitude = 0.0,
    required this.createdAt,
    this.favoriteBy = const [],
    this.handledBy = const [],
    this.completionProofBase64 = '',
    this.completionNote = '',
    this.completedByUid = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'username': username,
      'title': title,
      'description': description,
      'imageBase64': imageBase64,
      'categories': categories,
      'category': category, // backward compat: keep legacy single field
      'animalType': animalType,
      'locationText': locationText,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': Timestamp.fromDate(createdAt),
      'favoriteBy': favoriteBy,
      'handledBy': handledBy,
      'completionProofBase64': completionProofBase64,
      'completionNote': completionNote,
      'completedByUid': completedByUid,
    };
  }

  factory PostModel.fromMap(Map<String, dynamic> map, String docId) {
    // Support both new 'categories' list and legacy single 'category' string
    List<String> cats;
    if (map['categories'] != null && map['categories'] is List) {
      cats = List<String>.from(map['categories']);
    } else if (map['category'] != null &&
        map['category'] is String &&
        (map['category'] as String).isNotEmpty) {
      cats = [map['category'] as String];
    } else {
      cats = [];
    }

    return PostModel(
      postId: docId,
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageBase64: map['imageBase64'] ?? '',
      categories: cats,
      animalType: map['animalType'] ?? '',
      locationText: map['locationText'] ?? '',
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : 0.0,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : 0.0,
      status: map['status'] ?? 'Butuh Bantuan',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      favoriteBy: List<String>.from(map['favoriteBy'] ?? []),
      handledBy: List<String>.from(map['handledBy'] ?? []),
      completionProofBase64: map['completionProofBase64'] ?? '',
      completionNote: map['completionNote'] ?? '',
      completedByUid: map['completedByUid'] ?? '',
    );
  }

  PostModel copyWith({
    String? postId,
    String? userId,
    String? username,
    String? title,
    String? description,
    String? imageBase64,
    List<String>? categories,
    String? animalType,
    String? locationText,
    String? status,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    List<String>? favoriteBy,
    List<String>? handledBy,
    String? completionProofBase64,
    String? completionNote,
    String? completedByUid,
  }) {
    return PostModel(
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      title: title ?? this.title,
      description: description ?? this.description,
      imageBase64: imageBase64 ?? this.imageBase64,
      categories: categories ?? this.categories,
      animalType: animalType ?? this.animalType,
      locationText: locationText ?? this.locationText,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      favoriteBy: favoriteBy ?? this.favoriteBy,
      handledBy: handledBy ?? this.handledBy,
      completionProofBase64:
          completionProofBase64 ?? this.completionProofBase64,
      completionNote: completionNote ?? this.completionNote,
      completedByUid: completedByUid ?? this.completedByUid,
    );
  }
}
