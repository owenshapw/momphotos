import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer; // 添加这一行
import '../models/photo.dart';
import '../services/photo_provider.dart';
import 'package:provider/provider.dart';



class PhotoDetailScreen extends StatefulWidget {
  final Photo photo;
  final List<Photo> photos;

  const PhotoDetailScreen({
    super.key,
    required this.photo,
    required this.photos,
  });

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  late PageController _pageController;
  late int _currentIndex;
  final _preloadedIndices = <int>{};
  late List<Photo> allPhotos;

  @override
  void initState() {
    super.initState();
    // 获取当前照片在列表中的索引
    _currentIndex = widget.photos.indexWhere((photo) => photo.id == widget.photo.id);
    if (_currentIndex == -1) _currentIndex = 0;
    _pageController = PageController(initialPage: _currentIndex);
    // 设置初始查看的照片ID
    if (widget.photos.isNotEmpty) {
      context.read<PhotoProvider>().lastViewedPhotoId = widget.photos[_currentIndex].id;
    }
    // 优先用Provider的照片列表（如有更新），否则用传递的参数
    final providerPhotos = context.read<PhotoProvider>().photos;
    if (providerPhotos.isNotEmpty) {
      allPhotos = providerPhotos;
      // 重新定位索引
      _currentIndex = providerPhotos.indexWhere((photo) => photo.id == widget.photo.id);
      if (_currentIndex == -1) _currentIndex = 0;
      _pageController = PageController(initialPage: _currentIndex);
    } else {
      allPhotos = widget.photos;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 预加载相邻的照片
    _preloadAdjacentImages(widget.photos);
  }

  // 预加载相邻的照片
  void _preloadAdjacentImages(List<Photo> allPhotos) {
    if (allPhotos.isEmpty) return;
    
    // 预加载当前照片和相邻的照片
    final indicesToPreload = <int>[];
    
    // 当前照片
    indicesToPreload.add(_currentIndex);
    
    // 前一张照片
    if (_currentIndex > 0) {
      indicesToPreload.add(_currentIndex - 1);
    }
    
    // 后一张照片
    if (_currentIndex < allPhotos.length - 1) {
      indicesToPreload.add(_currentIndex + 1);
    }
    
    // 预加载图片
    for (final index in indicesToPreload) {
      if (index >= 0 && index < allPhotos.length && !_preloadedIndices.contains(index)) {
        _preloadedIndices.add(index);
        precacheImage(
          CachedNetworkImageProvider(
            allPhotos[index].url,
            cacheKey: allPhotos[index].id,
          ),
          context,
        );
      }
    }
  }

  // 页面变化时预加载相邻照片
  void _preloadAdjacentImagesOnPageChange(List<Photo> allPhotos, int index) {
    if (allPhotos.isEmpty) return;
    
    // 预加载当前照片和相邻的照片
    final indicesToPreload = <int>[];
    
    // 当前照片
    indicesToPreload.add(index);
    
    // 前一张照片
    if (index > 0) {
      indicesToPreload.add(index - 1);
    }
    
    // 后一张照片
    if (index < allPhotos.length - 1) {
      indicesToPreload.add(index + 1);
    }
    
    // 预加载图片
    for (final index in indicesToPreload) {
      if (index >= 0 && index < allPhotos.length && !_preloadedIndices.contains(index)) {
        _preloadedIndices.add(index);
        precacheImage(
          CachedNetworkImageProvider(
            allPhotos[index].url,
            cacheKey: allPhotos[index].id,
          ),
          context,
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildLoadingIndicator(ImageChunkEvent? event) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 4,
              value: event?.expectedTotalBytes != null
                  ? event!.cumulativeBytesLoaded / event.expectedTotalBytes!
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '正在加载照片...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorIndicator() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.white,
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            '加载失败',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoInfo(Photo photo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photo.year != null) ...[
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                '拍摄年代: ${photo.year}年',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (photo.description != null && photo.description!.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.description, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  photo.description!,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              '上传时间: ${_formatDate(photo.createdAt)}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _downloadPhoto(Photo photo) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在下载照片...')),
      );
      final response = await http.get(Uri.parse(photo.url));
      if (response.statusCode == 200) {
        if (kIsWeb) {
          // Web download logic can be added here
        } else {
          await _downloadPhotoMobile(response.bodyBytes, photo.id);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('照片下载成功！')),
          );
        }
      } else {
        throw Exception('下载失败');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _downloadPhotoMobile(Uint8List bytes, String photoId) async {
    try {
      final status = await Permission.storage.status;
      if (!status.isGranted) {
        final result = await Permission.storage.request();
        if (!result.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('需要存储权限才能保存照片')),
            );
          }
          return;
        }
      }
      final result = await ImageGallerySaver.saveImage(
        bytes,
        quality: 100,
        name: 'photo_$photoId',
      );
      if (result['isSuccess'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('照片已保存到相册')),
          );
        }
      } else {
        throw Exception('保存失败');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always get the latest photos from the provider
    final photoProvider = context.watch<PhotoProvider>();
    final currentPhotos = photoProvider.photos;

    // If the current index is out of bounds, reset it safely.
    if (_currentIndex >= currentPhotos.length) {
      _currentIndex = currentPhotos.isNotEmpty ? currentPhotos.length - 1 : 0;
    }
    
    if (currentPhotos.isEmpty) {
      // This handles the case where the last photo was deleted.
      // We use a post-frame callback to pop safely after the build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if(mounted) context.pop();
      });
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => _onBack(currentPhotos),
        ),
        title: Text(
          '${_currentIndex + 1} / ${currentPhotos.length}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        actions: [
          // ... (IconButton actions remain the same)
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () => _downloadPhoto(currentPhotos[_currentIndex]),
            tooltip: '下载照片',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () => _deletePhoto(context, currentPhotos, currentPhotos[_currentIndex]),
            tooltip: '删除照片',
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () async {
              final photoProvider = context.read<PhotoProvider>();
              final currentPhotoId = photoProvider.photos[_currentIndex].id; // Get ID of current photo

              await context.push('/photo-edit', extra: {
                'photo': photoProvider.photos[_currentIndex], // Pass the current photo
              });

              if (mounted) {
                // After returning, find the updated index of the *same* photo
                final updatedPhotos = photoProvider.photos; // Get the potentially re-sorted list
                final newIndex = updatedPhotos.indexWhere((p) => p.id == currentPhotoId);

                if (newIndex != -1 && newIndex != _currentIndex) {
                  // If the photo moved, update _currentIndex and jump the PageController
                  setState(() {
                    _currentIndex = newIndex;
                  });
                  _pageController.jumpToPage(newIndex);
                } else if (newIndex != -1 && newIndex == _currentIndex) {
                  // If photo didn't move but its data changed, just force a rebuild
                  setState(() {});
                }
                // If newIndex is -1, it means the photo was deleted, which is handled by the build method's empty check.
              }
            },
          ),
        ],
      ),
      body: KeyboardListener(
        focusNode: FocusNode(),
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey.keyLabel == 'Arrow Left' && _currentIndex > 0) {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            } else if (event.logicalKey.keyLabel == 'Arrow Right' && _currentIndex < currentPhotos.length - 1) {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          }
        },
        child: Column(
        children: [
          // 照片查看区域
          Expanded(
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                        context.read<PhotoProvider>().lastViewedPhotoId = currentPhotos[index].id;
                      });
                      _preloadAdjacentImagesOnPageChange(currentPhotos, index);
                    },
                    itemCount: currentPhotos.length,
                    physics: _currentIndex == 0 && currentPhotos.length == 1
                        ? const NeverScrollableScrollPhysics()
                        : const ClampingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final photo = currentPhotos[index];
                      return Hero(
                        tag: photo.id,
                        child: PhotoView(
                          key: ValueKey(photo.id),
                          imageProvider: CachedNetworkImageProvider(
                            photo.url,
                            cacheKey: '${photo.id}_original',
                          ),
                          minScale: PhotoViewComputedScale.contained,
                          maxScale: PhotoViewComputedScale.covered * 2,
                          backgroundDecoration: const BoxDecoration(
                            color: Colors.black,
                          ),
                          loadingBuilder: (context, event) => _buildLoadingIndicator(event),
                          errorBuilder: (context, error, stackTrace) => _buildErrorIndicator(),
                        ),
                      );
                    },
                  ),
                  
                  // ... (Indicators remain the same)
                ],
            ),
          ),
          
          // 照片信息区域
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  // ... (Page indicator remains the same)
                  
                  // 当前照片信息
                  _buildPhotoInfo(currentPhotos[_currentIndex]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  

  // ... (buildLoadingIndicator, buildErrorIndicator, _buildPhotoInfo, _formatDate, _downloadPhoto methods remain the same)

  Future<void> _deletePhoto(BuildContext context, List<Photo> currentPhotos, Photo photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这张照片吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final photoProvider = Provider.of<PhotoProvider>(context, listen: false);
    final initialIndex = _currentIndex;

    try {
      await photoProvider.deletePhoto(photo.id);
      if (!mounted) return;

      // After deletion, the provider's list is already updated.
      // The `watch` in the build method will handle the rebuild.
      // We just need to adjust the index locally.
      
      final newTotal = currentPhotos.length - 1;
      if (newTotal <= 0) {
        // If no photos left, we will pop in the build method.
        return;
      }

      final nextIndex = initialIndex >= newTotal
          ? newTotal - 1
          : initialIndex;

      // We don't need to call setState, as the provider will notify.
      // But we need to jump the page controller to the correct new index.
      _pageController.jumpToPage(nextIndex);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('照片已删除')),
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: ${e.toString()}')),
        );
      }
    }
  }

  void _onBack(List<Photo> currentPhotos) {
    final photoProvider = context.read<PhotoProvider>();
    if (currentPhotos.isNotEmpty && _currentIndex < currentPhotos.length) {
      photoProvider.setScrollTarget(currentPhotos[_currentIndex].id);
    } else {
      photoProvider.setScrollTarget(null);
    }
    context.pop();
  }
}
