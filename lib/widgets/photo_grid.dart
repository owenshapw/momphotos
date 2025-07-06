import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../models/photo.dart';

class PhotoGrid extends StatefulWidget {
  final Map<String, List<Photo>> photos;
  final ItemScrollController? itemScrollController;
  final ItemPositionsListener? itemPositionsListener;

  const PhotoGrid({
    super.key,
    required this.photos,
    this.itemScrollController,
    this.itemPositionsListener,
  });

  @override
  PhotoGridState createState() => PhotoGridState();
}

class PhotoGridState extends State<PhotoGrid> {
  final List<Photo> _allPhotos = [];

  @override
  void initState() {
    super.initState();
    _initializePhotos();
  }

  @override
  void didUpdateWidget(PhotoGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!const MapEquality().equals(oldWidget.photos, widget.photos)) {
      _initializePhotos();
    }
  }

  void _initializePhotos() {
    _allPhotos.clear();
    widget.photos.values.forEach((photoList) {
      _allPhotos.addAll(photoList);
    });
    _allPhotos.sort((a, b) {
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
    if (mounted) {
      setState(() {});
    }
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

    return ScrollablePositionedList.builder(
      itemCount: (_allPhotos.length / 2).ceil(),
      itemScrollController: widget.itemScrollController,
      itemPositionsListener: widget.itemPositionsListener,
      itemBuilder: (context, index) {
        final int firstIndex = index * 2;
        final int secondIndex = firstIndex + 1;
        return Row(
          children: [
            Expanded(
              child: PhotoCard(
                photo: _allPhotos[firstIndex],
                allPhotos: _allPhotos,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: secondIndex < _allPhotos.length
                  ? PhotoCard(
                      photo: _allPhotos[secondIndex],
                      allPhotos: _allPhotos,
                    )
                  : const SizedBox(),
            ),
          ],
        );
      },
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
              color: Colors.black.withOpacity(0.1),
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
 