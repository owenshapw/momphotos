import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/photo_provider.dart';
import '../widgets/photo_grid.dart';
import '../widgets/search_bar.dart';
import 'upload_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // 延迟加载，确保Provider完全初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 添加短暂延迟，确保网络连接稳定
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          context.read<PhotoProvider>().loadPhotos();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '妈妈的照片',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            onPressed: () async {
              // 显示确认对话框
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('清理已删除照片'),
                  content: const Text('这将检测并移除所有已删除的照片，可能需要一些时间。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('确认'),
                    ),
                  ],
                ),
              );
              
              if (confirmed == true) {
                // 显示加载指示器
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const AlertDialog(
                    content: Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('正在清理...'),
                      ],
                    ),
                  ),
                );
                
                // 执行清理
                await context.read<PhotoProvider>().filterDeletedPhotos();
                
                // 关闭加载对话框
                if (mounted) {
                  Navigator.pop(context);
                  
                  // 显示完成提示
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('清理完成'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
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
                await context.read<PhotoProvider>().loadPhotos();
              },
              child: Consumer<PhotoProvider>(
                builder: (context, photoProvider, child) {
                  if (photoProvider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (photoProvider.error != null) {
                    return Center(
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
                    );
                  }

                  if (photoProvider.filteredPhotos.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            photoProvider.searchQuery.isEmpty
                                ? Icons.photo_library_outlined
                                : Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            photoProvider.searchQuery.isEmpty
                                ? '暂无照片'
                                : '未找到相关照片',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (photoProvider.searchQuery.isNotEmpty) ...[
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
                    );
                  }

                  return PhotoGrid(photos: photoProvider.photosByDecade);
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UploadScreen(),
            ),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }
} 