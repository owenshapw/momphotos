import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/photo.dart';
import 'api_service.dart';
import 'package:http/http.dart' as http;

class PhotoProvider with ChangeNotifier {
  List<Photo> _photos = [];
  List<Photo> _filteredPhotos = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  List<String> _searchHistory = [];
  bool _hasLoaded = false; // 添加加载状态标记

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
  Future<void> loadPhotos({bool checkDeletedPhotos = false, bool forceRefresh = false}) async {
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
        _photos = await ApiService.getPhotos();
        _applySearchFilter();
        _hasLoaded = true; // 标记为已加载
        notifyListeners();
        
        // 只在需要时检测已删除的照片
        if (checkDeletedPhotos) {
          await filterDeletedPhotos();
        }
        
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

  // 搜索照片
  Future<void> searchPhotos(String query) async {
    _searchQuery = query.trim();
    
    if (_searchQuery.isEmpty) {
      _filteredPhotos = _photos;
    } else {
      _setLoading(true);
      _error = null;
      
      // 添加到搜索历史
      _addToSearchHistory(_searchQuery);
      
      try {
        // 先尝试使用后端搜索API
        _filteredPhotos = await ApiService.searchPhotos(_searchQuery);
        notifyListeners();
      } catch (e) {
        // 如果后端搜索失败，使用本地搜索
        _error = null; // 清除错误，因为本地搜索可以工作
        _applyLocalSearchFilter();
        notifyListeners();
      } finally {
        _setLoading(false);
      }
    }
    
    notifyListeners();
  }

  // 应用本地搜索过滤器
  void _applyLocalSearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredPhotos = _photos;
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredPhotos = _photos.where((photo) {
        // 搜索人物标签
        final tagMatch = photo.tags.any((tag) =>
            tag.toLowerCase().contains(query));
        
        // 搜索年代
        final yearMatch = photo.year != null && 
            photo.year.toString().contains(query);
        
        // 搜索年代分组
        final decadeMatch = photo.decadeGroup.toLowerCase().contains(query);
        
        // 搜索简介
        final descriptionMatch = photo.description != null &&
            photo.description!.toLowerCase().contains(query);
        
        return tagMatch || yearMatch || decadeMatch || descriptionMatch;
      }).toList();
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
      
      _photos.insert(0, photo); // 添加到列表开头
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
        _photos[index] = updatedPhoto;
        _applySearchFilter();
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

  // 检测并过滤掉已删除的照片
  Future<void> filterDeletedPhotos() async {
    final validPhotos = <Photo>[];
    
    // 使用并发请求，提高检测速度
    final futures = _photos.map((photo) async {
      try {
        // 尝试加载图片来检测是否还存在
        final response = await http.head(Uri.parse(photo.url));
        if (response.statusCode == 200) {
          return photo;
        }
      } catch (e) {
        // 如果图片加载失败，说明照片可能已被删除
        print('照片已删除或无法访问: ${photo.url}');
      }
      return null;
    });
    
    // 等待所有请求完成
    final results = await Future.wait(futures);
    
    // 过滤掉null结果
    for (final result in results) {
      if (result != null) {
        validPhotos.add(result);
      }
    }
    
    if (validPhotos.length != _photos.length) {
      _photos = validPhotos;
      _applySearchFilter();
      notifyListeners();
    }
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