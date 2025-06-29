# ShaPhoto - 照片管理应用

ShaPhoto 是一个基于 Flutter 和 Flask 的照片管理应用，支持云端存储、人物标签管理和智能搜索功能。

## 功能特性

### 📱 前端功能（Flutter）

**主要功能：**
1. **浏览云端照片** - 支持时间线和瀑布流展示，按年代分组显示
2. **人物标签管理** - 为每张照片添加人物姓名标签
3. **智能搜索** - 通过姓名关键词搜索相关照片

**次要功能：**
4. **照片上传** - 从手机相册选择或拍照上传
5. **照片信息编辑** - 上传时填写拍摄年代、人物标签等信息

### ☁️ 后端功能（Flask）

**API 接口：**
- `GET /photos` - 获取所有照片（包含时间戳、标签、图片URL）
- `GET /search?name=张三` - 按姓名关键词搜索照片
- `POST /upload` - 上传照片及标签信息
- `POST /tag` - 为已有照片添加或更新标签

## 技术栈

### 前端
- **Flutter** - 跨平台移动应用框架
- **Provider** - 状态管理
- **HTTP** - API 通信
- **Image Picker** - 照片选择和拍摄
- **Cached Network Image** - 图片缓存和加载
- **Photo View** - 图片查看和缩放
- **Flutter Staggered Grid View** - 瀑布流布局
- **Dropdown Search** - 搜索下拉框

### 后端
- **Flask** - Python Web 框架
- **Supabase** - 数据库和文件存储
- **Render** - 云部署平台

## 项目结构

```
shaphoto/
├── lib/                          # Flutter前端代码
│   ├── models/
│   │   └── photo.dart            # 照片数据模型
│   ├── services/
│   │   ├── api_service.dart      # API 服务
│   │   └── photo_provider.dart   # 状态管理
│   ├── screens/
│   │   ├── home_screen.dart      # 主屏幕
│   │   ├── upload_screen.dart    # 上传屏幕
│   │   └── photo_detail_screen.dart # 照片详情
│   ├── widgets/
│   │   ├── photo_grid.dart       # 照片网格组件
│   │   └── search_bar.dart       # 搜索栏组件
│   └── main.dart                 # 应用入口
├── assets/                       # 静态资源
│   ├── images/
│   └── fonts/
├── app.py                        # Flask后端API
├── requirements.txt              # Python依赖
├── database_schema.sql           # 数据库结构
├── render.yaml                   # Render部署配置
├── env.example                   # 环境变量示例
├── BACKEND_README.md             # 后端文档
└── pubspec.yaml                  # Flutter依赖配置
```

## 快速开始

### 1. 后端设置

#### 1.1 创建Supabase项目
1. 访问 [Supabase](https://supabase.com) 创建新项目
2. 在SQL编辑器中执行 `database_schema.sql` 创建表结构
3. 创建Storage bucket名为 `photos` 并设置为公开访问
4. 获取项目URL和API密钥

#### 1.2 配置环境变量
复制 `env.example` 为 `.env`：
```bash
SUPABASE_URL=your-supabase-project-url
SUPABASE_KEY=your-supabase-anon-key
FLASK_ENV=development
FLASK_DEBUG=True
```

#### 1.3 本地运行后端
```bash
pip install -r requirements.txt
python app.py
```

#### 1.4 部署到Render
1. 将代码推送到GitHub
2. 在Render中连接GitHub仓库
3. 配置环境变量：`SUPABASE_URL` 和 `SUPABASE_KEY`
4. 部署服务

### 2. 前端设置

#### 2.1 安装依赖
```bash
flutter pub get
```

#### 2.2 配置后端URL
在 `lib/services/api_service.dart` 中更新 `baseUrl`：
```dart
static const String baseUrl = 'https://your-flask-app.onrender.com';
```

#### 2.3 运行应用
```bash
flutter run
```

## 使用说明

### 浏览照片
- 应用启动后自动加载云端照片
- 照片按年代分组显示（如"1980年代"、"2020年代"）
- 支持瀑布流布局，点击照片查看详情

### 搜索功能
- 在搜索框输入人物姓名
- 实时搜索相关照片
- 支持已有标签的快速选择

### 上传照片
1. 点击右下角的"+"按钮
2. 选择"从相册选择"或"拍照"
3. 添加人物标签（支持选择已有标签或输入新标签）
4. 选择拍摄年代（可选）
5. 添加描述信息（可选）
6. 点击"上传照片"

### 照片详情
- 点击照片进入详情页面
- 支持图片缩放和查看
- 显示完整的人物标签、年代、描述等信息

## API文档

详细的API文档请参考 [BACKEND_README.md](BACKEND_README.md)

## 开发说明

### 添加新功能
1. 在 `lib/models/` 中添加数据模型
2. 在 `lib/services/` 中添加业务逻辑
3. 在 `lib/screens/` 或 `lib/widgets/` 中添加 UI 组件
4. 更新状态管理（如需要）

### 自定义样式
- 主题配置在 `lib/main.dart` 中
- 颜色方案使用 Material 3 设计系统
- 支持深色模式（待实现）

## 部署说明

### 前端部署
- 支持 Android、iOS、Web 平台
- 使用 `flutter build` 命令构建

### 后端部署
- 部署到 Render 平台
- 配置 Supabase 连接
- 设置环境变量

## 测试

### 后端API测试
```bash
# 健康检查
curl http://localhost:5000/health

# 获取照片
curl http://localhost:5000/photos

# 搜索照片
curl "http://localhost:5000/search?name=张三"
```

### 前端测试
```bash
flutter test
```

## 贡献指南

1. Fork 项目
2. 创建功能分支
3. 提交更改
4. 推送到分支
5. 创建 Pull Request

## 许可证

MIT License

## 联系方式

如有问题或建议，请提交 Issue 或联系开发团队。
