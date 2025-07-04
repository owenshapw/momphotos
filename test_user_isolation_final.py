#!/usr/bin/env python3
"""
测试用户隔离和缓存清理
"""
import requests
import json
import time

BASE_URL = 'http://localhost:8080'

def test_user_isolation():
    """测试用户隔离功能"""
    print("🧪 开始测试用户隔离功能...")
    
    # 测试用户1登录
    print("\n1. 测试用户1登录 (18910597028)")
    login1_response = requests.post(f'{BASE_URL}/auth/login', json={
        'phone': '18910597028',
        'password': '529751'
    })
    
    if login1_response.status_code != 200:
        print(f"❌ 用户1登录失败: {login1_response.text}")
        return
    
    user1_data = login1_response.json()
    user1_token = user1_data['token']
    user1_id = user1_data['user']['id']
    print(f"✅ 用户1登录成功: {user1_data['user']['phone']} (ID: {user1_id})")
    
    # 获取用户1的照片
    print("\n2. 获取用户1的照片")
    photos1_response = requests.get(f'{BASE_URL}/photos', headers={
        'Authorization': f'Bearer {user1_token}'
    })
    
    if photos1_response.status_code != 200:
        print(f"❌ 获取用户1照片失败: {photos1_response.text}")
        return
    
    photos1 = photos1_response.json()
    print(f"✅ 用户1照片数量: {len(photos1)}")
    
    # 显示前3张照片的信息
    for i, photo in enumerate(photos1[:3]):
        print(f"  照片{i+1}: ID={photo['id']}, 用户ID={photo['user_id']}")
    
    # 测试用户2登录
    print("\n3. 测试用户2登录 (13800138000)")
    login2_response = requests.post(f'{BASE_URL}/auth/login', json={
        'phone': '13800138000',
        'password': '123456'
    })
    
    if login2_response.status_code != 200:
        print(f"❌ 用户2登录失败: {login2_response.text}")
        return
    
    user2_data = login2_response.json()
    user2_token = user2_data['token']
    user2_id = user2_data['user']['id']
    print(f"✅ 用户2登录成功: {user2_data['user']['phone']} (ID: {user2_id})")
    
    # 获取用户2的照片
    print("\n4. 获取用户2的照片")
    photos2_response = requests.get(f'{BASE_URL}/photos', headers={
        'Authorization': f'Bearer {user2_token}'
    })
    
    if photos2_response.status_code != 200:
        print(f"❌ 获取用户2照片失败: {photos2_response.text}")
        return
    
    photos2 = photos2_response.json()
    print(f"✅ 用户2照片数量: {len(photos2)}")
    
    # 显示前3张照片的信息
    for i, photo in enumerate(photos2[:3]):
        print(f"  照片{i+1}: ID={photo['id']}, 用户ID={photo['user_id']}")
    
    # 验证用户隔离
    print("\n5. 验证用户隔离")
    user1_photo_ids = {photo['id'] for photo in photos1}
    user2_photo_ids = {photo['id'] for photo in photos2}
    
    common_photos = user1_photo_ids.intersection(user2_photo_ids)
    
    if common_photos:
        print(f"❌ 发现共享照片: {len(common_photos)} 张")
        for photo_id in common_photos:
            print(f"  共享照片ID: {photo_id}")
    else:
        print("✅ 用户隔离正常，没有共享照片")
    
    # 再次获取用户1的照片，验证缓存
    print("\n6. 再次获取用户1的照片（验证缓存）")
    photos1_again_response = requests.get(f'{BASE_URL}/photos', headers={
        'Authorization': f'Bearer {user1_token}'
    })
    
    if photos1_again_response.status_code == 200:
        photos1_again = photos1_again_response.json()
        print(f"✅ 用户1照片数量（缓存）: {len(photos1_again)}")
        
        # 验证照片数量是否一致
        if len(photos1) == len(photos1_again):
            print("✅ 缓存工作正常，照片数量一致")
        else:
            print(f"❌ 缓存异常，照片数量不一致: {len(photos1)} vs {len(photos1_again)}")
    
    print("\n🎉 用户隔离测试完成！")

if __name__ == '__main__':
    try:
        test_user_isolation()
    except Exception as e:
        print(f"❌ 测试失败: {e}") 