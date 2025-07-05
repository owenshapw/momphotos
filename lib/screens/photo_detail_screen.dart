import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/photo.dart';

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

  @override
  void initState() {
    super.initState();
    // 获取当前照片在列表中的索引
    _currentIndex = widget.photos.indexWhere((photo) => photo.id == widget.photo.id);
    if (_currentIndex == -1) _currentIndex = 0;
    
    _pageController = PageController(initialPage: _currentIndex);
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

  @override
  Widget build(BuildContext context) {
    final allPhotos = widget.photos;
    
    if (allPhotos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: Text(
            '没有照片可显示',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '${_currentIndex + 1} / ${allPhotos.length}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () async {
              await context.push('/photo-edit', extra: allPhotos[_currentIndex]);
              
              // 如果编辑成功，PhotoProvider已经处理了数据更新
              // 不需要额外操作，因为数据会自动更新
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
            } else if (event.logicalKey.keyLabel == 'Arrow Right' && _currentIndex < allPhotos.length - 1) {
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
                      });
                      
                      // 页面变化时预加载相邻照片
                      _preloadAdjacentImagesOnPageChange(allPhotos, index);
                    },
                    itemCount: allPhotos.length,
                    physics: _currentIndex == 0 && allPhotos.length == 1
                        ? const NeverScrollableScrollPhysics()
                        : const ClampingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final photo = allPhotos[index];
                      return Hero(
                        tag: photo.id,
            child: PhotoView(
                          key: ValueKey(photo.id),
                          imageProvider: CachedNetworkImageProvider(
                            photo.url,
                            cacheKey: photo.id,
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
                  
                  // 左右滑动指示器
                  if (allPhotos.length > 1) ...[
                    // 左箭头指示器
                    if (_currentIndex > 0)
                      Positioned(
                        left: 20,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: AnimatedOpacity(
                            opacity: _currentIndex > 0 ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.chevron_left,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                  
                    // 右箭头指示器
                    if (_currentIndex < allPhotos.length - 1)
                      Positioned(
                        right: 20,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: AnimatedOpacity(
                            opacity: _currentIndex < allPhotos.length - 1 ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.chevron_right,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
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
                  // 页面指示器
                  if (allPhotos.length > 1) ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.photo_library,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_currentIndex + 1} / ${allPhotos.length}',
                    style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // 当前照片信息
                  _buildPhotoInfo(allPhotos[_currentIndex]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(ImageChunkEvent? event) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 脉冲动画背景
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.1 * value),
                      Colors.transparent,
                    ],
                  ),
                ),
              );
            },
          ),
          // 进度指示器
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 背景环
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.2),
                  ),
                  value: 1.0,
                  strokeWidth: 4,
                ),
                // 进度环
                CircularProgressIndicator(
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 4,
                  value: event?.expectedTotalBytes != null
                      ? event!.cumulativeBytesLoaded / event.expectedTotalBytes!
                      : null,
                ),
                // 百分比文字
                if (event?.expectedTotalBytes != null)
                  Text(
                    '${((event!.cumulativeBytesLoaded / event.expectedTotalBytes!) * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 加载文字
          Text(
            '正在加载照片...',
                          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
                          ),
          ),
        ],
                        ),
                      );
  }

  Widget _buildErrorIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.white,
            size: 48,
                  ),
                  const SizedBox(height: 16),
          const Text(
            '加载失败',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请检查网络连接后重试',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
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
                // 年代信息
                if (photo.year != null) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '拍摄年代: ${photo.year}年',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                
                // 描述信息
                if (photo.description != null && photo.description!.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.description,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          photo.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                
                // 上传时间
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '上传时间: ${_formatDate(photo.createdAt)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
} 