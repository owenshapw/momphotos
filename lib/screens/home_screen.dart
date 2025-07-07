import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'dart:developer' as developer; // 添加这一行
import '../services/photo_provider.dart';
import '../services/auth_service.dart';
import '../widgets/photo_grid.dart';
import '../widgets/search_bar.dart';
import '../models/photo.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 首次加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final photoProvider = context.read<PhotoProvider>();
      if (AuthService.isLoggedIn && !photoProvider.hasLoaded) {
        photoProvider.loadPhotos(forceRefresh: true); // 强制刷新，确保登录后拉取
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      developer.log('HomeScreen: didChangeAppLifecycleState - 应用从后台恢复。');
      final photoProvider = context.read<PhotoProvider>();
      if (photoProvider.lastViewedPhotoId != null) {
        developer.log('HomeScreen: didChangeAppLifecycleState - 检测到 lastViewedPhotoId: ${photoProvider.lastViewedPhotoId}，尝试滚动。');
        _scrollToLastViewedPhoto(photoProvider);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = GoRouterState.of(context).extra as Map?;
    final scrollToId = args != null ? args['scrollToId'] : null;
    if (scrollToId != null) {
      final photos = context.read<PhotoProvider>().photos;
      final index = photos.indexWhere((p) => p.id == scrollToId);
      if (index != -1 && itemScrollController.isAttached) {
        // 由于每行2张，需滚动到对应行
        itemScrollController.scrollTo(index: index ~/ 2, duration: Duration(milliseconds: 300));
      }
    }
  }

  void _scrollToLastViewedPhoto(PhotoProvider photoProvider) {
    final photoId = photoProvider.lastViewedPhotoId;
    developer.log('HomeScreen: _scrollToLastViewedPhoto - 尝试滚动到照片ID: $photoId');
    if (photoId == null) {
      developer.log('HomeScreen: _scrollToLastViewedPhoto - photoId 为空，不执行滚动。');
      return;
    }

    final photos = photoProvider.filteredPhotos;
    final index = photos.indexWhere((p) => p.id == photoId);
    developer.log('HomeScreen: _scrollToLastViewedPhoto - 找到照片索引: $index');

    if (index != -1) {
      final rowIndex = index ~/ 2;
      developer.log('HomeScreen: _scrollToLastViewedPhoto - 计算出行索引: $rowIndex');
      
      // 使用addPostFrameCallback确保在UI渲染完成后再滚动
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && itemScrollController.isAttached) {
          developer.log('HomeScreen: _scrollToLastViewedPhoto - 执行滚动到索引: $rowIndex');
          itemScrollController.scrollTo(
            index: rowIndex,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.5, // 滚动到屏幕中间，提供更好的上下文
          );
          // 关键修复：只有在滚动指令成功发出后，才清除标记
          photoProvider.lastViewedPhotoId = null;
          developer.log('HomeScreen: _scrollToLastViewedPhoto - 滚动完成，清除 lastViewedPhotoId。');
        } else {
          developer.log('HomeScreen: _scrollToLastViewedPhoto - 无法滚动：mounted: $mounted, isAttached: ${itemScrollController.isAttached}');
        }
      });
    } else {
      // 如果在当前列表中找不到照片，也清除标记，避免无效循环
      photoProvider.lastViewedPhotoId = null;
      developer.log('HomeScreen: _scrollToLastViewedPhoto - 未找到照片，清除 lastViewedPhotoId。');
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
                await context.read<PhotoProvider>().loadPhotos(forceRefresh: true);
              },
              child: Builder(
                builder: (context) {
                  final photoProvider = context.watch<PhotoProvider>();
                  final photos = photoProvider.filteredPhotos;

                  // 兜底：如果已登录但还没加载且没在加载，自动拉取
                  if (AuthService.isLoggedIn && !photoProvider.hasLoaded && !photoProvider.isLoading) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      context.read<PhotoProvider>().loadPhotos(forceRefresh: true);
                    });
                  }

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
                    // 新增：如果是未登录错误，弹窗提示而不是直接跳转
                    if (photoProvider.error!.contains('未登录') || photoProvider.error!.contains('401')) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (ScaffoldMessenger.of(context).mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('登录状态已失效，请重新登录')),
                          );
                        }
                        // 可选：自动登出并跳转登录页（如需自动跳转可放开下面两行）
                        // context.read<PhotoProvider>().reset();
                        // GoRouter.of(context).go('/login');
                      });
                    }
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

                  if (photos.isEmpty && photoProvider.hasLoaded) {
                    return Container(
                      color: const Color(0xFFF4F7F6), // mom.png底色
                      width: double.infinity,
                      height: double.infinity,
                      child: Column(
                        children: [
                          const Spacer(flex: 2),
                          Image.asset(
                            'assets/icon/mom.png',
                            width: 200,
                            height: 200,
                          ),
                          const SizedBox(height: 32),
                          Text(
                            '点击右上角图标上传照片',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                          const Spacer(flex: 3), // 让内容整体偏上
                        ],
                      ),
                    );
                  }

                  // 1. 定义打开详情页的方法，带参数跳转并处理返回
                  void openPhotoDetail(Photo photo, List<Photo> photos) async {
                    final result = await context.push('/photo-detail', extra: {
                      'photo': photo,
                      'photos': photos,
                    });
                    if (result is Map && result['scrollToId'] != null) {
                      final scrollToId = result['scrollToId'];
                      if (scrollToId != null) {
                        // 自动滚动到目标照片
                        final index = photos.indexWhere((p) => p.id == scrollToId);
                        if (index != -1) {
                          itemScrollController.scrollTo(index: index, duration: const Duration(milliseconds: 400));
                        }
                      }
                    }
                  }

                  // 2. 传递openPhotoDetail给PhotoGrid，点击缩略图时调用
                  return PhotoGrid(
                    photos: photos,
                    itemScrollController: itemScrollController,
                    itemPositionsListener: itemPositionsListener,
                    onPhotoTap: (photo) => openPhotoDetail(photo, photos), // 传递点击回调
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
    try {
      if (!mounted) return;
      final photoProvider = context.read<PhotoProvider>();
      final goRouter = GoRouter.of(context);
      await AuthService.logout();
      if (!mounted) return;
      photoProvider.reset();
      goRouter.go('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登出失败: ${e.toString()}')),
        );
      }
    }
  }
}