import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/photo.dart';

class ApiService {
  // 替换为你的 Flask 后端 URL
  static const String baseUrl = 'http://192.168.2.100:5003';
  
  // 获取所有照片
  static Future<List<Photo>> getPhotos() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/photos'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Photo.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load photos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // 按姓名搜索照片
  static Future<List<Photo>> searchPhotos(String name) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/search?name=${Uri.encodeComponent(name)}'),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Photo.fromJson(json)).toList();
      } else {
        throw Exception('Failed to search photos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // 上传照片
  static Future<Photo> uploadPhoto({
    required File imageFile,
    required List<String> tags,
    int? year,
    String? description,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload'),
      );

      // 添加图片文件
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
        ),
      );

      // 添加其他数据
      request.fields['tags'] = json.encode(tags);
      if (year != null) request.fields['year'] = year.toString();
      if (description != null) request.fields['description'] = description;

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(responseData);
        return Photo.fromJson(data);
      } else {
        throw Exception('Failed to upload photo: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }

  // 为照片添加或更新标签
  static Future<Photo> updatePhotoTags({
    required String photoId,
    required List<String> tags,
    int? year,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tag'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'photo_id': photoId,
          'tags': tags,
          if (year != null) 'year': year,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Photo.fromJson(data);
      } else {
        throw Exception('Failed to update tags: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Update error: $e');
    }
  }
} 