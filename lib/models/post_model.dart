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
    required this.categories,
    this.animalType = 'Lainnya',
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

  /// Daftar kategori yang tersedia
  static const List<String> availableCategories = [
    'Hilang',
    'Ditemukan',
    'Kecelakaan',
    'Mati',
    'Terjebak',
    'Sakit',
    'Lainnya',
  ];

  /// Daftar jenis hewan yang tersedia
  static const List<String> availableAnimalTypes = [
    'Kucing',
    'Anjing',
    'Burung',
    'Kelinci',
    'Reptil',
    'Lainnya',
  ];

  /// Emoji untuk kategori
  static String categoryEmoji(String category) {
    switch (category) {
      case 'Hilang':
        return '🔍';
      case 'Ditemukan':
        return '📦';
      case 'Kecelakaan':
        return '🚨';
      case 'Mati':
        return '💀';
      case 'Terjebak':
        return '🪤';
      case 'Sakit':
        return '🩹';
      case 'Lainnya':
        return '📋';
      default:
        return '🐾';
    }
  }

  /// Emoji untuk jenis hewan
  static String animalTypeEmoji(String type) {
    switch (type) {
      case 'Kucing':
        return '🐱';
      case 'Anjing':
        return '🐶';
      case 'Burung':
        return '🐦';
      case 'Kelinci':
        return '🐰';
      case 'Reptil':
        return '🦎';
      case 'Lainnya':
        return '🐾';
      default:
        return '🐾';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'username': username,
      'title': title,
      'description': description,
      'imageBase64': imageBase64,
      'categories': categories,
      'animalType': animalType,
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
    // Handle migration: old data may have 'category' as String
    List<String> cats;
    if (map['categories'] != null) {
      cats = List<String>.from(map['categories']);
    } else if (map['category'] != null && map['category'] is String) {
      // Migration from old single-category format
      final oldCat = map['category'] as String;
      cats = oldCat.isNotEmpty ? [oldCat] : ['Lainnya'];
    } else {
      cats = ['Lainnya'];
    }

    return PostModel(
      postId: docId,
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageBase64: map['imageBase64'] ?? '',
      categories: cats,
      animalType: map['animalType'] ?? 'Lainnya',
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
    List<String>? categories,
    String? animalType,
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
      categories: categories ?? this.categories,
      animalType: animalType ?? this.animalType,
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
