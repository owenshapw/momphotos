#!/usr/bin/env python3
"""
更新用户密码脚本
"""
import os
from dotenv import load_dotenv

# 加载环境变量
load_dotenv()

# Supabase配置
SUPABASE_URL = os.environ.get('SUPABASE_URL', 'your-supabase-url')
SUPABASE_KEY = os.environ.get('SUPABASE_KEY', 'your-supabase-key')

def update_user_password():
    """更新用户密码"""
    if SUPABASE_URL == 'your-supabase-url' or SUPABASE_KEY == 'your-supabase-key':
        print("❌ 请先配置Supabase环境变量")
        return
    
    try:
        from supabase import create_client, Client
        supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
        print("✅ Supabase客户端初始化成功")
        
        # 查找用户13800138000
        user_response = supabase.table('users').select('*').eq('phone', '13800138000').execute()
        
        if not user_response.data:
            print("❌ 用户13800138000不存在")
            return
        
        user = user_response.data[0]
        user_id = user['id']
        old_password = user.get('password', '未设置')
        
        print(f"✅ 找到用户: {user['phone']} (ID: {user_id})")
        print(f"📝 当前密码: {old_password}")
        
        # 更新密码
        update_response = supabase.table('users').update({
            'password': '194201'
        }).eq('id', user_id).execute()
        
        if update_response.data:
            print("✅ 密码更新成功！")
            print(f"📝 新密码: 123456")
            
            # 验证更新
            verify_response = supabase.table('users').select('password').eq('id', user_id).execute()
            if verify_response.data:
                new_password = verify_response.data[0]['password']
                print(f"🔍 验证结果: 密码已更新为 {new_password}")
        else:
            print("❌ 密码更新失败")
            
    except Exception as e:
        print(f"❌ 更新失败: {e}")

if __name__ == '__main__':
    update_user_password() 