import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../models/photo.dart';
import 'api_service.dart';

import '../services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../main.dart';

class PhotoProvider with ChangeNotifier {
  List<Photo> _photos = [];
  List<Photo> _filteredPhotos = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  List<String> _searchHistory = [];
  bool _hasLoaded = false; // 添加加载状态标记
  String? _lastLoadedUserId;
  String? lastViewedPhotoId; // 用于从详情页返回时定位

  // Getters
  List<Photo> get photos => _photos;
  List<Photo> get filteredPhotos => _filteredPhotos;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  List<String> get searchHistory => List.unmodifiable(_searchHistory);
  bool get hasLoaded => _hasLoaded;

  // 获取所有标签
  Set<String> get allTags {
    final Set<String> tags = {};
    for (final photo in _photos) {
      tags.addAll(photo.tags);
    }
    return tags;
  }

    // 加载所有照片
  Future<void> loadPhotos({bool forceRefresh = false}) async {
    // 检查用户是否发生变化
    final currentUserId = AuthService.currentUser?.id;
    if (currentUserId != null && _lastLoadedUserId != currentUserId) {
      developer.log('🔄 检测到用户切换，重置PhotoProvider状态');
      developer.log('  上次加载用户ID: $_lastLoadedUserId');
      developer.log('  当前用户ID: $currentUserId');
      reset();
      _lastLoadedUserId = currentUserId;
      forceRefresh = true; // 强制刷新
    }
    if (_hasLoaded && !forceRefresh && _photos.isNotEmpty) {
      return;
    }
    _setLoading(true);
    _error = null;
    int retryCount = 0;
    const maxRetries = 3;
    while (retryCount < maxRetries) {
      try {
        final allPhotos = await ApiService.getPhotos(forceRefresh: forceRefresh);
        _photos = allPhotos;
        _photos.sort((a, b) {
          if (a.year != null && b.year != null) {
            return b.year!.compareTo(a.year!);
          } else if (a.year != null) {
            return -1;
          } else if (b.year != null) {
            return 1;
          } else {
            return b.createdAt.compareTo(a.createdAt);
          }
        });
        _applySearchFilter();
        _hasLoaded = true;
        _lastLoadedUserId = currentUserId;
        developer.log('📸 照片加载完成: [32m[1m${_photos.length}[0m 张照片 (用户ID: $currentUserId)');
        notifyListeners();
        _setLoading(false);
        return;
      } catch (e) {
        if (e.toString().contains('401')) {
          if (navigatorKey.currentContext != null) {
            ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
              const SnackBar(content: Text('登录已过期，请重新登录')),
            );
            await AuthService.logout();
            if (navigatorKey.currentContext!.mounted) {
              GoRouter.of(navigatorKey.currentContext!).go('/login');
            }
          }
          return;
        }
        retryCount++;
        if (retryCount >= maxRetries) {
          _error = e.toString();
          _setLoading(false);
          notifyListeners();
        } else {
          await Future.delayed(Duration(seconds: retryCount));
        }
      }
    }
  }



    // 搜索照片
  Future<void> searchPhotos(String query) async {
    _searchQuery = query.trim();
    if (_searchQuery.isEmpty) {
      _filteredPhotos = _photos;
      notifyListeners();
      return;
    }
    _addToSearchHistory(_searchQuery);
    _applyLocalSearchFilter();
    notifyListeners();
    if (_photos.isEmpty) {
      _setLoading(true);
      _error = null;
      try {
        _filteredPhotos = await ApiService.searchPhotos(_searchQuery);
        notifyListeners();
      } catch (e) {
        if (e.toString().contains('401')) {
          if (navigatorKey.currentContext != null) {
            ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
              const SnackBar(content: Text('登录已过期，请重新登录')),
            );
            await AuthService.logout();
            if (navigatorKey.currentContext!.mounted) {
              GoRouter.of(navigatorKey.currentContext!).go('/login');
            }
          }
          return;
        }
        _error = null;
        _applyLocalSearchFilter();
        notifyListeners();
      } finally {
        _setLoading(false);
      }
    }
  }

  // 应用本地搜索过滤器
  void _applyLocalSearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredPhotos = _photos;
    } else {
      final query = _searchQuery.toLowerCase();
      if (kDebugMode) {
        debugPrint('=== 搜索调试信息 ===');
        debugPrint('搜索查询: "$query"');
        debugPrint('总照片数: ${_photos.length}');
        
        // 显示所有照片的年代信息
        for (int i = 0; i < _photos.length && i < 5; i++) {
          final photo = _photos[i];
          debugPrint('照片 $i: ID=${photo.id}, 年份=${photo.year}, 年代分组="${photo.decadeGroup}"');
        }
      }
      
      _filteredPhotos = _photos.where((photo) {
        // 搜索人物标签
        final tagMatch = photo.tags.any((tag) =>
            tag.toLowerCase().contains(query));
        
        // 搜索年代
        final yearMatch = photo.year != null && 
            photo.year.toString().contains(query);
        
        // 搜索年代分组（如"1970年代"）
        final decadeMatch = photo.decadeGroup.toLowerCase().contains(query);
        
        // 搜索年代数字（如"1970"）
        final decadeNumberMatch = photo.year != null && 
            query.contains(photo.year.toString());
        
        // 搜索简介
        final descriptionMatch = photo.description != null &&
            photo.description!.toLowerCase().contains(query);
        
        if (kDebugMode) {
          if (tagMatch || yearMatch || decadeMatch || decadeNumberMatch || descriptionMatch) {
            debugPrint('✓ 匹配照片: ID=${photo.id}, 年份=${photo.year}, 年代分组="${photo.decadeGroup}"');
            debugPrint('  标签匹配: $tagMatch, 年份匹配: $yearMatch, 年代分组匹配: $decadeMatch, 年代数字匹配: $decadeNumberMatch, 简介匹配: $descriptionMatch');
          }
        }
        
        return tagMatch || yearMatch || decadeMatch || decadeNumberMatch || descriptionMatch;
      }).toList();
      
      if (kDebugMode) {
        debugPrint('搜索结果: ${_filteredPhotos.length} 张照片');
        debugPrint('=== 搜索调试结束 ===');
      }
    }
  }

  // 应用搜索过滤器
  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredPhotos = _photos;
    } else {
      _applyLocalSearchFilter();
    }
  }

  // 上传照片
  Future<Photo> uploadPhoto({
    required String imagePath,
    required List<String> tags,
    int? year,
    String? description,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final photo = await ApiService.uploadPhoto(
        imageFile: File(imagePath),
        tags: tags,
        year: year,
        description: description,
      );
      await resetAndReload();
      return photo;
    } catch (e) {
      if (e.toString().contains('401')) {
        if (navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            const SnackBar(content: Text('登录已过期，请重新登录')),
          );
          await AuthService.logout();
          if (navigatorKey.currentContext!.mounted) {
            GoRouter.of(navigatorKey.currentContext!).go('/login');
          }
        }
        throw Exception('登录已过期，请重新登录');
      }
      _error = e.toString();
      notifyListeners();
      if (navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          SnackBar(content: Text('操作失败: [31m${e.toString()}[0m')),
        );
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // 删除照片
  Future<void> deletePhoto(String photoId) async {
    _setLoading(true);
    _error = null;
    try {
      await ApiService.deletePhoto(photoId);
      
      // 从照片列表中移除
      _photos.removeWhere((photo) => photo.id == photoId);
      _applySearchFilter();
      notifyListeners();
    } catch (e) {
      if (e.toString().contains('401')) {
        if (navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            const SnackBar(content: Text('登录已过期，请重新登录')),
          );
          await AuthService.logout();
          if (navigatorKey.currentContext!.mounted) {
            GoRouter.of(navigatorKey.currentContext!).go('/login');
          }
        }
        return;
      }
      _error = e.toString();
      notifyListeners();
      if (navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          SnackBar(content: Text('操作失败: [31m${e.toString()}[0m')),
        );
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // 更新照片标签、年代和描述
  Future<void> updatePhotoDetails({
    required String photoId,
    List<String>? tags,
    dynamic year,
    String? description,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final updatedPhoto = await ApiService.updatePhotoDetails(
        photoId: photoId,
        tags: tags,
        year: year,
        description: description,
      );
      
      // 更新照片列表中的对应照片
      final index = _photos.indexWhere((photo) => photo.id == photoId);
      if (index != -1) {
        final oldPhoto = _photos[index];
        _photos[index] = updatedPhoto;
        
        // 只有当年份发生变化时才需要重新排序
        if (oldPhoto.year != updatedPhoto.year) {
          _photos.sort((a, b) {
            if (a.year != null && b.year != null) {
              return b.year!.compareTo(a.year!); // 降序
            } else if (a.year != null) {
              return -1;
            } else if (b.year != null) {
              return 1;
            } else {
              return b.createdAt.compareTo(a.createdAt);
            }
          });
        }
        
        _applySearchFilter();
        notifyListeners();
      }
    } catch (e) {
      if (e.toString().contains('401')) {
        // token失效，弹窗提示并跳转登录页
        if (navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            const SnackBar(content: Text('登录已过期，请重新登录')),
          );
          // await AuthService.logout(); // 注释掉自动logout
          // if (navigatorKey.currentContext!.mounted) {
          //   GoRouter.of(navigatorKey.currentContext!).go('/login');
          // }
        }
        return;
      }
      _error = e.toString();
      notifyListeners();
      if (navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          SnackBar(content: Text('操作失败: [31m${e.toString()}[0m')),
        );
      }
      rethrow; // 重新抛出异常，让UI层处理
    } finally {
      _setLoading(false);
    }
  }

  // 清除搜索
  void clearSearch() {
    _searchQuery = '';
    _filteredPhotos = _photos;
    notifyListeners();
  }

  // 设置加载状态
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // 清除错误
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // 重置状态（用于用户切换时）
  void reset() {
    _photos.clear();
    _filteredPhotos.clear();
    _isLoading = false;
    _error = null;
    _searchQuery = '';
    _hasLoaded = false;
    _lastLoadedUserId = null; // 清除上次加载的用户ID
    // 只清除照片缓存，不清token
    ApiService.clearCache();
    notifyListeners();
    developer.log('🔄 PhotoProvider状态已重置');
  }

  // 清除图片缓存
  void clearImageCache() {
    // 通知PhotoGrid重新加载图片
    notifyListeners();
  }

  // 添加搜索历史
  void _addToSearchHistory(String query) {
    if (query.trim().isNotEmpty) {
      _searchHistory.remove(query.trim());
      _searchHistory.insert(0, query.trim());
      // 只保留最近10条搜索记录
      if (_searchHistory.length > 10) {
        _searchHistory = _searchHistory.take(10).toList();
      }
    }
  }

  // 清除搜索历史
  void clearSearchHistory() {
    _searchHistory.clear();
    notifyListeners();
  }

  void setLastViewedPhotoId(String? id) {
    lastViewedPhotoId = id;
    notifyListeners();
  }

  Future<void> resetAndReload() async {
    _photos.clear();
    _filteredPhotos.clear();
    _isLoading = false;
    _error = null;
    _searchQuery = '';
    _hasLoaded = false;
    _lastLoadedUserId = null;
    ApiService.clearCache();
    notifyListeners();
    developer.log('🔄 PhotoProvider状态已重置并即将强制刷新');
    await loadPhotos(forceRefresh: true);
  }
}