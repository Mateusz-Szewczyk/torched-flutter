import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Service for managing file categories (system and user-defined)
class CategoryService {
  final ApiService _apiService = ApiService();

  /// Get all categories (system + user's custom)
  Future<List<CategoryModel>> getCategories() async {
    try {
      // Use trailing slash to avoid 307 redirect
      final response = await _apiService.ragGet('/categories/');

      if (response.statusCode == 200) {
        // response.data is already parsed by Dio (responseType: json by default)
        final List<dynamic> data = response.data is String
            ? json.decode(response.data)
            : response.data;
        return data.map((json) => CategoryModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load categories: ${response.statusMessage}');
      }
    } catch (e) {
      debugPrint('[CategoryService] Error fetching categories: $e');
      rethrow;
    }
  }

  /// Create a new custom category
  Future<CategoryModel> createCategory(String name) async {
    try {
      // Use trailing slash to avoid 307 redirect
      final response = await _apiService.ragPost(
        '/categories/',
        data: {'name': name},
      );

      if (response.statusCode == 201) {
        // response.data is already parsed by Dio
        final Map<String, dynamic> data = response.data is String
            ? json.decode(response.data)
            : response.data;
        return CategoryModel.fromJson(data);
      } else {
        throw Exception('Failed to create category: ${response.statusMessage}');
      }
    } catch (e) {
      debugPrint('[CategoryService] Error creating category: $e');
      rethrow;
    }
  }

  /// Delete a custom category (only user's own categories)
  Future<void> deleteCategory(String categoryId) async {
    try {
      // Use trailing slash to avoid 307 redirect
      final response = await _apiService.ragDelete('/categories/$categoryId/');

      if (response.statusCode != 204) {
        throw Exception('Failed to delete category: ${response.statusMessage}');
      }
    } catch (e) {
      debugPrint('[CategoryService] Error deleting category: $e');
      rethrow;
    }
  }
}

/// Model for Category
class CategoryModel {
  final String id;
  final String name;
  final bool isSystem;
  final DateTime? createdAt;

  CategoryModel({
    required this.id,
    required this.name,
    required this.isSystem,
    this.createdAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'],
      name: json['name'],
      isSystem: json['is_system'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_system': isSystem,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}

