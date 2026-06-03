import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String postId;
  final String userId;
  final String username;
  final String title;
  final String description;
  final String imageBase64;
  final String category;
  final String locationText;
  final String locationDetail;
  final double latitude;
  final double longitude;
  final String status;
  final DateTime createdAt;
  final List<String> favoriteBy;
  final List<String> handledBy;
  final String completionProofBase64;
  final String completionNote;
  final String completedByUid;

  PostModel({
    required this.postId,
    required this.userId,
    required this.username,
    required this.title,
    required this.description,
    this.imageBase64 = '',
    required this.category,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.locationText = '',
    this.locationDetail = '',
    this.status = 'Butuh Bantuan',
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
      'category': category,
      'locationText': locationText,
      'locationDetail': locationDetail,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'favoriteBy': favoriteBy,
      'handledBy': handledBy,
      'completionProofBase64': completionProofBase64,
      'completionNote': completionNote,
      'completedByUid': completedByUid,
    };
  }

  factory PostModel.fromMap(Map<String, dynamic> map, String docId) {
    return PostModel(
      postId: docId,
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageBase64: map['imageBase64'] ?? '',
      category: map['category'] ?? '',
      locationText: map['locationText'] ?? '',
      locationDetail: map['locationDetail'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
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
    String? category,
    String? locationText,
    String? locationDetail,
    double? latitude,
    double? longitude,
    String? status,
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
      category: category ?? this.category,
      locationText: locationText ?? this.locationText,
      locationDetail: locationDetail ?? this.locationDetail,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
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
