from flask import Flask, request, jsonify
from flask_cors import CORS
import os
from datetime import datetime
from typing import Optional

app = Flask(__name__)
CORS(app)

# Supabase配置
SUPABASE_URL = os.environ.get('SUPABASE_URL', 'your-supabase-url')
SUPABASE_KEY = os.environ.get('SUPABASE_KEY', 'your-supabase-key')

# 初始化Supabase客户端
supabase = None
if SUPABASE_URL != 'your-supabase-url' and SUPABASE_KEY != 'your-supabase-key':
    try:
        from supabase import create_client, Client
        supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
        print("Supabase客户端初始化成功")
    except Exception as e:
        print(f"Supabase初始化失败: {e}")

@app.route('/test-db', methods=['GET'])
def test_database():
    """测试数据库连接"""
    if not supabase:
        return jsonify({'error': 'Supabase未配置'}), 500
    
    try:
        # 测试用户表
        users_response = supabase.table('users').select('count').execute()
        users_count = len(users_response.data) if users_response.data else 0
        
        # 测试照片表
        photos_response = supabase.table('photos').select('count').execute()
        photos_count = len(photos_response.data) if photos_response.data else 0
        
        return jsonify({
            'status': 'success',
            'message': '数据库连接正常',
            'users_count': users_count,
            'photos_count': photos_count,
            'timestamp': datetime.now().isoformat()
        })
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': f'数据库连接失败: {str(e)}',
            'timestamp': datetime.now().isoformat()
        }), 500

@app.route('/health', methods=['GET'])
def health_check():
    """健康检查"""
    return jsonify({
        'status': 'ok',
        'message': '服务运行正常',
        'timestamp': datetime.now().isoformat(),
        'supabase_configured': supabase is not None
    })

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=8080)