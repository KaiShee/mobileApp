import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  final String id;
  final String userId;
  final String hotelId;
  final String roomTypeId;
  final Timestamp checkInDate;
  final Timestamp checkOutDate;
  final num totalAmount;
  final num? discountAmount;
  final String status;
  final bool isPaid;
  final String? paymentMethod;
  final String? paymentId;
  final Timestamp createdAt;
  final Timestamp? updatedAt;
  
  // Additional fields for hotel and room details
  final String? hotelName;
  final String? hotelImage;
  final String? roomName;
  final String? roomDescription;
  final String? roomImage;
  final List<dynamic>? roomAmenities;
  final int? quantity;
  final int? numberOfNights;

  BookingModel({
    required this.id,
    required this.userId,
    required this.hotelId,
    required this.roomTypeId,
    required this.checkInDate,
    required this.checkOutDate,
    required this.totalAmount,
    this.discountAmount,
    required this.status,
    required this.isPaid,
    this.paymentMethod,
    this.paymentId,
    required this.createdAt,
    this.updatedAt,
    this.hotelName,
    this.hotelImage,
    this.roomName,
    this.roomDescription,
    this.roomImage,
    this.roomAmenities,
    this.quantity,
    this.numberOfNights,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'hotelId': hotelId,
      'roomTypeId': roomTypeId,
      'checkInDate': checkInDate,
      'checkOutDate': checkOutDate,
      'totalAmount': totalAmount,
      'discountAmount': discountAmount,
      'status': status,
      'isPaid': isPaid,
      'paymentMethod': paymentMethod,
      'paymentId': paymentId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'hotelName': hotelName,
      'hotelImage': hotelImage,
      'roomName': roomName,
      'roomDescription': roomDescription,
      'roomImage': roomImage,
      'roomAmenities': roomAmenities,
      'quantity': quantity,
      'numberOfNights': numberOfNights,
    };
  }

  factory BookingModel.fromMap(Map<String, dynamic> map) {
    return BookingModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      hotelId: map['hotelId'] ?? '',
      roomTypeId: map['roomTypeId'] ?? '',
      checkInDate: map['checkInDate'] as Timestamp,
      checkOutDate: map['checkOutDate'] as Timestamp,
      totalAmount: map['totalAmount'] ?? 0,
      discountAmount: map['discountAmount'],
      status: map['status'] ?? 'pending',
      isPaid: map['isPaid'] ?? false,
      paymentMethod: map['paymentMethod'],
      paymentId: map['paymentId'],
      createdAt: map['createdAt'] as Timestamp,
      updatedAt: map['updatedAt'] as Timestamp?,
      hotelName: map['hotelName'],
      hotelImage: map['hotelImage'],
      roomName: map['roomName'],
      roomDescription: map['roomDescription'],
      roomImage: map['roomImage'],
      roomAmenities: map['roomAmenities'],
      quantity: map['quantity'],
      numberOfNights: map['numberOfNights'],
    );
  }

  String toJson() => json.encode(toMap());

  factory BookingModel.fromJson(String source) =>
      BookingModel.fromMap(json.decode(source));

  BookingModel copyWith({
    String? id,
    String? userId,
    String? hotelId,
    String? roomTypeId,
    Timestamp? checkInDate,
    Timestamp? checkOutDate,
    num? totalAmount,
    num? discountAmount,
    String? status,
    bool? isPaid,
    String? paymentMethod,
    String? paymentId,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    String? hotelName,
    String? hotelImage,
    String? roomName,
    String? roomDescription,
    String? roomImage,
    List<dynamic>? roomAmenities,
    int? quantity,
    int? numberOfNights,
  }) {
    return BookingModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      hotelId: hotelId ?? this.hotelId,
      roomTypeId: roomTypeId ?? this.roomTypeId,
      checkInDate: checkInDate ?? this.checkInDate,
      checkOutDate: checkOutDate ?? this.checkOutDate,
      totalAmount: totalAmount ?? this.totalAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      status: status ?? this.status,
      isPaid: isPaid ?? this.isPaid,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentId: paymentId ?? this.paymentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hotelName: hotelName ?? this.hotelName,
      hotelImage: hotelImage ?? this.hotelImage,
      roomName: roomName ?? this.roomName,
      roomDescription: roomDescription ?? this.roomDescription,
      roomImage: roomImage ?? this.roomImage,
      roomAmenities: roomAmenities ?? this.roomAmenities,
      quantity: quantity ?? this.quantity,
      numberOfNights: numberOfNights ?? this.numberOfNights,
    );
  }
} 