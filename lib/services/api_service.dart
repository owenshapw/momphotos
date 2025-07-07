import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/photo.dart';
import '../models/user.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthResponse;
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;
import 'package:exif/exif.dart';
import '../services/auth_service.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class ApiService {
  // 生产环境 URL
  static const String baseUrl = 'https://momphotos.onrender.com';
  // 本地开发服务器 URL: 'http://localhost:8080'
  
  // 设置超时时间
  static const Duration timeout = Duration(seconds: 10);
  
  // 缓存机制 - 与用户ID绑定
  static List<Photo>? _cachedPhotos;
  static DateTime? _lastCacheTime;
  static String? _cachedUserId; // 新增：记录缓存对应的用户ID
  static const Duration cacheValidDuration = Duration(minutes: 30); // 延长缓存时间到30分钟
  
  // 获取所有照片（带缓存和分页）
  static Future<List<Photo>> getPhotos({int? limit, int? offset, bool forceRefresh = false}) async {
    final currentUserId = AuthService.currentUser?.id;
    final token = AuthService.currentToken;
    if (token == null) {
      developer.log('❌ Token为空，无法请求getPhotos');
      throw Exception('登录已过期，请重新登录');
    }
    // 检查用户是否发生变化，如果变化则清空缓存
    if (_cachedUserId != currentUserId) {
      _cachedPhotos = null;
      _lastCacheTime = null;
      _cachedUserId = currentUserId;
      developer.log('🔄 ApiService: 用户切换，清空缓存 ($_cachedUserId -> $currentUserId)');
    }
    
    // 检查缓存 - 优先使用缓存，除非强制刷新
    if (!forceRefresh && _cachedPhotos != null && _lastCacheTime != null) {
      final timeSinceLastCache = DateTime.now().difference(_lastCacheTime!);
      if (timeSinceLastCache < cacheValidDuration) {
        developer.log('📸 ApiService: 使用缓存数据 (用户ID: $currentUserId, 照片数: ${_cachedPhotos!.length})');
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
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Connection': 'keep-alive',
        },
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final photos = data.map((json) => Photo.fromJson(json)).toList();
        
        // 更新缓存（只在获取所有照片时）
        if (limit == null && offset == null) {
          _cachedPhotos = photos;
          _lastCacheTime = DateTime.now();
          _cachedUserId = currentUserId; // 记录当前用户ID
          developer.log('📸 ApiService: 缓存已更新 (用户ID: $currentUserId, 照片数: ${photos.length})');
        }
        
        return photos;
      } else if (response.statusCode == 401) {
        developer.log('❌ Token失效，getPhotos返回401');
        throw Exception('401');
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
    final token = AuthService.currentToken;
    if (token == null) {
      developer.log('❌ Token为空，无法请求searchPhotos');
      throw Exception('登录已过期，请重新登录');
    }
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
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Photo.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        developer.log('❌ Token失效，searchPhotos返回401');
        throw Exception('401');
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
    _cachedUserId = null; // 清除用户ID
    developer.log('🔄 API缓存已清除');
  }

  // 用户认证相关方法
  static String? _authToken;

  // 设置认证token
  static void setAuthToken(String token) {
    _authToken = token;
  }

  // 清除认证token
  static void clearAuthToken() {
    _authToken = null;
  }

  // 获取认证token
  static String? getAuthToken() {
    return _authToken;
  }

  // 用户注册
  static Future<AuthResponse> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
        }),
      ).timeout(timeout);

      if (response.statusCode == 201) { // Updated to check for 201 Created
        final data = json.decode(response.body);
        final authResponse = AuthResponse.fromJson(data);
        // 保存token
        setAuthToken(authResponse.token);
        return authResponse;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? '注册失败');
      }
    } on TimeoutException {
      throw Exception('请求超时，请检查网络连接');
    } on SocketException {
      throw Exception('网络连接失败，请检查网络设置');
    } catch (e) {
      throw Exception('注册错误: $e');
    }
  }

  // 用户登录
  static Future<AuthResponse> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final authResponse = AuthResponse.fromJson(data);
        // 保存token
        setAuthToken(authResponse.token);
        return authResponse;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? '登录失败');
      }
    } on TimeoutException {
      throw Exception('请求超时，请检查网络连接');
    } on SocketException {
      throw Exception('网络连接失败，请检查网络设置');
    } catch (e) {
      throw Exception('登录错误: $e');
    }
  }

  // 验证token（用于检查登录状态）
  static Future<bool> validateToken() async {
    if (_authToken == null) return false;
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/validate'),
        headers: {'Authorization': 'Bearer $_authToken'},
      ).timeout(timeout);

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 忘记密码
  static Future<String> forgotPassword({required String email}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      ).timeout(timeout);

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return data['message'];
      } else {
        throw Exception(data['error'] ?? '请求失败');
      }
    } on TimeoutException {
      throw Exception('请求超时，请检查网络连接');
    } on SocketException {
      throw Exception('网络连接失败，请检查网络设置');
    } catch (e) {
      throw Exception('请求错误: $e');
    }
  }

  // 上传照片
  static Future<Photo> uploadPhoto({
    required File imageFile,
    required List<String> tags,
    int? year,
    String? description,
  }) async {
    final token = AuthService.currentToken;
    if (token == null) {
      developer.log('❌ Token为空，无法请求uploadPhoto');
      throw Exception('登录已过期，请重新登录');
    }
    try {
      // 1. 上传原图到 Supabase Storage（不压缩，保持原始质量）
      final supabase = Supabase.instance.client;
      final originalBytes = kIsWeb 
          ? await _readFileBytesWeb(imageFile.path)
          : await imageFile.readAsBytes();
      
      // 添加随机数避免缓存问题
      final random = DateTime.now().millisecondsSinceEpoch + (DateTime.now().microsecond);
      final fileName =
          'photos/${random}_${p.basename(imageFile.path)}';
      final storageResponse = await supabase.storage
          .from('photos')
          .uploadBinary(fileName, originalBytes, fileOptions: FileOptions(contentType: 'image/jpeg'));
      if (storageResponse.isEmpty) {
        throw Exception('图片上传到 Supabase Storage 失败');
      }
      final imageUrl = supabase.storage.from('photos').getPublicUrl(fileName);

      // 2. 生成缩略图并上传
      // 解码原图用于生成缩略图
      final originalImage = img.decodeImage(originalBytes);
      if (originalImage == null) {
        throw Exception('无法解码原始图片');
      }
      
      // 处理EXIF方向信息
      Map<String, IfdTag>? exifData;
      try {
        exifData = await readExifFromBytes(originalBytes);
      } catch (e) {
        developer.log('读取EXIF数据失败: $e');
      }
      
      // 根据EXIF方向信息旋转图片
      final correctedImage = _correctImageOrientation(originalImage, exifData);
      
      // 固定缩略图尺寸：300x400px，从原图中心截取
      final targetWidth = 300;
      final targetHeight = 400;
      final originalWidth = correctedImage.width;
      final originalHeight = correctedImage.height;
      
      // 计算缩放比例，确保图片能完全覆盖目标尺寸
      final scaleX = targetWidth / originalWidth;
      final scaleY = targetHeight / originalHeight;
      final scale = scaleX > scaleY ? scaleX : scaleY; // 使用较大的缩放比例
      
      // 计算缩放后的尺寸
      final scaledWidth = (originalWidth * scale).round();
      final scaledHeight = (originalHeight * scale).round();
      
      // 缩放图片
      final scaledImage = img.copyResize(correctedImage, width: scaledWidth, height: scaledHeight, interpolation: img.Interpolation.cubic);
      
      // 从中心截取目标尺寸
      final left = (scaledWidth - targetWidth) ~/ 2;
      final top = (scaledHeight - targetHeight) ~/ 2;
      
      // 截取中心部分
      final thumbnail = img.copyCrop(scaledImage, x: left, y: top, width: targetWidth, height: targetHeight);
      final thumbnailBytes = img.encodeJpg(thumbnail, quality: 95);
      
      // 生成照片ID（使用UUID格式）
      final photoId = '${DateTime.now().millisecondsSinceEpoch}_$random';
      final thumbFileName = 'thumbnails/$photoId.jpg';
      final thumbStorageResponse = await supabase.storage
          .from('photos')
          .uploadBinary(thumbFileName, thumbnailBytes, fileOptions: FileOptions(contentType: 'image/jpeg'));
      if (thumbStorageResponse.isEmpty) {
        throw Exception('缩略图上传到 Supabase Storage 失败');
      }
      final thumbnailUrl = supabase.storage.from('photos').getPublicUrl(thumbFileName);

      // 3. POST 元数据到后端
      final response = await http.post(
        Uri.parse('$baseUrl/photos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'url': imageUrl,
          'thumbnail_url': thumbnailUrl,
          'tags': tags,
          if (year != null) 'year': year,
          if (description != null) 'description': description,
        }),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // 清除缓存，以便下次能获取到最新列表
        clearCache();
        return Photo.fromJson(data);
      } else if (response.statusCode == 401) {
        developer.log('❌ Token失效，uploadPhoto返回401');
        throw Exception('401');
      } else {
        final errorData = json.decode(response.body);
        throw Exception('上传失败: ${(errorData['error'] ?? response.body)}');
      }
    } on TimeoutException {
      throw Exception('上传超时，请检查网络连接');
    } on SocketException {
      throw Exception('网络连接失败，请检查网络设置');
    } catch (e) {
      throw Exception('上传错误: $e');
    }
  }

  // 删除照片
  static Future<void> deletePhoto(String photoId) async {
    final token = AuthService.currentToken;
    if (token == null) {
      developer.log('❌ Token为空，无法请求deletePhoto');
      throw Exception('登录已过期，请重新登录');
    }
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/photos/$photoId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(timeout);

      if (response.statusCode == 200) {
        // 由Provider在本地更新列表，不再清除整个缓存
        // clearCache();
      } else if (response.statusCode == 401) {
        developer.log('❌ Token失效，deletePhoto返回401');
        throw Exception('401');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? '删除失败');
      }
    } on TimeoutException {
      throw Exception('请求超时，请检查网络连接');
    } on SocketException {
      throw Exception('网络连接失败，请检查网络设置');
    } catch (e) {
      throw Exception('删除错误: $e');
    }
  }

  // 注销账户
  static Future<void> deleteAccount() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/auth/account'),
        headers: {
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        },
      ).timeout(timeout);

      if (response.statusCode == 200) {
        // 清除认证信息和缓存
        clearAuthToken();
        clearCache();
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? '注销账户失败');
      }
    } on TimeoutException {
      throw Exception('请求超时，请检查网络连接');
    } on SocketException {
      throw Exception('网络连接失败，请检查网络设置');
    } catch (e) {
      throw Exception('注销账户错误: $e');
    }
  }

  // 为照片添加或更新标签、年代和描述
  static Future<Photo> updatePhotoDetails({
    required String photoId,
    List<String>? tags,
    dynamic year, // 允许为空字符串或null
    String? description,
  }) async {
    final token = AuthService.currentToken;
    if (token == null) {
      developer.log('❌ Token为空，无法请求updatePhotoDetails');
      throw Exception('登录已过期，请重新登录');
    }
    try {
      final Map<String, dynamic> body = {
        'photo_id': photoId,
      };
      if (tags != null) body['tags'] = tags;
      if (year != null) body['year'] = year;
      if (description != null) body['description'] = description;

      final response = await http.post(
        Uri.parse('$baseUrl/photos/update'), // 路由已更新
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // 更新成功后，不再清除整个缓存，而是由Provider在本地更新
        // clearCache(); 
        return Photo.fromJson(data);
      } else if (response.statusCode == 401) {
        developer.log('❌ Token失效，updatePhotoDetails返回401');
        throw Exception('401');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? '更新失败');
      }
    } on TimeoutException {
      throw Exception('请求超时，请检查网络连接');
    } on SocketException {
      throw Exception('网络连接失败，请检查网络设置');
    } catch (e) {
      throw Exception('更新错误: $e');
    }
  }

  // 处理EXIF方向信息
  static img.Image _correctImageOrientation(img.Image image, Map<String, IfdTag>? exifData) {
    if (exifData == null) return image;
    
    try {
      final orientationTag = exifData['Image Orientation'];
      if (orientationTag == null) return image;
      
      final orientation = orientationTag.printable;
      switch (orientation) {
        case '3': // 180度旋转
          return img.copyRotate(image, angle: 180);
        case '6': // 顺时针90度旋转
          return img.copyRotate(image, angle: 90);
        case '8': // 逆时针90度旋转
          return img.copyRotate(image, angle: 270);
        default:
          return image;
      }
    } catch (e) {
      developer.log('EXIF方向处理失败: $e');
      return image;
    }
  }

  // Web平台文件读取方法
  static Future<Uint8List> _readFileBytesWeb(String filePath) async {
    try {
      final response = await http.get(Uri.parse(filePath));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('无法读取文件: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('读取文件失败: $e');
    }
  }
} 