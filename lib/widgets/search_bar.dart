import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/photo_provider.dart';

class CustomSearchBar extends StatefulWidget {
  const CustomSearchBar({super.key});

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showSuggestions = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<String> _getSearchSuggestions(PhotoProvider photoProvider) {
    final suggestions = <String>{};
    
    // 添加搜索历史
    suggestions.addAll(photoProvider.searchHistory);
    
    // 添加标签建议
    suggestions.addAll(photoProvider.allTags);
    
    // 添加年代建议
    for (final photo in photoProvider.photos) {
      if (photo.year != null) {
        suggestions.add(photo.year.toString());
        suggestions.add('${photo.year}年');
      }
    }
    
    // 添加年代分组建议
    for (final photo in photoProvider.photos) {
      suggestions.add(photo.decadeGroup);
    }
    
    final result = suggestions.toList()..sort();
    
    // 调试信息
    if (kDebugMode) {
      debugPrint('搜索建议: $result');
    }
    
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PhotoProvider>(
      builder: (context, photoProvider, child) {
        final suggestions = _getSearchSuggestions(photoProvider);
        
        return Column(
          children: [
            Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            decoration: InputDecoration(
                  hintText: '搜索人物名、年代、简介...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _controller.clear();
                        photoProvider.clearSearch();
                        _focusNode.unfocus();
                            setState(() {
                              _showSuggestions = false;
                            });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) {
                  setState(() {
                    _showSuggestions = value.isNotEmpty && _focusNode.hasFocus;
                  });
                  
              if (value.isEmpty) {
                photoProvider.clearSearch();
              } else {
                photoProvider.searchPhotos(value);
              }
            },
                onTap: () {
                  setState(() {
                    _showSuggestions = _controller.text.isNotEmpty;
                  });
                },
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                photoProvider.searchPhotos(value);
              }
              _focusNode.unfocus();
                  setState(() {
                    _showSuggestions = false;
                  });
            },
          ),
            ),
            
            // 搜索建议
            if (_showSuggestions && suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = suggestions[index];
                    final isHistory = photoProvider.searchHistory.contains(suggestion);
                    final isYear = suggestion.contains('年') || (int.tryParse(suggestion) != null);
                    final isDecade = suggestion.contains('年代');
                    
                    IconData icon;
                    Color iconColor;
                    
                    if (isHistory) {
                      icon = Icons.history;
                      iconColor = Colors.blue;
                    } else if (isYear) {
                      icon = Icons.calendar_today;
                      iconColor = Colors.orange;
                    } else if (isDecade) {
                      icon = Icons.date_range;
                      iconColor = Colors.green;
                    } else {
                      icon = Icons.person;
                      iconColor = Colors.purple;
                    }
                    
                    return ListTile(
                      dense: true,
                      title: Text(
                        suggestion,
                        style: const TextStyle(fontSize: 14),
                      ),
                      leading: Icon(icon, size: 16, color: iconColor),
                      onTap: () {
                        _controller.text = suggestion;
                        photoProvider.searchPhotos(suggestion);
                        _focusNode.unfocus();
                        setState(() {
                          _showSuggestions = false;
                        });
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
} 