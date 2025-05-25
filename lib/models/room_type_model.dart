import 'package:cloud_firestore/cloud_firestore.dart';

class RoomTypeModel {
  final String id;
  final String hotelId;
  final String name;
  final String description;
  final double price;
  final String image;
  final int floorNumber;
  final String roomNumber;
  final bool isActive;
  final int createdAt;
  final int updatedAt;

  RoomTypeModel({
    required this.id,
    required this.hotelId,
    required this.name,
    required this.description,
    required this.price,
    required this.image,
    required this.floorNumber,
    required this.roomNumber,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hotelId': hotelId,
      'name': name,
      'description': description,
      'price': price,
      'image': image,
      'floorNumber': floorNumber,
      'roomNumber': roomNumber,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory RoomTypeModel.fromMap(Map<String, dynamic> map) {
    return RoomTypeModel(
      id: map['id'] ?? '',
      hotelId: map['hotelId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      image: map['image'] ?? '',
      floorNumber: map['floorNumber'] ?? 0,
      roomNumber: map['roomNumber'] ?? '',
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] ?? 0,
      updatedAt: map['updatedAt'] ?? 0,
    );
  }
} 