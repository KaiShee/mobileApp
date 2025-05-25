import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

enum DiscountType {
  percentage,
  fixedAmount,
}

class DiscountModel {
  final String id;
  final String code;
  final String description;
  final num rate;
  final num limit;
  final num used;
  final Timestamp expiry;
  final bool isActive;
  final dynamic createdAt;

  DiscountModel({
    required this.id,
    required this.code,
    required this.description,
    required this.rate,
    required this.limit,
    required this.used,
    required this.expiry,
    required this.isActive,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'description': description,
      'rate': rate,
      'limit': limit,
      'used': used,
      'expiry': expiry,
      'isActive': isActive,
      'createdAt': createdAt,
    };
  }

  factory DiscountModel.fromMap(Map<String, dynamic> map) {
    return DiscountModel(
      id: map['id'] ?? '',
      code: map['code'] ?? '',
      description: map['description'] ?? '',
      rate: map['rate'] ?? 0,
      limit: map['limit'] ?? 0,
      used: map['used'] ?? 0,
      expiry: map['expiry'] as Timestamp,
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'],
    );
  }

  String toJson() => json.encode(toMap());

  factory DiscountModel.fromJson(String source) =>
      DiscountModel.fromMap(json.decode(source));

  DiscountModel copyWith({
    String? id,
    String? code,
    String? description,
    num? rate,
    num? limit,
    num? used,
    Timestamp? expiry,
    bool? isActive,
    dynamic createdAt,
  }) {
    return DiscountModel(
      id: id ?? this.id,
      code: code ?? this.code,
      description: description ?? this.description,
      rate: rate ?? this.rate,
      limit: limit ?? this.limit,
      used: used ?? this.used,
      expiry: expiry ?? this.expiry,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 