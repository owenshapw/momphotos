import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:exif/exif.dart';
import '../services/photo_provider.dart';

class BatchUploadScreen extends StatefulWidget {
  const BatchUploadScreen({super.key});

  @override
  State<BatchUploadScreen> createState() => _BatchUploadScreenState();
}

class _BatchUploadScreenState extends State<BatchUploadScreen> {
  final List<XFile> _selectedImages = [];
  final List<String> _batchTags = [];
  final TextEditingController _batchDescriptionController = TextEditingController();
  bool _isUploading = false;
  int _uploadProgress = 0;
  int _totalImages = 0;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _batchDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        // 完全移除所有压缩设置，保持原始质量
        // imageQuality: 100, // 移除质量设置
        // maxWidth: 3840, // 移除尺寸限制
        // maxHeight: 3840, // 移除尺寸限制
      );

      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择照片失败: $e')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _addTag(String tag) {
    if (tag.trim().isNotEmpty && !_batchTags.contains(tag.trim())) {
      setState(() {
        _batchTags.add(tag.trim());
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _batchTags.remove(tag);
    });
  }

  void _showAddTagDialog() {
    final tagController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加标签'),
        content: TextField(
          controller: tagController,
          decoration: const InputDecoration(
            hintText: '输入标签',
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

  // 从EXIF数据中提取拍摄年份
  Future<int?> _extractYearFromExif(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final exifData = await readExifFromBytes(bytes);
      
      if (exifData.isNotEmpty) {
        // 尝试获取拍摄时间
        final dateTimeOriginal = exifData['EXIF DateTimeOriginal']?.printable;
        final dateTime = exifData['Image DateTime']?.printable;
        
        String? dateString = dateTimeOriginal ?? dateTime;
        if (dateString != null) {
          // 解析日期格式 (通常是 YYYY:MM:DD HH:MM:SS)
          final parts = dateString.split(' ')[0].split(':');
          if (parts.isNotEmpty) {
            final year = int.tryParse(parts[0]);
            if (year != null && year > 1900 && year <= DateTime.now().year) {
              return year;
            }
          }
        }
            }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EXIF解析失败: $e');
      }
    }
    return null;
  }

  Future<void> _uploadBatch() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择照片')),
      );
      return;
    }

    if (_batchTags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少添加一个标签')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _totalImages = _selectedImages.length;
    });

    try {
      for (int i = 0; i < _selectedImages.length; i++) {
        final imageFile = _selectedImages[i];
        
        // 显示当前上传进度
        if (mounted) {
          setState(() {
            _uploadProgress = i + 1;
          });
        }

        // 提取拍摄年份
        final year = await _extractYearFromExif(imageFile);
        
        // 上传照片
        if (mounted) {
          await context.read<PhotoProvider>().uploadPhoto(
            imagePath: imageFile.path,
            tags: _batchTags,
            year: year,
            description: _batchDescriptionController.text.trim().isEmpty
                ? null
                : _batchDescriptionController.text.trim(),
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功上传 $_totalImages 张照片'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 清空选择
        setState(() {
          _selectedImages.clear();
          _batchTags.clear();
          _batchDescriptionController.clear();
        });
        
        // 返回上一页
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('上传失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('批量上传'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_isUploading)
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
          else if (_selectedImages.isNotEmpty)
            TextButton(
              onPressed: _uploadBatch,
              child: const Text(
                '上传',
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
            // 选择照片按钮
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '选择照片',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isUploading ? null : _pickImages,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('选择多张照片'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    if (_selectedImages.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        '已选择 ${_selectedImages.length} 张照片',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 照片预览
            if (_selectedImages.isNotEmpty) ...[
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
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: kIsWeb
                                      ? Image.network(
                                          _selectedImages[index].path,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                          errorBuilder: (context, error, stackTrace) {
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
                                        )
                                      : Image.file(
                                          File(_selectedImages[index].path),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // 批量标签设置
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '批量标签设置',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '这些标签将应用到所有选中的照片',
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
                          onPressed: _showAddTagDialog,
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
                    if (_batchTags.isNotEmpty) ...[
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
                        children: _batchTags.map((tag) {
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
            
            // 批量描述设置
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '批量描述设置',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '这个描述将应用到所有选中的照片（可选）',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _batchDescriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: '添加照片描述（可选）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 功能说明
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '功能说明',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem(
                      Icons.auto_awesome,
                      '自动年代识别',
                      '系统会自动从照片的EXIF数据中提取拍摄时间',
                    ),
                    _buildFeatureItem(
                      Icons.label,
                      '批量标签',
                      '为所有照片统一设置搜索标签',
                    ),
                    _buildFeatureItem(
                      Icons.description,
                      '批量描述',
                      '为所有照片统一设置描述信息',
                    ),
                    _buildFeatureItem(
                      Icons.upload,
                      '批量上传',
                      '一次性上传多张照片，提高效率',
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 上传按钮
            if (_selectedImages.isNotEmpty && !_isUploading) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _uploadBatch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('开始批量上传'),
                ),
              ),
            ],
            
            // 上传进度
            if (_isUploading) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '上传进度',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: _totalImages > 0 ? _uploadProgress / _totalImages : 0,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '正在上传 $_uploadProgress / $_totalImages',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}