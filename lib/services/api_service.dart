import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/photo.dart';

class ApiService {
  // 替换为你的 Flask 后端 URL
  // 注意：请确认 Render 部署成功后的正确 URL
  static const String baseUrl = 'https://momphotos.onrender.com';
  // 如果上面的 URL 不工作，请使用 Render 控制台中的实际 URL
  
  // 设置超时时间
  static const Duration timeout = Duration(seconds: 30);
  
  // 获取所有照片
  static Future<List<Photo>> getPhotos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/photos'),
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Photo.fromJson(json)).toList();
      } else if (response.statusCode == 503) {
        // 服务暂时不可用，可能是后端正在启动
        throw Exception('服务正在启动中，请稍后重试');
      } else {
        throw Exception('加载失败: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('请求超时，请检查网络连接');
    } on SocketException {
      throw Exception('网络连接失败，请检查网络设置');
    } catch (e) {
      if (e.toString().contains('Failed host lookup')) {
        throw Exception('无法连接到服务器，请检查网络连接');
      }
      throw Exception('网络错误: $e');
    }
  }

  // 按姓名搜索照片
  static Future<List<Photo>> searchPhotos(String name) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/search?name=${Uri.encodeComponent(name)}'),
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Photo.fromJson(json)).toList();
      } else {
        throw Exception('搜索失败: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('请求超时，请检查网络连接');
    } on SocketException {
      throw Exception('网络连接失败，请检查网络设置');
    } catch (e) {
      throw Exception('网络错误: $e');
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

      final response = await request.send().timeout(timeout);
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(responseData);
        return Photo.fromJson(data);
      } else {
        // 尝试解析错误信息
        try {
          final errorData = json.decode(responseData);
          throw Exception('上传失败: ${errorData['error'] ?? '未知错误'} (状态: ${response.statusCode})');
        } catch (e) {
          throw Exception('上传失败: $responseData (状态: ${response.statusCode})');
        }
      }
    } on TimeoutException {
      throw Exception('上传超时，请检查网络连接');
    } on SocketException {
      throw Exception('网络连接失败，请检查网络设置');
    } catch (e) {
      throw Exception('上传错误: $e');
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
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Photo.fromJson(data);
      } else {
        throw Exception('更新标签失败: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('请求超时，请检查网络连接');
    } on SocketException {
      throw Exception('网络连接失败，请检查网络设置');
    } catch (e) {
      throw Exception('更新错误: $e');
    }
  }
} 