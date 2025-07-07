import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../models/photo.dart';

class PhotoGrid extends StatelessWidget {
  final List<Photo> photos;
  final ItemScrollController? itemScrollController;
  final ItemPositionsListener? itemPositionsListener;

  const PhotoGrid({
    super.key,
    required this.photos,
    this.itemScrollController,
    this.itemPositionsListener,
  });

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
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
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: PhotoCard(
                      photo: photos[firstIndex],
                      allPhotos: photos,
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

  const PhotoCard({
    super.key,
    required this.photo,
    required this.allPhotos,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (context.mounted) {
          context.push('/photo-detail', extra: {
            'photo': photo,
            'photos': allPhotos,
          });
        }
      },
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
              errorWidget: (context, url, error) {
                if (url == photo.thumbnailUrl &&
                    photo.thumbnailUrl != photo.url) {
                  return CachedNetworkImage(
                    imageUrl: photo.url,
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
                    cacheKey: '${photo.id}_original',
                    maxWidthDiskCache: 1200,
                    maxHeightDiskCache: 1200,
                  );
                }

                return Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.grey,
                      size: 24,
                    ),
                  ),
                );
              },
              httpHeaders: const {
                'User-Agent': 'Mozilla/5.0 (compatible; Flutter Web)',
              },
              cacheKey: '${photo.id}_thumb',
              maxWidthDiskCache: 1200,
              maxHeightDiskCache: 1200,
              memCacheWidth: 1200,
              memCacheHeight: 1200,
            ),
          ),
        ),
      ),
    );
  }
}
 