import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String name;
  final String phoneNumber;
  final String? profileImageUrl;
  final String? localProfileImagePath;
  final bool isAdmin;
  final List<String> bookingHistory;
  final DateTime createdAt;
  final DateTime lastLogin;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.phoneNumber,
    this.profileImageUrl,
    this.localProfileImagePath,
    this.isAdmin = false,
    this.bookingHistory = const [],
    required this.createdAt,
    required this.lastLogin,
  });

  // Convert a UserModel instance to a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'localProfileImagePath': localProfileImagePath,
      'isAdmin': isAdmin,
      'bookingHistory': bookingHistory,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLogin': Timestamp.fromDate(lastLogin),
    };
  }

  // Create a UserModel instance from a Map
  factory UserModel.fromMap(Map<String, dynamic> map) {
    try {
      return UserModel(
        id: map['id'] ?? '',
        email: map['email'] ?? '',
        name: map['name'] ?? '',
        phoneNumber: map['phoneNumber'] ?? '',
        profileImageUrl: map['profileImageUrl'],
        localProfileImagePath: map['localProfileImagePath'],
        isAdmin: map['isAdmin'] ?? false,
        bookingHistory: List<String>.from(map['bookingHistory'] ?? []),
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        lastLogin: (map['lastLogin'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    } catch (e) {
      print('Error in UserModel.fromMap: $e');
      // If there's an error, create a default user with current timestamp
      return UserModel(
        id: map['id'] ?? '',
        email: map['email'] ?? '',
        name: map['name'] ?? '',
        phoneNumber: map['phoneNumber'] ?? '',
        profileImageUrl: map['profileImageUrl'],
        localProfileImagePath: map['localProfileImagePath'],
        isAdmin: map['isAdmin'] ?? false,
        bookingHistory: List<String>.from(map['bookingHistory'] ?? []),
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );
    }
  }

  // Convert UserModel instance to a JSON string
  String toJson() => json.encode(toMap());

  // Create a UserModel instance from a JSON string
  factory UserModel.fromJson(String source) => UserModel.fromMap(json.decode(source));

  // Create a copy of UserModel with some fields potentially changed
  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? phoneNumber,
    String? profileImageUrl,
    String? localProfileImagePath,
    bool? isAdmin,
    List<String>? bookingHistory,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      localProfileImagePath: localProfileImagePath ?? this.localProfileImagePath,
      isAdmin: isAdmin ?? this.isAdmin,
      bookingHistory: bookingHistory ?? this.bookingHistory,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
} 