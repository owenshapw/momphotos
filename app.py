from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import jwt
import secrets
from datetime import datetime, timedelta
from typing import Optional
from dotenv import load_dotenv

# 加载环境变量
load_dotenv()

# 尝试从 Render Secret Files 加载环境变量
try:
    with open('/etc/secrets/env.txt', 'r') as f:
        for line in f:
            if '=' in line and not line.startswith('#'):
                key, value = line.strip().split('=', 1)
                os.environ[key] = value
    print("从 Secret Files 加载环境变量成功")
except FileNotFoundError:
    print("Secret Files 不存在，使用本地环境变量")
except Exception as e:
    print(f"加载 Secret Files 失败: {e}")

app = Flask(__name__)
CORS(app)

# JWT配置
app.config['SECRET_KEY'] = os.environ.get('JWT_SECRET_KEY', 'your-secret-key-change-in-production')
JWT_SECRET_KEY = app.config['SECRET_KEY']

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

def generate_token(user_id: str, phone: str) -> str:
    """生成JWT token"""
    payload = {
        'user_id': user_id,
        'phone': phone,
        'exp': datetime.utcnow() + timedelta(days=30),  # 30天过期
        'iat': datetime.utcnow()
    }
    return jwt.encode(payload, JWT_SECRET_KEY, algorithm='HS256')

def verify_token(token: str) -> Optional[dict]:
    """验证JWT token"""
    try:
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=['HS256'])
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None

@app.route('/health', methods=['GET'])
def health_check():
    """健康检查"""
    return jsonify({
        'status': 'ok',
        'message': '服务运行正常',
        'timestamp': datetime.now().isoformat(),
        'supabase_configured': supabase is not None
    })

@app.route('/test-db', methods=['GET'])
def test_database():
    """测试数据库连接"""
    if not supabase:
        return jsonify({'error': 'Supabase未配置'}), 500
    
    try:
        # 测试用户表
        users_response = supabase.table('users').select('*').execute()
        users_count = len(users_response.data) if users_response.data else 0
        
        # 测试照片表
        photos_response = supabase.table('photos').select('*').execute()
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

@app.route('/migrate-db', methods=['POST'])
def migrate_database():
    """数据库迁移"""
    if not supabase:
        return jsonify({'error': 'Supabase未配置'}), 500
    
    try:
        # 检查用户表结构
        users_response = supabase.table('users').select('*').limit(1).execute()
        
        # 尝试更新默认用户的密码字段
        try:
            update_result = supabase.table('users').update({
                'password': '194201'
            }).eq('id', '00000000-0000-0000-0000-000000000000').execute()
            
            return jsonify({
                'status': 'success',
                'message': '数据库迁移完成（密码字段已存在）',
                'result': str(update_result),
                'timestamp': datetime.now().isoformat()
            })
        except Exception as update_error:
            # 如果更新失败，说明没有password字段
            return jsonify({
                'status': 'error',
                'message': f'需要手动添加password字段到users表: {str(update_error)}',
                'hint': '请在Supabase控制台中手动添加password字段',
                'timestamp': datetime.now().isoformat()
            }), 500
            
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': f'数据库迁移失败: {str(e)}',
            'timestamp': datetime.now().isoformat()
        }), 500

@app.route('/photos', methods=['GET'])
def get_photos():
    """获取照片列表（只返回当前用户的照片）"""
    if not supabase:
        # 如果没有数据库连接，返回测试数据
        return jsonify([
            {
                'id': 'test1',
                'url': 'https://example.com/test1.jpg',
                'tags': ['测试'],
                'description': '测试照片',
                'created_at': datetime.now().isoformat()
            }
        ])
    # 认证token
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        return jsonify({'error': '缺少认证token'}), 401
    token = auth_header.split(' ')[1]
    payload = verify_token(token)
    if not payload:
        return jsonify({'error': 'token无效或已过期'}), 401
    user_id = payload['user_id']
    try:
        # 只返回当前用户的照片
        response = supabase.table('photos').select('*').eq('user_id', user_id).execute()
        return jsonify(response.data)
    except Exception as e:
        return jsonify({
            'error': f'获取照片失败: {str(e)}'
        }), 500

