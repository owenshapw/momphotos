from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import uuid
from datetime import datetime
import json
from werkzeug.utils import secure_filename
from typing import Optional

app = Flask(__name__)
CORS(app)

# Supabase配置
SUPABASE_URL = os.environ.get('SUPABASE_URL', 'your-supabase-url')
SUPABASE_KEY = os.environ.get('SUPABASE_KEY', 'your-supabase-key')

# 只有在配置了Supabase时才初始化客户端
supabase = None
if SUPABASE_URL != 'your-supabase-url' and SUPABASE_KEY != 'your-supabase-key':
    try:
        from supabase import create_client, Client
        supabase: Optional[Client] = create_client(SUPABASE_URL, SUPABASE_KEY)
    except Exception as e:
        print(f"Supabase初始化失败: {e}")

# 文件上传配置
UPLOAD_FOLDER = 'uploads'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'webp'}

if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@app.route('/photos', methods=['GET'])
def get_photos():
    """获取所有照片，支持分页和缓存"""
    if not supabase:
        return jsonify({'error': 'Supabase未配置'}), 500
    
    try:
        # 获取分页参数
        limit = request.args.get('limit')
        offset = int(request.args.get('offset', 0))
        
        # 优化查询：只选择需要的字段，按年份和创建时间排序
        query = supabase.table('photos').select('id,url,thumbnail_url,created_at,year,tags,description')
        
        # 按年份降序，然后按创建时间降序
        query = query.order('year', desc=True).order('created_at', desc=True)
        
        # 如果没有指定limit，返回所有照片
        if limit is None:
            response = query.execute()
        else:
            limit = int(limit)
            start = offset
            end = offset + limit - 1
            response = query.range(start, end).execute()
        
        photos = response.data
        return jsonify(photos)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/search', methods=['GET'])
def search_photos():
    """按多种条件搜索照片（优化版本）"""
    if not supabase:
        return jsonify({'error': 'Supabase未配置'}), 500
    
    query = request.args.get('name', '').strip()
    if not query:
        return jsonify([])
    
    try:
        # 尝试数字搜索（年份）
        if query.isdigit():
            year = int(query)
            if 1900 <= year <= 2030:
                response = supabase.table('photos').select('*').eq('year', year).order('created_at', desc=True).execute()
                return jsonify(response.data)
        
        # 尝试年代搜索（如"2020年代"）
        if query.endswith('年代') and query[:-2].isdigit():
            decade = int(query[:-2])
            start_year = decade
            end_year = decade + 9
            response = supabase.table('photos').select('*').gte('year', start_year).lte('year', end_year).order('created_at', desc=True).execute()
            return jsonify(response.data)
        
        # 对于其他搜索，使用文本搜索
        # 注意：这里简化处理，实际可以使用PostgreSQL的全文搜索功能
        response = supabase.table('photos').select('*').order('created_at', desc=True).execute()
        all_photos = response.data
        
        # 在Python中进行文本搜索（作为后备方案）
        query_lower = query.lower()
        filtered_photos = []
        
        for photo in all_photos:
            # 搜索人物标签
            tags = photo.get('tags', [])
            tag_match = any(tag.lower().find(query_lower) != -1 for tag in tags)
            
            # 搜索简介
            description = photo.get('description', '')
            description_match = description and description.lower().find(query_lower) != -1
            
            # 如果任一字段匹配，则包含此照片
            if tag_match or description_match:
                filtered_photos.append(photo)
        
        return jsonify(filtered_photos)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/upload', methods=['POST'])
def upload_photo():
    """上传照片"""
    if not supabase:
        return jsonify({'error': 'Supabase未配置'}), 500
    
    try:
        if 'image' not in request.files:
            return jsonify({'error': '没有文件'}), 400
        
        file = request.files['image']
        if file.filename == '':
            return jsonify({'error': '没有选择文件'}), 400
        
        if file and allowed_file(file.filename):
            # 生成唯一文件名
            if file.filename is None:
                return jsonify({'error': '文件名不能为空'}), 400
            filename = secure_filename(file.filename)
            file_extension = filename.rsplit('.', 1)[1].lower()
            unique_filename = f"{uuid.uuid4()}.{file_extension}"
            
            try:
                # 直接读取文件内容到内存，避免文件系统权限问题
                file_content = file.read()
                print(f"文件大小: {len(file_content)} bytes")
                
                # 上传到Supabase Storage
                bucket_name = 'photos'
                storage_path = f"photos/{unique_filename}"
                
                supabase.storage.from_(bucket_name).upload(storage_path, file_content)
                print(f"文件已上传到 Supabase Storage: {storage_path}")
                
                # 获取公开URL
                public_url = supabase.storage.from_(bucket_name).get_public_url(storage_path)
                print(f"公开URL: {public_url}")
                
            except Exception as storage_error:
                print(f"Storage 错误: {storage_error}")
                return jsonify({'error': f'Storage error: {storage_error}'}), 500
            
            # 解析请求数据
            tags = json.loads(request.form.get('tags', '[]'))
            year = request.form.get('year')
            description = request.form.get('description', '')
            
            # 创建照片记录
            photo_data = {
                'id': str(uuid.uuid4()),
                'url': public_url,
                'thumbnail_url': public_url,  # 可以后续生成缩略图
                'tags': tags,
                'year': int(year) if year else None,
                'description': description if description else None,
                'created_at': datetime.now().isoformat()
            }
            
            try:
                # 保存到数据库
                supabase.table('photos').insert(photo_data).execute()
                print(f"照片记录已保存到数据库: {photo_data['id']}")
            except Exception as db_error:
                print(f"数据库错误: {db_error}")
                return jsonify({'error': f'Database error: {db_error}'}), 500
            
            return jsonify(photo_data)
        
        return jsonify({'error': '不支持的文件类型'}), 400
        
    except Exception as e:
        print(f"上传错误: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/tag', methods=['POST'])
def update_photo_tags():
    """更新照片标签和描述"""
    if not supabase:
        return jsonify({'error': 'Supabase未配置'}), 500
    
    try:
        data = request.get_json()
        photo_id = data.get('photo_id')
        tags = data.get('tags', [])
        year = data.get('year')
        description = data.get('description')
        
        if not photo_id:
            return jsonify({'error': '缺少照片ID'}), 400
        
        # 更新照片标签和描述
        update_data = {'tags': tags}
        if year:
            update_data['year'] = int(year)
        if description is not None:  # 允许空字符串
            update_data['description'] = description
        
        response = supabase.table('photos').update(update_data).eq('id', photo_id).execute()
        
        if response.data:
            return jsonify(response.data[0])
        else:
            return jsonify({'error': '照片不存在'}), 404
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/health', methods=['GET'])
def health_check():
    """健康检查"""
    try:
        # 简单的数据库连接测试
        if supabase:
            # 执行一个轻量级查询来测试连接
            response = supabase.table('photos').select('id').limit(1).execute()
            return jsonify({
                'status': 'ok', 
                'timestamp': datetime.now().isoformat(),
                'database': 'connected',
                'photo_count': len(response.data) if response.data else 0
            })
        else:
            return jsonify({
                'status': 'ok', 
                'timestamp': datetime.now().isoformat(),
                'database': 'not_configured'
            })
    except Exception as e:
        return jsonify({
            'status': 'error', 
            'timestamp': datetime.now().isoformat(),
            'error': str(e)
        }), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=8080) 