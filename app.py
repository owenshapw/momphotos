from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_mail import Mail, Message
import os
import jwt
from datetime import datetime, timedelta, timezone
from typing import Optional
from dotenv import load_dotenv
from werkzeug.security import generate_password_hash, check_password_hash
from supabase import create_client, Client

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
FRONTEND_URL = os.environ.get('FRONTEND_URL', 'http://localhost:3000')

# Flask-Mail 配置
app.config['MAIL_SERVER'] = os.environ.get('MAIL_SERVER', 'smtp.gmail.com')
app.config['MAIL_PORT'] = int(os.environ.get('MAIL_PORT', 587))
app.config['MAIL_USE_TLS'] = os.environ.get('MAIL_USE_TLS', 'True').lower() in ['true', '1', 't']
app.config['MAIL_USERNAME'] = os.environ.get('MAIL_USERNAME')
app.config['MAIL_PASSWORD'] = os.environ.get('MAIL_PASSWORD')
SENDER_EMAIL = os.environ.get('SENDER_EMAIL')

mail = Mail(app)

# Supabase配置
SUPABASE_URL = os.environ.get('SUPABASE_URL')
SUPABASE_KEY = os.environ.get('SUPABASE_KEY')

# 初始化Supabase客户端
supabase: Optional[Client] = None
if SUPABASE_URL and SUPABASE_KEY:
    try:
        supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
        print("Supabase客户端初始化成功")
    except Exception as e:
        print(f"Supabase初始化失败: {e}")

def generate_token(user_id: str, username: str, expires_delta: timedelta = timedelta(days=30)) -> str:
    """生成JWT token"""
    payload = {
        'user_id': user_id,
        'username': username,
        'exp': datetime.now(timezone.utc) + expires_delta,
        'iat': datetime.now(timezone.utc)
    }
    return jwt.encode(payload, JWT_SECRET_KEY, algorithm='HS256')

def verify_token(token: str) -> Optional[dict]:
    """验证JWT token"""
    try:
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=['HS256'])
        return payload
    except (jwt.ExpiredSignatureError, jwt.InvalidTokenError):
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

@app.route('/auth/register', methods=['POST'])
def register_user():
    """用户注册"""
    if not supabase:
        return jsonify({'error': '数据库服务未配置'}), 500
    
    data = request.get_json()
    username = data.get('username')
    email = data.get('email')
    password = data.get('password')
    
    if not all([username, email, password]):
        return jsonify({'error': '用户名、邮箱和密码不能为空'}), 400
    
    try:
        existing_user = supabase.table('users').select('id').eq('username', username).execute()
        if existing_user.data:
            return jsonify({'error': '该用户名已存在'}), 409

        existing_email = supabase.table('users').select('id').eq('email', email).execute()
        if existing_email.data:
            return jsonify({'error': '该邮箱已被注册'}), 409
        
        hashed_password = generate_password_hash(password)
        
        new_user_response = supabase.table('users').insert({
            'username': username,
            'email': email,
            'password': hashed_password,
        }).execute()
        
        if new_user_response.data:
            user = new_user_response.data[0]
            token = generate_token(user['id'], user['username'])
            return jsonify({
                'message': '注册成功',
                'user': {'id': user['id'], 'username': user['username'], 'email': user['email']},
                'token': token
            }), 201
        else:
            return jsonify({'error': '注册失败，请稍后重试'}), 500
            
    except Exception as e:
        return jsonify({'error': f'服务器内部错误: {str(e)}'}), 500

@app.route('/auth/login', methods=['POST'])
def login_user():
    """用户登录"""
    if not supabase:
        return jsonify({'error': '数据库服务未配置'}), 500
        
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    
    if not all([username, password]):
        return jsonify({'error': '用户名和密码不能为空'}), 400
    
    try:
        user_response = supabase.table('users').select('*').eq('username', username).limit(1).execute()
        
        if user_response.data:
            user = user_response.data[0]
            if check_password_hash(user.get('password', ''), password):
                token = generate_token(user['id'], user['username'])
                
                try:
                    supabase.table('users').update({'last_login_at': datetime.now().isoformat()}).eq('id', user['id']).execute()
                except Exception:
                    pass
                
                return jsonify({
                    'message': '登录成功',
                    'user': {'id': user['id'], 'username': user['username'], 'email': user.get('email')},
                    'token': token
                })
        
        return jsonify({'error': '用户名或密码错误'}), 401
            
    except Exception as e:
        return jsonify({'error': f'服务器内部错误: {str(e)}'}), 500

