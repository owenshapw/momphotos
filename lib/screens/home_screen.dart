import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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
  final GlobalKey<PhotoGridState> _photoGridKey = GlobalKey<PhotoGridState>();

  @override
  void initState() {
    super.initState();
    // 确保用户登录后能正确加载照片
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final photoProvider = context.read<PhotoProvider>();
      if (AuthService.isLoggedIn && !photoProvider.hasLoaded) {
        photoProvider.loadPhotos(forceRefresh: true);
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
      
      if (mounted) {
        context.go('/login');
      }
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
            _photoGridKey.currentState?.scrollToTop();
          },
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // 用户信息按钮
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
                  await AuthService.logout();
                  if (!mounted) return;
                  photoProvider.reset();
                  if (mounted) {
                    context.go('/login');
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
                  '当前用户: ${AuthService.currentUser?.username ?? '未知'}',
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
          // 批量上传按钮
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () {
              if (mounted) {
                context.push('/batch-upload');
              }
            },
            tooltip: '批量上传',
          ),
          // 单张上传按钮
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
          // 搜索栏
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: CustomSearchBar(),
          ),
          
          // 照片网格
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                final photoProvider = context.read<PhotoProvider>();
                await photoProvider.loadPhotos(forceRefresh: true);
              },
              child: Consumer<PhotoProvider>(
                builder: (context, photoProvider, child) {
                  // 如果正在加载但已有数据，显示现有数据
                  if (photoProvider.isLoading && photoProvider.hasLoaded && photoProvider.photos.isNotEmpty) {
                    return PhotoGrid(key: _photoGridKey, photos: photoProvider.photosByDecade);
                  }
                  
                  // 如果正在加载且没有数据，显示简单加载指示器
                  if (photoProvider.isLoading && !photoProvider.hasLoaded) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            '正在加载照片...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (photoProvider.error != null) {
                    return SingleChildScrollView(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '加载失败',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  photoProvider.error!,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                  ),
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
                                  const SizedBox(width: 12),
                                  TextButton.icon(
                                    onPressed: () {
                                      photoProvider.clearError();
                                      // 延迟重试
                                      Future.delayed(const Duration(seconds: 2), () {
                                        if (mounted) {
                                          photoProvider.loadPhotos();
                                        }
                                      });
                                    },
                                    icon: const Icon(Icons.schedule),
                                    label: const Text('稍后重试'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  if (photoProvider.filteredPhotos.isEmpty) {
                    return SingleChildScrollView(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                photoProvider.searchQuery.isEmpty
                                    ? Icons.add_photo_alternate
                                    : Icons.search_off,
                                size: 64,
                                color: photoProvider.searchQuery.isEmpty
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                photoProvider.searchQuery.isEmpty
                                    ? '开始上传您的第一张照片'
                                    : '未找到相关照片',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: photoProvider.searchQuery.isEmpty
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey[600],
                                  fontWeight: photoProvider.searchQuery.isEmpty
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              if (photoProvider.searchQuery.isEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '上传照片，记录美好时光',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        if (mounted) {
                                          context.push('/upload');
                                        }
                                      },
                                      icon: const Icon(Icons.add_photo_alternate),
                                      label: const Text('上传单张'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        if (mounted) {
                                          context.push('/batch-upload');
                                        }
                                      },
                                      icon: const Icon(Icons.upload_file),
                                      label: const Text('批量上传'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Theme.of(context).colorScheme.primary,
                                        side: BorderSide(color: Theme.of(context).colorScheme.primary),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  margin: const EdgeInsets.symmetric(horizontal: 32),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.lightbulb_outline,
                                            size: 20,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '上传提示',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '• 支持单张或批量上传照片\n'
                                        '• 添加标签便于搜索和分类\n'
                                        '• 设置拍摄年代记录时间\n'
                                        '• 添加描述保存美好回忆',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                          height: 1.4,
                                        ),
                                        textAlign: TextAlign.left,
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 8),
                                Text(
                                  '搜索关键词: "${photoProvider.searchQuery}"',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  margin: const EdgeInsets.symmetric(horizontal: 32),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        '搜索提示:',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '• 人物姓名（如：张三、李四）\n'
                                        '• 拍摄年代（如：2020、2020年）\n'
                                        '• 年代分组（如：2020年代、1990年代）\n'
                                        '• 照片简介中的关键词',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          height: 1.4,
                                        ),
                                        textAlign: TextAlign.left,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return PhotoGrid(key: _photoGridKey, photos: photoProvider.photosByDecade);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
} 