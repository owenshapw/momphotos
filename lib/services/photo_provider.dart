import 'dart:io';
import 'dart:developer' as developer;
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
  bool _hasLoaded = false;
  String? _lastLoadedUserId;
  String? lastViewedPhotoId;

  List<Photo> get photos => _photos;
  List<Photo> get filteredPhotos => _filteredPhotos;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  List<String> get searchHistory => List.unmodifiable(_searchHistory);
  bool get hasLoaded => _hasLoaded;

  Set<String> get allTags {
    final Set<String> tags = {};
    for (final photo in _photos) {
      tags.addAll(photo.tags);
    }
    return tags;
  }

  Future<void> loadPhotos({bool forceRefresh = false}) async {
    final currentUserId = AuthService.currentUser?.id;

    if (_lastLoadedUserId == null && currentUserId != null) {
      _lastLoadedUserId = currentUserId;
    }

    if (currentUserId != null &&
        _lastLoadedUserId != null &&
        _lastLoadedUserId != currentUserId) {
      developer.log('🔄 真实用户切换，重置 PhotoProvider 状态');
      reset();
      _lastLoadedUserId = currentUserId;
      forceRefresh = true;
    }

    if (_hasLoaded && !forceRefresh && _photos.isNotEmpty) {
      return;
    }

    _setLoading(true);
    _error = null;

    try {
      final allPhotos = await ApiService.getPhotos(forceRefresh: forceRefresh);
      _photos = _sortPhotos(allPhotos);
      _applySearchFilter();
      _hasLoaded = true;
      _lastLoadedUserId = currentUserId;
      developer.log('📸 照片加载完成: ${_photos.length} 张照片 (用户ID: $currentUserId)');
    } catch (e) {
      await _handleApiError(e);
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> refreshPhotos() async {
    _setLoading(true);
    _error = null;

    try {
      final updatedPhotos = await ApiService.getPhotos(forceRefresh: true);
      _photos = _sortPhotos(updatedPhotos);
      _applySearchFilter();
      _hasLoaded = true;
      developer.log('🔄 照片刷新完成，共 ${_photos.length} 张');
    } catch (e) {
      await _handleApiError(e);
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

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
  }

  void _applyLocalSearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredPhotos = _photos;
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredPhotos = _photos.where((photo) {
        final tagMatch = photo.tags.any((tag) => tag.toLowerCase().contains(query));
        final yearMatch = photo.year != null && photo.year.toString().contains(query);
        final decadeMatch = photo.decadeGroup.toLowerCase().contains(query);
        final decadeNumberMatch = photo.year != null && query.contains(photo.year.toString());
        final descriptionMatch = photo.description?.toLowerCase().contains(query) ?? false;
        return tagMatch || yearMatch || decadeMatch || decadeNumberMatch || descriptionMatch;
      }).toList();
    }
  }

  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredPhotos = _photos;
    } else {
      _applyLocalSearchFilter();
    }
  }

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
      await refreshPhotos(); // 使用更安全的刷新逻辑
      return photo;
    } catch (e) {
      await _handleApiError(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deletePhoto(String photoId) async {
    _setLoading(true);
    _error = null;
    try {
      await ApiService.deletePhoto(photoId);
      _photos.removeWhere((photo) => photo.id == photoId);
      _applySearchFilter();
    } catch (e) {
      await _handleApiError(e);
      rethrow;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

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
      final index = _photos.indexWhere((photo) => photo.id == photoId);
      if (index != -1) {
        _photos[index] = updatedPhoto;
        _photos = _sortPhotos(_photos);
        _applySearchFilter();
      }
    } catch (e) {
      await _handleApiError(e);
      rethrow;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchQuery = '';
    _filteredPhotos = _photos;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _photos.clear();
    _filteredPhotos.clear();
    _isLoading = false;
    _error = null;
    _searchQuery = '';
    _hasLoaded = false;
    _lastLoadedUserId = null;
    ApiService.clearCache();
    notifyListeners();
    developer.log('🔄 PhotoProvider状态已重置');
  }

  void clearImageCache() {
    notifyListeners();
  }

  void _addToSearchHistory(String query) {
    if (query.trim().isNotEmpty) {
      _searchHistory.remove(query.trim());
      _searchHistory.insert(0, query.trim());
      if (_searchHistory.length > 10) {
        _searchHistory = _searchHistory.take(10).toList();
      }
    }
  }

  void clearSearchHistory() {
    _searchHistory.clear();
    notifyListeners();
  }

  void setLastViewedPhotoId(String? id) {
    lastViewedPhotoId = id;
    notifyListeners();
  }

  List<Photo> _sortPhotos(List<Photo> photos) {
    photos.sort((a, b) {
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
    return photos;
  }

  Future<void> _handleApiError(dynamic e) async {
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
    } else {
      _error = e.toString();
      developer.log('❌ API错误: $e');
    }
  }
}