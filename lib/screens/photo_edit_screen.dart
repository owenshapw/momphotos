import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/photo.dart';
import '../services/photo_provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class PhotoEditScreen extends StatefulWidget {
  final Photo photo;

  const PhotoEditScreen({
    super.key,
    required this.photo,
  });

  @override
  State<PhotoEditScreen> createState() => _PhotoEditScreenState();
}

class _PhotoEditScreenState extends State<PhotoEditScreen> {
  final List<String> _tags = [];
  final TextEditingController _descriptionController = TextEditingController();
  int? _selectedYear;
  bool _isSaving = false;

  // 新增：照片列表、当前索引、滚动控制器
  late List<Photo> allPhotos;
  late int _currentIndex;
  final ItemScrollController itemScrollController = ItemScrollController();

  @override
  void initState() {
    super.initState();
    // 初始化表单数据
    _tags.addAll(widget.photo.tags);
    _selectedYear = widget.photo.year;
    _descriptionController.text = widget.photo.description ?? '';
    // 初始化照片列表和当前索引
    allPhotos = [widget.photo]; // 如有多张照片可改为 widget.photos
    _currentIndex = 0;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    if (tag.trim().isNotEmpty && !_tags.contains(tag.trim())) {
      setState(() {
        _tags.add(tag.trim());
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _saveChanges() async {
    if (_tags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少添加一个搜索标签')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await context.read<PhotoProvider>().updatePhotoDetails(
        photoId: widget.photo.id,
        tags: _tags,
        year: _selectedYear,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );
      if (!mounted) return;
      await context.read<PhotoProvider>().loadPhotos(forceRefresh: true);
      if (!mounted) return;

      final photos = Provider.of<PhotoProvider>(context, listen: false).photos;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存成功！')),
      );
      
      // 返回到前一个页面，并传递更新后的照片ID以便高亮
      context.pop({'updatedPhotoId': widget.photo.id});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (allPhotos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
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
      appBar: AppBar(
        title: const Text('编辑照片'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveChanges,
              child: const Text(
                '保存',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 照片预览
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '照片预览',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          widget.photo.url,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                  size: 48,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 搜索标签编辑
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '搜索标签',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '添加标签用于搜索功能',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 标签输入框
                    Row(
                      children: [
                        Expanded(
                          child: Consumer<PhotoProvider>(
                            builder: (context, photoProvider, child) {
                              return DropdownButtonFormField<String>(
                                value: null,
                                hint: const Text('选择已有标签'),
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                                items: photoProvider.allTags.map((tag) {
                                  return DropdownMenuItem<String>(
                                    value: tag,
                                    child: Text(tag),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    _addTag(value);
                                  }
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            _showAddTagDialog();
                          },
                          icon: const Icon(Icons.add),
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 已添加的标签
                    if (_tags.isNotEmpty) ...[
                      const Text(
                        '已添加的标签:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _tags.map((tag) {
                          return Chip(
                            label: Text(tag),
                            onDeleted: () => _removeTag(tag),
                            deleteIcon: const Icon(Icons.close, size: 18),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 年代选择
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '拍摄年代',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        final currentYear = DateTime.now().year;
                        final years = List.generate(100, (index) => currentYear - index);
                        return DropdownButtonFormField<int>(
                          value: years.contains(_selectedYear) ? _selectedYear : null,
                          hint: const Text('选择拍摄年代（可选）'),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          items: years.map((year) => DropdownMenuItem<int>(
                            value: year,
                            child: Text('$year年'),
                          )).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedYear = value;
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 描述编辑
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '照片描述',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: '添加照片描述（可选）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 保存按钮
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: _isSaving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('保存中...'),
                        ],
                      )
                    : const Text('保存更改'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTagDialog() {
    final tagController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加新标签'),
        content: TextField(
          controller: tagController,
          decoration: const InputDecoration(
            hintText: '输入新标签',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              _addTag(value.trim());
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (tagController.text.trim().isNotEmpty) {
                _addTag(tagController.text.trim());
                Navigator.of(context).pop();
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      final scrollToId = args != null ? args['scrollToId'] : null;
      if (scrollToId != null) {
        final photos = context.read<PhotoProvider>().photos;
        final index = photos.indexWhere((p) => p.id == scrollToId);
        if (index != -1 && itemScrollController.isAttached) {
          itemScrollController.scrollTo(index: index ~/ 2, duration: Duration(milliseconds: 300));
        }
      }
    });
  }
} 