import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/photo.dart';
import '../screens/photo_detail_screen.dart';
// import 'package:http/http.dart' as http; // 已移除未使用

class PhotoGrid extends StatefulWidget {
  final Map<String, List<Photo>> photos;
  const PhotoGrid({super.key, required this.photos});

  @override
  PhotoGridState createState() => PhotoGridState();
}

class PhotoGridState extends State<PhotoGrid> {
  final List<Photo> _allPhotos = []; // 按时间顺序的所有照片
  final List<Photo> _loadedPhotos = []; // 已加载的照片
  final int _batchSize = 12; // 每次加载的照片数量
  bool _isLoading = false;
  bool _hasMorePhotos = true;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _initializePhotos();
  }

  @override
  void didUpdateWidget(PhotoGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只有当照片数据真正发生变化时才重新初始化
    if (oldWidget.photos != widget.photos) {
      // 检查是否是相同照片的更新（比如编辑后的更新）
      final oldPhotoIds = _getAllPhotoIds(oldWidget.photos);
      final newPhotoIds = _getAllPhotoIds(widget.photos);
      
      // 如果照片ID集合相同，说明只是内容更新，保持当前状态
      if (oldPhotoIds.length == newPhotoIds.length && 
          oldPhotoIds.every((id) => newPhotoIds.contains(id))) {
        // 照片内容更新，保持当前状态
        return;
      }
      
      // 照片数量或ID发生变化，重新初始化
      _initializePhotos();
    }
  }

  // 获取所有照片ID的集合
  Set<String> _getAllPhotoIds(Map<String, List<Photo>> photos) {
    final Set<String> ids = {};
    for (final photoList in photos.values) {
      for (final photo in photoList) {
        ids.add(photo.id);
      }
    }
    return ids;
  }

  void _initializePhotos() {
    _allPhotos.clear();
    _loadedPhotos.clear();
    
    // 将所有照片按时间顺序排列
    final List<Photo> allPhotos = [];
    for (final photoList in widget.photos.values) {
      allPhotos.addAll(photoList);
    }
    
    // 按拍摄时间排序（从最近到以前）
    allPhotos.sort((a, b) {
      // 优先按拍摄年份排序
      if (a.year != null && b.year != null) {
        return b.year!.compareTo(a.year!);
      } else if (a.year != null) {
        return -1; // a有年份，b没有，a排在前面
      } else if (b.year != null) {
        return 1; // b有年份，a没有，b排在前面
      } else {
        // 都没有年份，按上传时间排序
        return b.createdAt.compareTo(a.createdAt);
      }
    });
    
    _allPhotos.addAll(allPhotos);
    
    // 初始加载第一批照片
    final initialPhotos = _allPhotos.take(_batchSize).toList();
    _loadedPhotos.addAll(initialPhotos);
    
    _hasMorePhotos = _allPhotos.length > _batchSize;
    _isLoading = false;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMorePhotos();
    }
  }

  void _loadMorePhotos() {
    if (_isLoading || !_hasMorePhotos) return;
    
    setState(() {
      _isLoading = true;
    });
    
    // 模拟异步加载
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      
      final currentCount = _loadedPhotos.length;
      final remainingPhotos = _allPhotos.skip(currentCount).take(_batchSize).toList();
      
      setState(() {
        _loadedPhotos.addAll(remainingPhotos);
        _isLoading = false;
        _hasMorePhotos = _loadedPhotos.length < _allPhotos.length;
      });
    });
  }

  void scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_allPhotos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '暂无照片',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 照片统计信息
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.photo_library,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '已加载 ${_loadedPhotos.length} / ${_allPhotos.length} 张照片',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (_hasMorePhotos && _isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        
        // 照片网格
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
            itemCount: _loadedPhotos.length + (_hasMorePhotos ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _loadedPhotos.length) {
                // 加载更多指示器 - 使用空白色块
                return Container(
                  color: Colors.grey[100],
                  child: const Center(
                    child: Text(
                      '加载中...',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }
              
              final photo = _loadedPhotos[index];
              return PhotoCard(photo: photo, allPhotos: _allPhotos);
            },
          ),
        ),
      ],
    );
  }
}

class PhotoCard extends StatelessWidget {
  final Photo photo;
  final List<Photo> allPhotos;

  const PhotoCard({
    super.key,
    required this.photo,
    required this.allPhotos,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoDetailScreen(
              photo: photo,
              photos: allPhotos,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: photo.url,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[100],
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[200],
              child: const Center(
                child: Icon(
                  Icons.error_outline,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 