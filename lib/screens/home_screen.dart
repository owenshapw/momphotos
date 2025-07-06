import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../services/photo_provider.dart';
import '../services/auth_service.dart';
import '../widgets/photo_grid.dart';
import '../widgets/search_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<PhotoGridContainerState> _gridKey =
      GlobalKey<PhotoGridContainerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final photoProvider = context.read<PhotoProvider>();
      if (AuthService.isLoggedIn && !photoProvider.hasLoaded) {
        photoProvider.loadPhotos(forceRefresh: false);
      }
    });
  }

  Future<void> _deleteAccount() async {
    try {
      await AuthService.deleteAccount();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('账户已注销')),
      );

      GoRouter.of(context).go('/login');
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('注销失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: IconButton(
          icon: const Icon(Icons.home),
          tooltip: '回到顶部',
          onPressed: () {
            _gridKey.currentState?.scrollToTop();
          },
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            tooltip: '用户信息',
            onSelected: (value) async {
              if (value == 'logout') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('确认登出'),
                    content: const Text('确定要退出登录吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                );
                
                if (confirmed == true) {
                  final photoProvider = context.read<PhotoProvider>();
                  final navigator = GoRouter.of(context);
                  
                  await AuthService.logout();
                  if (!mounted) return;
                  
                  photoProvider.reset();
                  if (mounted) {
                    navigator.go('/login');
                  }
                }
              } else if (value == 'delete_account') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('确认注销账户'),
                    content: const Text(
                      '⚠️ 警告：注销账户后，您的所有照片将永久删除且无法恢复！\n\n'
                      '此操作不可撤销，请谨慎考虑。',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('确认注销'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await _deleteAccount();
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'user_info',
                enabled: false,
                child: Text(
                  '当前用户: ${AuthService.currentUser?.username ?? '未知'}'
,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('退出登录', style: TextStyle(color: Colors.orange)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete_account',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('注销账户', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () {
              if (mounted) {
                context.push('/batch-upload');
              }
            },
            tooltip: '批量上传',
          ),
          IconButton(
            icon: const Icon(Icons.add_photo_alternate),
            onPressed: () {
              if (mounted) {
                context.push('/upload');
              }
            },
            tooltip: '上传照片',
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: CustomSearchBar(),
          ),
          Expanded(child: PhotoGridContainer(key: _gridKey)),
        ],
      ),
    );
  }
}

class PhotoGridContainer extends StatefulWidget {
  const PhotoGridContainer({super.key});

  @override
  State<PhotoGridContainer> createState() => PhotoGridContainerState();
}

class PhotoGridContainerState extends State<PhotoGridContainer> {
  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();
  bool _isInitialScrollDone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final photoProvider = context.watch<PhotoProvider>();
    if (photoProvider.hasLoaded && !_isInitialScrollDone) {
      _scrollToLastViewedPhoto(photoProvider);
    }
  }

  void _scrollToLastViewedPhoto(PhotoProvider photoProvider) {
    final photoId = photoProvider.lastViewedPhotoId;
    if (photoId == null) {
      _isInitialScrollDone = true;
      return;
    }

    final allPhotos = <Photo>[];
    photoProvider.photosByDecade.values.forEach(allPhotos.addAll);
    allPhotos.sort((a, b) {
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

    final index = allPhotos.indexWhere((p) => p.id == photoId);

    if (index != -1) {
      final rowIndex = index ~/ 2;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && itemScrollController.isAttached) {
          itemScrollController.scrollTo(
            index: rowIndex,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }
    _isInitialScrollDone = true;
    photoProvider.lastViewedPhotoId = null;
  }

  void scrollToTop() {
    if (itemScrollController.isAttached) {
      itemScrollController.scrollTo(
        index: 0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        final photoProvider = context.read<PhotoProvider>();
        setState(() {
          _isInitialScrollDone = false;
        });
        await photoProvider.loadPhotos(forceRefresh: true);
      },
      child: Consumer<PhotoProvider>(
        builder: (context, photoProvider, child) {
          if (photoProvider.isLoading && !photoProvider.hasLoaded) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    '正在加载照片...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          if (photoProvider.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text('加载失败',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        photoProvider.error!,
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            photoProvider.clearError();
                            photoProvider.loadPhotos();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('重试'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          if (photoProvider.photos.isEmpty && photoProvider.hasLoaded) {
            return const Center(child: Text('暂无照片'));
          }

          return PhotoGrid(
            photos: photoProvider.photosByDecade,
            itemScrollController: itemScrollController,
            itemPositionsListener: itemPositionsListener,
          );
        },
      ),
    );
  }
}