#!/usr/bin/env python3
"""
测试缓存修复效果
"""
import requests
import json

BASE_URL = 'http://localhost:8080'

def test_cache_fix():
    """测试缓存修复"""
    print("🧪 测试缓存修复效果...")
    
    # 测试用户1登录
    print("\n1. 用户1登录 (18910597028)")
    login1 = requests.post(f'{BASE_URL}/auth/login', json={
        'phone': '18910597028',
        'password': '529751'
    })
    
    if login1.status_code != 200:
        print(f"❌ 用户1登录失败: {login1.text}")
        return
    
    user1_data = login1.json()
    user1_token = user1_data['token']
    print(f"✅ 用户1登录成功: {user1_data['user']['phone']}")
    
    # 获取用户1照片
    photos1 = requests.get(f'{BASE_URL}/photos', headers={
        'Authorization': f'Bearer {user1_token}'
    })
    
    if photos1.status_code == 200:
        photos1_data = photos1.json()
        print(f"✅ 用户1照片数量: {len(photos1_data)}")
    else:
        print(f"❌ 获取用户1照片失败: {photos1.text}")
        return
    
    # 测试用户2登录
    print("\n2. 用户2登录 (13800138000)")
    login2 = requests.post(f'{BASE_URL}/auth/login', json={
        'phone': '13800138000',
        'password': '123456'
    })
    
    if login2.status_code != 200:
        print(f"❌ 用户2登录失败: {login2.text}")
        return
    
    user2_data = login2.json()
    user2_token = user2_data['token']
    print(f"✅ 用户2登录成功: {user2_data['user']['phone']}")
    
    # 获取用户2照片
    photos2 = requests.get(f'{BASE_URL}/photos', headers={
        'Authorization': f'Bearer {user2_token}'
    })
    
    if photos2.status_code == 200:
        photos2_data = photos2.json()
        print(f"✅ 用户2照片数量: {len(photos2_data)}")
    else:
        print(f"❌ 获取用户2照片失败: {photos2.text}")
        return
    
    # 再次获取用户1照片，验证缓存隔离
    print("\n3. 再次获取用户1照片（验证缓存隔离）")
    photos1_again = requests.get(f'{BASE_URL}/photos', headers={
        'Authorization': f'Bearer {user1_token}'
    })
    
    if photos1_again.status_code == 200:
        photos1_again_data = photos1_again.json()
        print(f"✅ 用户1照片数量（缓存）: {len(photos1_again_data)}")
        
        # 验证照片数量是否一致
        if len(photos1_data) == len(photos1_again_data):
            print("✅ 缓存隔离正常，用户1照片数量一致")
        else:
            print(f"❌ 缓存隔离异常，用户1照片数量不一致: {len(photos1_data)} vs {len(photos1_again_data)}")
    
    print("\n🎉 缓存修复测试完成！")

if __name__ == '__main__':
    try:
        test_cache_fix()
    except Exception as e:
        print(f"❌ 测试失败: {e}") 