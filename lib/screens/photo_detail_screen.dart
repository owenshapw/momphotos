import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/photo.dart';
import '../services/photo_provider.dart';
import '../screens/photo_edit_screen.dart';

class PhotoDetailScreen extends StatefulWidget {
  final Photo photo;

  const PhotoDetailScreen({
    super.key,
    required this.photo,
  });

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    // 获取当前照片在列表中的索引
    final photoProvider = context.read<PhotoProvider>();
    final allPhotos = photoProvider.filteredPhotos.isNotEmpty 
        ? photoProvider.filteredPhotos 
        : photoProvider.photos;
    _currentIndex = allPhotos.indexWhere((photo) => photo.id == widget.photo.id);
    if (_currentIndex == -1) _currentIndex = 0;
    
    _pageController = PageController(initialPage: _currentIndex);
    
    // 预加载相邻的照片
    _preloadAdjacentImages(allPhotos);
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
      if (index >= 0 && index < allPhotos.length) {
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
      if (index >= 0 && index < allPhotos.length) {
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
    return Consumer<PhotoProvider>(
      builder: (context, photoProvider, child) {
        final allPhotos = photoProvider.filteredPhotos.isNotEmpty 
            ? photoProvider.filteredPhotos 
            : photoProvider.photos;
        
        if (allPhotos.isEmpty) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
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
              onPressed: () => Navigator.pop(context),
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
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PhotoEditScreen(photo: allPhotos[_currentIndex]),
                    ),
                  );
                  
                  // 如果编辑成功，刷新照片数据
                  if (result == true && context.mounted) {
                    context.read<PhotoProvider>().loadPhotos();
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
                          return Stack(
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
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
                                  loadingBuilder: (context, event) {
                                    return Container(
                                      color: Colors.black,
                                      child: Stack(
                                        children: [
                                          // 背景渐变
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.grey[850]!,
                                                  Colors.black,
                                                ],
                                              ),
                                            ),
                                          ),
                                          // 主要内容
                                          Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                // 优雅的脉冲加载动画
                                                TweenAnimationBuilder<double>(
                                                  tween: Tween(begin: 0.0, end: 1.0),
                                                  duration: const Duration(milliseconds: 1500),
                                                  builder: (context, value, child) {
                                                    return Container(
                                                      width: 80,
                                                      height: 80,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        gradient: RadialGradient(
                                                          colors: [
                                                            Colors.white.withValues(alpha: 0.1 * value),
                                                            Colors.transparent,
                                                          ],
                                                        ),
                                                      ),
                                                      child: Center(
                                                        child: Container(
                                                          width: 40,
                                                          height: 40,
                                                          decoration: BoxDecoration(
                                                            shape: BoxShape.circle,
                                                            border: Border.all(
                                                              color: Colors.white.withValues(alpha: 0.3),
                                                              width: 2,
                                                            ),
                                                          ),
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            valueColor: AlwaysStoppedAnimation<Color>(
                                                              Colors.white.withValues(alpha: 0.6),
                                                            ),
                                                            value: event?.expectedTotalBytes != null
                                                                ? event!.cumulativeBytesLoaded / event.expectedTotalBytes!
                                                                : null,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                                const SizedBox(height: 24),
                                                // 加载文字
                                                AnimatedOpacity(
                                                  opacity: 1.0,
                                                  duration: const Duration(milliseconds: 500),
                                                  child: Text(
                                                    event?.expectedTotalBytes != null
                                                        ? '加载中 ${((event!.cumulativeBytesLoaded / event.expectedTotalBytes!) * 100).toInt()}%'
                                                        : '正在加载照片...',
                                                    style: TextStyle(
                                                      color: Colors.white.withValues(alpha: 0.8),
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w300,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ),
                                                if (event?.expectedTotalBytes != null) ...[
                                                  const SizedBox(height: 8),
                                                  // 进度条
                                                  Container(
                                                    width: 200,
                                                    height: 2,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(1),
                                                    ),
                                                    child: FractionallySizedBox(
                                                      alignment: Alignment.centerLeft,
                                                      widthFactor: event!.cumulativeBytesLoaded / event.expectedTotalBytes!,
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          color: Colors.white.withValues(alpha: 0.6),
                                                          borderRadius: BorderRadius.circular(1),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          // 照片占位符 - 更优雅的设计
                                          if (event?.expectedTotalBytes == null)
                                            Center(
                                              child: TweenAnimationBuilder<double>(
                                                tween: Tween(begin: 0.0, end: 1.0),
                                                duration: const Duration(milliseconds: 800),
                                                builder: (context, value, child) {
                                                  return Transform.scale(
                                                    scale: 0.8 + (0.2 * value),
                                                    child: Opacity(
                                                      opacity: value,
                                                      child: Container(
                                                        width: 180,
                                                        height: 180,
                                                        decoration: BoxDecoration(
                                                          color: Colors.grey[800]!.withValues(alpha: 0.3),
                                                          borderRadius: BorderRadius.circular(16),
                                                          border: Border.all(
                                                            color: Colors.white.withValues(alpha: 0.1),
                                                            width: 1,
                                                          ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors.black.withValues(alpha: 0.3),
                                                              blurRadius: 20,
                                                              offset: const Offset(0, 10),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Icon(
                                                          Icons.photo_library,
                                                          size: 60,
                                                          color: Colors.white.withValues(alpha: 0.4),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.black,
                                      child: Stack(
                                        children: [
                                          // 背景渐变
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.grey[850]!,
                                                  Colors.black,
                                                ],
                                              ),
                                            ),
                                          ),
                                          // 错误内容
                                          Center(
                                            child: TweenAnimationBuilder<double>(
                                              tween: Tween(begin: 0.0, end: 1.0),
                                              duration: const Duration(milliseconds: 600),
                                              builder: (context, value, child) {
                                                return Transform.scale(
                                                  scale: 0.9 + (0.1 * value),
                                                  child: Opacity(
                                                    opacity: value,
                                                    child: Container(
                                                      padding: const EdgeInsets.all(24),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red.withValues(alpha: 0.05),
                                                        borderRadius: BorderRadius.circular(20),
                                                        border: Border.all(
                                                          color: Colors.red.withValues(alpha: 0.2),
                                                          width: 1,
                                                        ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black.withValues(alpha: 0.3),
                                                            blurRadius: 20,
                                                            offset: const Offset(0, 10),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.all(16),
                                                            decoration: BoxDecoration(
                                                              color: Colors.red.withValues(alpha: 0.1),
                                                              shape: BoxShape.circle,
                                                            ),
                                                            child: Icon(
                                                              Icons.error_outline,
                                                              color: Colors.red[300],
                                                              size: 32,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 16),
                                                          Text(
                                                            '加载失败',
                                                            style: TextStyle(
                                                              color: Colors.red[300],
                                                              fontSize: 18,
                                                              fontWeight: FontWeight.w500,
                                                              letterSpacing: 0.5,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 8),
                                                          Text(
                                                            '请检查网络连接后重试',
                                                            style: TextStyle(
                                                              color: Colors.white.withValues(alpha: 0.7),
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w300,
                                                            ),
                                                            textAlign: TextAlign.center,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
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
      },
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