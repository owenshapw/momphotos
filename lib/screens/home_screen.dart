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
  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();

  @override
  void initState() {
    super.initState();
    // 首次加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final photoProvider = context.read<PhotoProvider>();
      if (AuthService.isLoggedIn && !photoProvider.hasLoaded) {
        photoProvider.loadPhotos(forceRefresh: false);
      }
    });
  }

  void _scrollToPhoto(String photoId) {
    final photos = context.read<PhotoProvider>().filteredPhotos;
    final index = photos.indexWhere((p) => p.id == photoId);

    if (index != -1) {
      final rowIndex = index ~/ 2;
      if (itemScrollController.isAttached) {
        itemScrollController.scrollTo(
          index: rowIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.5, // 滚动到屏幕中间
        );
      }
    }
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
    final photoProvider = context.watch<PhotoProvider>();

    return Scaffold(
      appBar: AppBar(
        title: IconButton(
          icon: const Icon(Icons.home),
          tooltip: '回到顶部',
          onPressed: scrollToTop,
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
                          child: const Text('取消')),
                      TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('确定')),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await _logout();
                }
              } else if (value == 'delete_account') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('确认注销账户'),
                    content: const Text(
                        '⚠️ 警告：注销账户后，您的所有照片将永久删除且无法恢复！\n\n此操作不可撤销，请谨慎考虑。'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('取消')),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('确认注销'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) await _deleteAccount();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'user_info',
                enabled: false,
                child: Text(
                    '当前用户: ${AuthService.currentUser?.username ?? '未知'}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('退出登录', style: TextStyle(color: Colors.orange))
                ]),
              ),
              const PopupMenuItem(
                value: 'delete_account',
                child: Row(children: [
                  Icon(Icons.delete_forever, color: Colors.red),
                  SizedBox(width: 8),
                  Text('注销账户', style: TextStyle(color: Colors.red))
                ]),
              ),
            ],
          ),
          IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: () => context.push('/batch-upload'),
              tooltip: '批量上传'),
          IconButton(
              icon: const Icon(Icons.add_photo_alternate),
              onPressed: () => context.push('/upload'),
              tooltip: '上传照片'),
        ],
      ),
      body: Column(
        children: [
          const Padding(
              padding: EdgeInsets.all(16.0), child: CustomSearchBar()),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await photoProvider.loadPhotos(forceRefresh: true);
              },
              child: Builder(
                builder: (context) {
                  if (photoProvider.isLoading && !photoProvider.hasLoaded) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('正在加载照片...', 
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey)),
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
                            Icon(Icons.error_outline,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text('加载失败',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.grey[600])),
                            const SizedBox(height: 8),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(photoProvider.error!,
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 14),
                                  textAlign: TextAlign.center),
                            ),
                            const SizedBox(height: 16),
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
                      ),
                    );
                  }

                  final photos = photoProvider.filteredPhotos;

                  if (photos.isEmpty && photoProvider.hasLoaded) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/icon/launch_splash.png',
                              width: 150,
                              height: 150,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              '暂无照片',
                              style: TextStyle(fontSize: 22, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '请点击右上角的上传图标开始分享您的珍贵回忆',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => context.push('/upload'),
                              icon: const Icon(Icons.add_photo_alternate),
                              label: const Text('上传第一张照片'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                textStyle: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return PhotoGrid(
                    photos: photos,
                    itemScrollController: itemScrollController,
                    itemPositionsListener: itemPositionsListener,
                    onPhotoReturned: (photoId) {
                      _scrollToPhoto(photoId);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    if (!mounted) return;
    final photoProvider = context.read<PhotoProvider>();
    final goRouter = GoRouter.of(context);
    await AuthService.logout();
    if (!mounted) return;
    photoProvider.reset();
    goRouter.go('/login');
  }

  void _scrollToLastViewedPhoto(PhotoProvider photoProvider) {
    final photoId = photoProvider.lastViewedPhotoId;
    if (photoId == null) {
      return;
    }

    final photos = photoProvider.filteredPhotos;
    final index = photos.indexWhere((p) => p.id == photoId);

    if (index != -1) {
      final rowIndex = index ~/ 2;
      
      // 使用addPostFrameCallback确保在UI渲染完成后再滚动
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && itemScrollController.isAttached) {
          itemScrollController.scrollTo(
            index: rowIndex,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.5, // 滚动到屏幕中间，提供更好的上下文
          );
          // 关键修复：只有在滚动指令成功发出后，才清除标记
          photoProvider.lastViewedPhotoId = null;
        }
      });
    } else {
      // 如果在当前列表中找不到照片，也清除标记，避免无效循环
      photoProvider.lastViewedPhotoId = null;
    }
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
}