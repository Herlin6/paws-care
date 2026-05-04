import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String username;
  final String email;
  final String password;
  final String phone;
  final String photoBase64;
  final String role; // 'Admin' or 'Pengguna'
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.username,
    required this.email,
    this.password = '',
    this.phone = '',
    this.photoBase64 = '',
    this.role = 'Pengguna',
    required this.createdAt,
  });

  bool get isAdmin => role == 'Admin';

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'email': email,
      'password': password,
      'phone': phone,
      'photoBase64': photoBase64,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      phone: map['phone'] ?? '',
      photoBase64: map['photoBase64'] ?? '',
      role: map['role'] ?? 'Pengguna',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  UserModel copyWith({
    String? uid,
    String? username,
    String? email,
    String? password,
    String? phone,
    String? photoBase64,
    String? role,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      phone: phone ?? this.phone,
      photoBase64: photoBase64 ?? this.photoBase64,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
