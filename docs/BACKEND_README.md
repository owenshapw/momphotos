# ShaPhoto 后端API

这是ShaPhoto项目的Flask后端API，提供照片管理功能。

## 功能特性

- 照片上传到Supabase Storage
- 照片元数据管理（标签、年代、描述）
- 按人物姓名搜索照片
- RESTful API设计

## API接口

### 1. 获取所有照片
```
GET /photos
```
返回所有照片列表，按创建时间倒序排列。

### 2. 搜索照片
```
GET /search?name=张三
```
按人物姓名搜索相关照片。

### 3. 上传照片
```
POST /upload
Content-Type: multipart/form-data

参数:
- image: 图片文件
- tags: JSON格式的标签数组
- year: 拍摄年代（可选）
- description: 照片描述（可选）
```

### 4. 更新照片标签
```
POST /tag
Content-Type: application/json

{
  "photo_id": "照片ID",
  "tags": ["标签1", "标签2"],
  "year": 2020
}
```

### 5. 健康检查
```
GET /health
```

## 环境配置

### 1. 安装依赖
```bash
pip install -r requirements.txt
```

### 2. 环境变量
复制 `env.example` 为 `.env` 并配置：
```bash
SUPABASE_URL=your-supabase-project-url
SUPABASE_KEY=your-supabase-anon-key
FLASK_ENV=development
FLASK_DEBUG=True
```

### 3. Supabase设置
1. 创建Supabase项目
2. 在SQL编辑器中执行 `database_schema.sql`
3. 创建Storage bucket名为 `photos`
4. 设置bucket为公开访问

## 本地运行

```bash
python app.py
```

服务将在 `http://localhost:5000` 启动。

## 部署到Render

1. 将代码推送到GitHub
2. 在Render中连接GitHub仓库
3. 配置环境变量：
   - `SUPABASE_URL`
   - `SUPABASE_KEY`
4. 部署服务

## 数据库结构

### photos表
- `id`: UUID主键
- `url`: 图片URL
- `thumbnail_url`: 缩略图URL
- `tags`: 标签数组
- `year`: 拍摄年代
- `description`: 描述
- `created_at`: 创建时间
- `updated_at`: 更新时间

## 错误处理

API返回标准HTTP状态码：
- 200: 成功
- 400: 请求错误
- 404: 资源不存在
- 500: 服务器错误

错误响应格式：
```json
{
  "error": "错误描述"
}
```

## 安全考虑

- 文件类型验证
- 文件名安全处理
- CORS配置
- 环境变量管理

## 开发说明

### 添加新功能
1. 在 `app.py` 中添加新的路由
2. 更新数据库结构（如需要）
3. 添加相应的错误处理
4. 更新文档

### 测试
```bash
# 测试健康检查
curl http://localhost:5000/health

# 测试获取照片
curl http://localhost:5000/photos

# 测试搜索
curl "http://localhost:5000/search?name=张三"
``` 