@app.route('/auth/forgot-password', methods=['POST'])
def forgot_password():
    """忘记密码，发送重置邮件"""
    if not supabase or not app.config.get('MAIL_USERNAME'):
        return jsonify({'error': '服务未配置完整，无法发送邮件'}), 500

    data = request.get_json()
    email = data.get('email')
    if not email:
        return jsonify({'error': '邮箱地址不能为空'}), 400

    try:
        user_response = supabase.table('users').select('id, username').eq('email', email).limit(1).execute()
        if not user_response.data:
            return jsonify({'message': '如果该邮箱已注册，您将会收到一封密码重置邮件。'})

        user = user_response.data[0]
        reset_token = generate_token(user['id'], user['username'], expires_delta=timedelta(minutes=15))
        # 更新链接以指向新的HTML页面
        reset_link = f"{FRONTEND_URL}/reset_password.html?token={reset_token}"

        msg = Message(
            '重置您的密码',
            sender=SENDER_EMAIL,
            recipients=[email]
        )
        msg.body = f"您好，请点击以下链接在浏览器中打开以重置您的密码：
{reset_link}

如果您没有请求重置密码，请忽略此邮件。
该链接将在15分钟后失效."
        
        mail.send(msg)
        
        return jsonify({'message': '如果该邮箱已注册，您将会收到一封密码重置邮件。'})

    except Exception as e:
        print(f"邮件发送失败: {e}")
        return jsonify({'message': '如果该邮箱已注册，您将会收到一封密码重置邮件。'})


@app.route('/auth/reset-password', methods=['POST'])
def reset_password():
    """重置密码"""
    if not supabase:
        return jsonify({'error': '数据库服务未配置'}), 500

    data = request.get_json()
    token = data.get('token')
    new_password = data.get('password')

    if not all([token, new_password]):
        return jsonify({'error': '令牌和新密码不能为空'}), 400

    payload = verify_token(token)
    if not payload:
        return jsonify({'error': '令牌无效或已过期'}), 401

    user_id = payload['user_id']
    hashed_password = generate_password_hash(new_password)

    try:
        supabase.table('users').update({'password': hashed_password}).eq('id', user_id).execute()
        return jsonify({'message': '密码重置成功，您现在可以用新密码登录。'})
    except Exception as e:
        return jsonify({'error': f'密码重置失败: {str(e)}'}), 500

@app.route('/photos', methods=['GET'])
def get_photos():
    """获取照片列表（只返回当前用户的照片）"""
    if not supabase:
        return jsonify([]) # 返回空列表而非测试数据
    
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        return jsonify({'error': '缺少认证token'}), 401
    token = auth_header.split(' ')[1]
    payload = verify_token(token)
    if not payload:
        return jsonify({'error': 'token无效或已过期'}), 401
    user_id = payload['user_id']
    try:
        response = supabase.table('photos').select('*').eq('user_id', user_id).execute()
        return jsonify(response.data)
    except Exception as e:
        return jsonify({'error': f'获取照片失败: {str(e)}'}), 500

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
        'username': payload['username']
    })

@app.route('/photos', methods=['POST'])
def upload_photo():
    """上传照片（自动写入user_id）"""
    if not supabase:
        return jsonify({'error': 'Supabase未配置'}), 500
    
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
        photo_data = {
            'user_id': user_id,
            'tags': data.get('tags', []),
            'description': data.get('description'),
            'year': data.get('year'),
            'url': data.get('url'),
            'thumbnail_url': data.get('thumbnail_url'),
        }
        result = supabase.table('photos').insert(photo_data).execute()
        if result.data:
            return jsonify(result.data[0])
        else:
            return jsonify({'error': '照片保存失败'}), 500
    except Exception as e:
        return jsonify({'error': f'上传照片失败: {str(e)}'}), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=8080)
 