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
  
  // 缓存机制
  static List<Photo>? _cachedPhotos;
  static DateTime? _lastCacheTime;
  static const Duration cacheValidDuration = Duration(minutes: 5);
  
  // 获取所有照片（带缓存和分页）
  static Future<List<Photo>> getPhotos({int? limit, int? offset, bool forceRefresh = false}) async {
    // 检查缓存
    if (!forceRefresh && _cachedPhotos != null && _lastCacheTime != null) {
      final timeSinceLastCache = DateTime.now().difference(_lastCacheTime!);
      if (timeSinceLastCache < cacheValidDuration) {
        // 如果请求分页，从缓存中返回对应部分
        if (limit != null && offset != null) {
          final start = offset;
          final end = (start + limit < _cachedPhotos!.length) ? start + limit : _cachedPhotos!.length;
          return _cachedPhotos!.sublist(start, end);
        }
        return _cachedPhotos!;
      }
    }
    
    try {
      final queryParams = <String, String>{};
      if (limit != null) queryParams['limit'] = limit.toString();
      if (offset != null) queryParams['offset'] = offset.toString();
      
      final uri = Uri.parse('$baseUrl/photos').replace(queryParameters: queryParams);
      final response = await http.get(uri).timeout(timeout);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final photos = data.map((json) => Photo.fromJson(json)).toList();
        
        // 更新缓存（只在获取所有照片时）
        if (limit == null && offset == null) {
          _cachedPhotos = photos;
          _lastCacheTime = DateTime.now();
        }
        
        return photos;
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

  // 按姓名搜索照片（优化版本）
  static Future<List<Photo>> searchPhotos(String name) async {
    try {
      // 如果缓存中有数据，先尝试本地搜索
      if (_cachedPhotos != null && _lastCacheTime != null) {
        final timeSinceLastCache = DateTime.now().difference(_lastCacheTime!);
        if (timeSinceLastCache < cacheValidDuration) {
          return _performLocalSearch(_cachedPhotos!, name);
        }
      }
      
      // 否则使用服务器搜索
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

  // 本地搜索实现
  static List<Photo> _performLocalSearch(List<Photo> photos, String query) {
    if (query.isEmpty) return photos;
    
    final queryLower = query.toLowerCase();
    return photos.where((photo) {
      // 搜索人物标签
      final tagMatch = photo.tags.any((tag) => tag.toLowerCase().contains(queryLower));
      
      // 搜索年代
      final yearMatch = photo.year != null && photo.year.toString().contains(query);
      
      // 搜索年代分组
      final decadeMatch = photo.decadeGroup.toLowerCase().contains(queryLower);
      
      // 搜索简介
      final descriptionMatch = photo.description != null && 
          photo.description!.toLowerCase().contains(queryLower);
      
      return tagMatch || yearMatch || decadeMatch || descriptionMatch;
    }).toList();
  }

  // 清除缓存
  static void clearCache() {
    _cachedPhotos = null;
    _lastCacheTime = null;
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

  // 为照片添加或更新标签和描述
  static Future<Photo> updatePhotoTags({
    required String photoId,
    required List<String> tags,
    int? year,
    String? description,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tag'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'photo_id': photoId,
          'tags': tags,
          if (year != null) 'year': year,
          if (description != null) 'description': description,
        }),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Photo.fromJson(data);
      } else {
        throw Exception('更新失败: ${response.statusCode}');
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