#!/usr/bin/env python3
"""
调试脚本：检查用户13800138000的照片问题
"""

import requests
import json

# 配置
BASE_URL = "https://momphotos.onrender.com"  # 或者你的本地服务器地址
USERNAME = "13800138000"
PASSWORD = "194201"  # 正确的密码

def test_user_photos():
    """测试用户照片获取"""
    print("🔍 开始调试用户照片问题...")
    print(f"用户: {USERNAME}")
    print(f"密码: {PASSWORD}")
    print(f"服务器: {BASE_URL}")
    print("-" * 50)
    
    # 1. 测试登录
    print("1. 测试用户登录...")
    login_data = {
        "username": USERNAME,
        "password": PASSWORD
    }
    
    try:
        login_response = requests.post(
            f"{BASE_URL}/auth/login",
            json=login_data,
            timeout=10
        )
        
        if login_response.status_code == 200:
            login_result = login_response.json()
            token = login_result.get('token')
            user_id = login_result.get('user', {}).get('id')
            print(f"✅ 登录成功")
            print(f"   用户ID: {user_id}")
            print(f"   预期ID: 9d4cee0f-1f04-4685-8f4d-d2e9c71e7469")
            print(f"   ID匹配: {'✅' if user_id == '9d4cee0f-1f04-4685-8f4d-d2e9c71e7469' else '❌'}")
            print(f"   Token: {token[:20]}...")
        else:
            print(f"❌ 登录失败: {login_response.status_code}")
            print(f"   响应: {login_response.text}")
            return
    except Exception as e:
        print(f"❌ 登录请求失败: {e}")
        return
    
    print("-" * 50)
    
    # 2. 测试获取照片
    print("2. 测试获取用户照片...")
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    try:
        photos_response = requests.get(
            f"{BASE_URL}/photos",
            headers=headers,
            timeout=10
        )
        
        if photos_response.status_code == 200:
            photos_data = photos_response.json()
            print(f"✅ 获取照片成功")
            print(f"   照片数量: {len(photos_data)}")
            
            if photos_data:
                print("   前3张照片:")
                for i, photo in enumerate(photos_data[:3]):
                    print(f"     {i+1}. ID: {photo.get('id')}, 描述: {photo.get('description', '无')}")
            else:
                print("   ⚠️ 没有找到照片")
        else:
            print(f"❌ 获取照片失败: {photos_response.status_code}")
            print(f"   响应: {photos_response.text}")
    except Exception as e:
        print(f"❌ 获取照片请求失败: {e}")
    
    print("-" * 50)
    
    # 3. 测试token验证
    print("3. 测试token验证...")
    try:
        validate_response = requests.get(
            f"{BASE_URL}/auth/validate",
            headers=headers,
            timeout=10
        )
        
        if validate_response.status_code == 200:
            validate_data = validate_response.json()
            print(f"✅ Token验证成功")
            print(f"   用户ID: {validate_data.get('user_id')}")
            print(f"   用户名: {validate_data.get('username')}")
        else:
            print(f"❌ Token验证失败: {validate_response.status_code}")
            print(f"   响应: {validate_response.text}")
    except Exception as e:
        print(f"❌ Token验证请求失败: {e}")
    
    print("-" * 50)
    print("🔍 调试完成")

if __name__ == "__main__":
    test_user_photos() 