@app.route('/auth/register', methods=['POST'])
def register_user():
    """用户注册"""
    if not supabase:
        return jsonify({'error': 'Supabase未配置'}), 500
    
    try:
        data = request.get_json()
        phone = data.get('phone')
        password = data.get('password')
        username = data.get('username', phone)  # 默认使用手机号作为用户名
        
        if not phone or not password:
            return jsonify({'error': '手机号和密码不能为空'}), 400
        
        # 检查手机号是否已存在
        existing_user = supabase.table('users').select('*').eq('phone', phone).execute()
        if existing_user.data:
            return jsonify({'error': '该手机号已注册'}), 409
        
        # 创建新用户
        new_user = supabase.table('users').insert({
            'phone': phone,
            'username': username,
            'password': password,  # 注意：生产环境应该加密密码
            'created_at': datetime.now().isoformat()
        }).execute()
        
        if new_user.data:
            user = new_user.data[0]
            # 生成token
            token = generate_token(user['id'], user['phone'])
            
            return jsonify({
                'status': 'success',
                'message': '注册成功',
                'user': {
                    'id': user['id'],
                    'phone': user['phone'],
                    'created_at': user.get('created_at', datetime.now().isoformat())
                },
                'token': token
            })
        else:
            return jsonify({'error': '注册失败'}), 500
            
    except Exception as e:
        return jsonify({'error': f'注册失败: {str(e)}'}), 500

@app.route('/auth/login', methods=['POST'])
def login_user():
    """用户登录"""
    if not supabase:
        return jsonify({'error': 'Supabase未配置'}), 500
    
    try:
        data = request.get_json()
        phone = data.get('phone')
        password = data.get('password')
        
        if not phone or not password:
            return jsonify({'error': '手机号和密码不能为空'}), 400
        
        # 查找用户
        user_response = supabase.table('users').select('*').eq('phone', phone).eq('password', password).execute()
        
        if user_response.data:
            user = user_response.data[0]
            # 生成token
            token = generate_token(user['id'], user['phone'])
            # 更新最后登录时间
            try:
                supabase.table('users').update({
                    'last_login_at': datetime.now().isoformat()
                }).eq('id', user['id']).execute()
            except:
                pass  # 如果last_login_at字段不存在，忽略错误
            
            return jsonify({
                'status': 'success',
                'message': '登录成功',
                'user': {
                    'id': user['id'],
                    'phone': user['phone'],
                    'created_at': user.get('created_at', datetime.now().isoformat()),
                    'last_login_at': datetime.now().isoformat()
                },
                'token': token
            })
        else:
            return jsonify({'error': '手机号或密码错误'}), 401
            
    except Exception as e:
        return jsonify({'error': f'登录失败: {str(e)}'}), 500

@app.route('/auth/validate', methods=['GET'])
def validate_token():
    """验证token"""
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        return jsonify({'error': '缺少认证token'}), 401
    
    token = auth_header.split(' ')[1]
    payload = verify_token(token)
    
    if not payload:
        return jsonify({'error': 'token无效或已过期'}), 401
    
    return jsonify({
        'status': 'success',
        'message': 'token有效',
        'user_id': payload['user_id'],
        'phone': payload['phone']
    })

@app.route('/photos', methods=['POST'])
def upload_photo():
    """上传照片（自动写入user_id）"""
    if not supabase:
        return jsonify({'error': 'Supabase未配置'}), 500
    # 认证token
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        return jsonify({'error': '缺少认证token'}), 401
    token = auth_header.split(' ')[1]
    payload = verify_token(token)
    if not payload:
        return jsonify({'error': 'token无效或已过期'}), 401
    user_id = payload['user_id']
    try:
        data = request.get_json()
        # 组装照片数据
        photo_data = {
            'user_id': user_id,
            'tags': data.get('tags', []),
            'description': data.get('description'),
            'year': data.get('year'),
            'url': data.get('url'),
            'thumbnail_url': data.get('thumbnail_url'),
            'created_at': datetime.now().isoformat()
        }
        # 插入照片
        result = supabase.table('photos').insert(photo_data).execute()
        if result.data:
            return jsonify(result.data[0])
        else:
            return jsonify({'error': '照片保存失败'}), 500
    except Exception as e:
        return jsonify({
            'error': f'上传照片失败: {str(e)}'
        }), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=8080) 