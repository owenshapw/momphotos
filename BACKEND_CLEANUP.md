# 后端文件整理说明

## 整理内容

### 删除的文件
- `app_test.py` - 空文件，已删除
- `app_test2.py` - 空文件，已删除  
- `app_test3.py` - 测试文件，功能已合并到主应用

### 保留的文件
- `app.py` - **主Flask应用**，包含所有功能
- `app_simple.py` - 备份文件，包含Supabase集成功能
- `test_app.py` - 新增的测试脚本，用于验证应用功能

## 主应用功能 (app.py)

### API端点
1. **GET /health** - 健康检查
   - 返回服务状态和Supabase配置状态

2. **GET /test-db** - 数据库连接测试
   - 测试Supabase连接
   - 返回用户和照片数量

3. **GET /photos** - 获取照片列表
   - 如果数据库可用，从Supabase获取
   - 如果数据库不可用，返回测试数据

4. **POST /photos** - 上传照片
   - 预留的照片上传接口

### 特性
- ✅ CORS支持
- ✅ 环境变量配置
- ✅ Supabase数据库集成
- ✅ 错误处理
- ✅ 健康检查

## 使用方法

### 1. 安装依赖
```bash
pip install -r requirements.txt
```

### 2. 配置环境变量
复制 `env.example` 到 `.env` 并填写Supabase配置：
```bash
cp env.example .env
```

### 3. 运行应用
```bash
python app.py
```

### 4. 测试应用
```bash
python test_app.py
```

## 项目结构
```
├── app.py              # 主Flask应用
├── app_simple.py       # 备份文件
├── test_app.py         # 测试脚本
├── requirements.txt    # Python依赖
├── env.example         # 环境变量示例
└── BACKEND_CLEANUP.md  # 本文件
```

## 注意事项
- 主应用现在包含所有必要的功能
- 保留了 `app_simple.py` 作为备份
- 新增了 `test_app.py` 用于功能验证
- 所有空文件和重复的测试文件已清理 