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
    """获取所有照片"""
    if not supabase:
        return jsonify({'error': 'Supabase未配置'}), 500
    
    try:
        # 从Supabase获取照片数据
        response = supabase.table('photos').select('*').order('created_at', desc=True).execute()
        photos = response.data
        
        return jsonify(photos)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/search', methods=['GET'])
def search_photos():
    """按多种条件搜索照片"""
    if not supabase:
        return jsonify({'error': 'Supabase未配置'}), 500
    
    query = request.args.get('name', '').strip()
    if not query:
        return jsonify([])
    
    try:
        # 获取所有照片，然后在Python中进行搜索
        response = supabase.table('photos').select('*').order('created_at', desc=True).execute()
        all_photos = response.data
        
        # 在Python中进行多字段搜索
        query_lower = query.lower()
        filtered_photos = []
        
        for photo in all_photos:
            # 搜索人物标签
            tags = photo.get('tags', [])
            tag_match = any(tag.lower().find(query_lower) != -1 for tag in tags)
            
            # 搜索年代
            year = photo.get('year')
            year_match = year is not None and str(year).find(query) != -1
            
            # 搜索简介
            description = photo.get('description', '')
            description_match = description and description.lower().find(query_lower) != -1
            
            # 如果任一字段匹配，则包含此照片
            if tag_match or year_match or description_match:
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
    """更新照片标签"""
    if not supabase:
        return jsonify({'error': 'Supabase未配置'}), 500
    
    try:
        data = request.get_json()
        photo_id = data.get('photo_id')
        tags = data.get('tags', [])
        year = data.get('year')
        
        if not photo_id:
            return jsonify({'error': '缺少照片ID'}), 400
        
        # 更新照片标签
        update_data = {'tags': tags}
        if year:
            update_data['year'] = int(year)
        
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
    return jsonify({
        'status': 'ok', 
        'timestamp': datetime.now().isoformat(),
        'supabase_configured': supabase is not None
    })

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=8080) 