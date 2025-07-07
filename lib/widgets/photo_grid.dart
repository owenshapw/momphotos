import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
// 添加这一行
import '../models/photo.dart';

class PhotoGrid extends StatelessWidget {
  final List<Photo> photos;
  final ItemScrollController? itemScrollController;
  final ItemPositionsListener? itemPositionsListener;
  final void Function(Photo photo)? onPhotoTap;

  const PhotoGrid({
    super.key,
    required this.photos,
    this.itemScrollController,
    this.itemPositionsListener,
    this.onPhotoTap,
  });

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      // 空状态已移至 HomeScreen，此处保留一个简单的备用
      return const Center(child: Text('没有照片可显示'));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ScrollablePositionedList.builder(
        itemCount: (photos.length / 2).ceil(),
        itemScrollController: itemScrollController,
        itemPositionsListener: itemPositionsListener,
        itemBuilder: (context, index) {
          final int firstIndex = index * 2;
          final int secondIndex = firstIndex + 1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: PhotoCard(
                      photo: photos[firstIndex],
                      allPhotos: photos,
                      onTap: () {
                        if (onPhotoTap != null) {
                          onPhotoTap!(photos[firstIndex]);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: secondIndex < photos.length
                      ? Padding(
                          padding: const EdgeInsets.all(2),
                          child: PhotoCard(
                            photo: photos[secondIndex],
                            allPhotos: photos,
                            onTap: () {
                              if (onPhotoTap != null) {
                                onPhotoTap!(photos[secondIndex]);
                              }
                            },
                          ),
                        )
                      : const SizedBox(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class PhotoCard extends StatelessWidget {
  final Photo photo;
  final List<Photo> allPhotos;
  final VoidCallback onTap;

  const PhotoCard({
    super.key,
    required this.photo,
    required this.allPhotos,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.1 * 255).round()),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            color: Colors.grey[50],
            child: CachedNetworkImage(
              imageUrl: photo.thumbnailUrl ?? photo.url,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[50],
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.grey,
                    size: 24,
                  ),
                ),
              ),
              httpHeaders: const {
                'User-Agent': 'Mozilla/5.0 (compatible; Flutter Web)',
              },
              cacheKey: '${photo.id}_thumb',
              memCacheWidth: 600, // 优化内存缓存大小
              memCacheHeight: 800,
            ),
          ),
        ),
      ),
    );
  }
}
 