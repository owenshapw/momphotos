import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/photo.dart';
import 'api_service.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class PhotoProvider with ChangeNotifier {
  List<Photo> _photos = [];
  List<Photo> _filteredPhotos = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  List<String> _searchHistory = [];
  bool _hasLoaded = false; // 添加加载状态标记
  String? _lastLoadedUserId;

  // Getters
  List<Photo> get photos => _photos;
  List<Photo> get filteredPhotos => _filteredPhotos;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  List<String> get searchHistory => List.unmodifiable(_searchHistory);
  bool get hasLoaded => _hasLoaded;

  // 按年代分组的照片
  Map<String, List<Photo>> get photosByDecade {
    final Map<String, List<Photo>> grouped = {};
    
    for (final photo in _filteredPhotos) {
      final decade = photo.decadeGroup;
      if (!grouped.containsKey(decade)) {
        grouped[decade] = [];
      }
      grouped[decade]!.add(photo);
    }
    
    // 在每个年代分组内按拍摄日期排序（从近到远）
    for (final photos in grouped.values) {
      photos.sort((a, b) {
        // 优先按拍摄年份排序
        if (a.year != null && b.year != null) {
          return b.year!.compareTo(a.year!); // 降序，最新的在前
        } else if (a.year != null) {
          return -1; // 有年份的排在前面
        } else if (b.year != null) {
          return 1;
        } else {
          // 如果都没有年份，按创建时间排序
          return b.createdAt.compareTo(a.createdAt);
        }
      });
    }
    
    // 过滤掉没有照片的年代分组
    final nonEmptyGrouped = Map<String, List<Photo>>.fromEntries(
      grouped.entries.where((entry) => entry.value.isNotEmpty),
    );
    
    // 按年代排序
    final sortedKeys = nonEmptyGrouped.keys.toList()
      ..sort((a, b) {
        if (a == '未知年代') return 1;
        if (b == '未知年代') return -1;
        return b.compareTo(a); // 降序排列
      });
    
    return Map.fromEntries(
      sortedKeys.map((key) => MapEntry(key, nonEmptyGrouped[key]!)),
    );
  }

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
      print('🔄 检测到用户切换，重置PhotoProvider状态');
      print('  上次加载用户ID: $_lastLoadedUserId');
      print('  当前用户ID: $currentUserId');
      reset();
      _lastLoadedUserId = currentUserId;
      forceRefresh = true; // 强制刷新
    }
    
    // 如果已经加载过且不强制刷新，直接返回
    if (_hasLoaded && !forceRefresh && _photos.isNotEmpty) {
      return;
    }
    
    _setLoading(true);
    _error = null;
    
    // 添加重试机制
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        // 使用新的API，支持缓存
        final allPhotos = await ApiService.getPhotos(forceRefresh: forceRefresh);
        
        // 过滤掉已删除的照片（只在强制刷新时进行）
        if (forceRefresh) {
          _photos = await _filterValidPhotos(allPhotos);
        } else {
          _photos = allPhotos;
        }
        
        // 按拍摄日期排序（从近到远）
        _photos.sort((a, b) {
          // 优先按拍摄年份排序
          if (a.year != null && b.year != null) {
            return b.year!.compareTo(a.year!); // 降序，最新的在前
          } else if (a.year != null) {
            return -1; // 有年份的排在前面
          } else if (b.year != null) {
            return 1;
          } else {
            // 如果都没有年份，按创建时间排序
            return b.createdAt.compareTo(a.createdAt);
          }
        });
        
        _applySearchFilter();
        _hasLoaded = true; // 标记为已加载
        _lastLoadedUserId = currentUserId; // 记录当前加载的用户ID
        notifyListeners();
        
        print('📸 照片加载完成: ${_photos.length} 张照片 (用户ID: $currentUserId)');
        
        return; // 成功则退出
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          // 最后一次重试失败
          _error = e.toString();
          notifyListeners();
        } else {
          // 减少重试间隔，提高响应速度
          await Future.delayed(Duration(seconds: retryCount));
        }
      }
    }
    
    _setLoading(false);
  }

  // 过滤有效的照片（未删除的照片）- 优化版本
  Future<List<Photo>> _filterValidPhotos(List<Photo> photos) async {
    final validPhotos = <Photo>[];
    
    // 限制并发请求数量，避免过多请求
    const maxConcurrent = 5;
    final batches = <List<Photo>>[];
    
    for (int i = 0; i < photos.length; i += maxConcurrent) {
      final end = (i + maxConcurrent < photos.length) ? i + maxConcurrent : photos.length;
      batches.add(photos.sublist(i, end));
    }
    
    for (final batch in batches) {
      // 使用并发请求，但限制数量
      final futures = batch.map((photo) async {
        try {
          // 使用更快的HEAD请求检查照片是否存在
          final response = await http.head(
            Uri.parse(photo.url),
            headers: {'Connection': 'keep-alive'},
          ).timeout(const Duration(seconds: 5));
          
          if (response.statusCode == 200) {
            return photo;
          }
        } catch (e) {
          // 如果图片加载失败，说明照片可能已被删除
          if (kDebugMode) {
            debugPrint('照片已删除或无法访问: ${photo.url}');
          }
        }
        return null;
      });
      
      // 等待当前批次完成
      final results = await Future.wait(futures);
      
      // 过滤掉null结果
      for (final result in results) {
        if (result != null) {
          validPhotos.add(result);
        }
      }
      
      // 短暂延迟，避免请求过于频繁
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    return validPhotos;
  }

    // 搜索照片
  Future<void> searchPhotos(String query) async {
    _searchQuery = query.trim();

    if (_searchQuery.isEmpty) {
      _filteredPhotos = _photos;
      notifyListeners();
      return;
    }

    // 添加到搜索历史
    _addToSearchHistory(_searchQuery);
    
    // 优先使用本地搜索（更快）
    _applyLocalSearchFilter();
    notifyListeners();
    
    // 如果本地没有数据，尝试服务器搜索
    if (_photos.isEmpty) {
      _setLoading(true);
      _error = null;
      
      try {
        _filteredPhotos = await ApiService.searchPhotos(_searchQuery);
        notifyListeners();
      } catch (e) {
        _error = null; // 清除错误，因为本地搜索可以工作
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

  // 按拍摄日期顺序插入照片
  void _insertPhotoInOrder(Photo photo) {
    // 找到正确的插入位置
    int insertIndex = 0;
    for (int i = 0; i < _photos.length; i++) {
      final existingPhoto = _photos[i];
      
      // 比较拍摄年份
      if (photo.year != null && existingPhoto.year != null) {
        if (photo.year! >= existingPhoto.year!) {
          insertIndex = i;
          break;
        }
      } else if (photo.year != null) {
        // 新照片有年份，现有照片没有年份，新照片排在前面
        insertIndex = i;
        break;
      } else if (existingPhoto.year != null) {
        // 新照片没有年份，现有照片有年份，继续查找
        continue;
      } else {
        // 都没有年份，按创建时间比较
        if (photo.createdAt.isAfter(existingPhoto.createdAt)) {
          insertIndex = i;
          break;
        }
      }
      
      // 如果到达列表末尾，插入到最后
      if (i == _photos.length - 1) {
        insertIndex = _photos.length;
      }
    }
    
    _photos.insert(insertIndex, photo);
  }

  // 上传照片
  Future<void> uploadPhoto({
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
      
      // 按拍摄日期顺序插入照片
      _insertPhotoInOrder(photo);
      _applySearchFilter();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // 更新照片标签和描述
  Future<void> updatePhotoTags({
    required String photoId,
    required List<String> tags,
    int? year,
    String? description,
  }) async {
    _setLoading(true);
    _error = null;
    
    try {
      final updatedPhoto = await ApiService.updatePhotoTags(
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
        
        bool needsResort = false;
        
        // 只有当年份发生变化时才重新排序
        if (oldPhoto.year != updatedPhoto.year) {
          needsResort = true;
          _photos.sort((a, b) {
            // 优先按拍摄年份排序
            if (a.year != null && b.year != null) {
              return b.year!.compareTo(a.year!); // 降序，最新的在前
            } else if (a.year != null) {
              return -1; // 有年份的排在前面
            } else if (b.year != null) {
              return 1;
            } else {
              // 如果都没有年份，按创建时间排序
              return b.createdAt.compareTo(a.createdAt);
            }
          });
        }
        
        // 只有在需要重新排序或搜索过滤结果可能受影响时才更新过滤结果
        if (needsResort || _searchQuery.isNotEmpty) {
          _applySearchFilter();
        }
        
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
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
    ApiService.clearCache(); // 清除API缓存
    notifyListeners();
    print('🔄 PhotoProvider状态已重置');
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
} 