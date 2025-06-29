class Photo {
  final String id;
  final String url;
  final String? thumbnailUrl;
  final DateTime createdAt;
  final int? year; // 拍摄年代
  final List<String> tags; // 人物姓名标签
  final String? description;

  Photo({
    required this.id,
    required this.url,
    this.thumbnailUrl,
    required this.createdAt,
    this.year,
    required this.tags,
    this.description,
  });

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'],
      url: json['url'],
      thumbnailUrl: json['thumbnail_url'],
      createdAt: DateTime.parse(json['created_at']),
      year: json['year'],
      tags: List<String>.from(json['tags'] ?? []),
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'thumbnail_url': thumbnailUrl,
      'created_at': createdAt.toIso8601String(),
      'year': year,
      'tags': tags,
      'description': description,
    };
  }

  // 获取年代分组（如"1980年代"、"2020年代"）
  String get decadeGroup {
    if (year == null) return '未知年代';
    
    int decade = (year! ~/ 10) * 10;
    return '$decade年代';
  }

  // 复制并更新照片信息
  Photo copyWith({
    String? id,
    String? url,
    String? thumbnailUrl,
    DateTime? createdAt,
    int? year,
    List<String>? tags,
    String? description,
  }) {
    return Photo(
      id: id ?? this.id,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      createdAt: createdAt ?? this.createdAt,
      year: year ?? this.year,
      tags: tags ?? this.tags,
      description: description ?? this.description,
    );
  }
} 