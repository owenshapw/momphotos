import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/photo.dart';
import 'api_service.dart';

class PhotoProvider with ChangeNotifier {
  List<Photo> _photos = [];
  List<Photo> _filteredPhotos = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  // Getters
  List<Photo> get photos => _photos;
  List<Photo> get filteredPhotos => _filteredPhotos;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;

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
    
    // 按年代排序
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == '未知年代') return 1;
        if (b == '未知年代') return -1;
        return b.compareTo(a); // 降序排列
      });
    
    return Map.fromEntries(
      sortedKeys.map((key) => MapEntry(key, grouped[key]!)),
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
  Future<void> loadPhotos() async {
    _setLoading(true);
    _error = null;
    
    try {
      _photos = await ApiService.getPhotos();
      _applySearchFilter();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // 搜索照片
  Future<void> searchPhotos(String query) async {
    _searchQuery = query.trim();
    
    if (_searchQuery.isEmpty) {
      _filteredPhotos = _photos;
    } else {
      _setLoading(true);
      _error = null;
      
      try {
        _filteredPhotos = await ApiService.searchPhotos(_searchQuery);
        notifyListeners();
      } catch (e) {
        _error = e.toString();
        notifyListeners();
      } finally {
        _setLoading(false);
      }
    }
    
    notifyListeners();
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

  // 更新照片标签
  Future<void> updatePhotoTags({
    required String photoId,
    required List<String> tags,
    int? year,
  }) async {
    _setLoading(true);
    _error = null;
    
    try {
      final updatedPhoto = await ApiService.updatePhotoTags(
        photoId: photoId,
        tags: tags,
        year: year,
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

  // 应用搜索过滤器
  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredPhotos = _photos;
    } else {
      _filteredPhotos = _photos.where((photo) {
        return photo.tags.any((tag) =>
            tag.toLowerCase().contains(_searchQuery.toLowerCase()));
      }).toList();
    }
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
} 