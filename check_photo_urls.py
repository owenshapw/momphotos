#!/usr/bin/env python3
"""
检查照片URL可访问性的脚本
"""

import requests
import json

# 配置
BASE_URL = "https://momphotos.onrender.com"
USERNAME = "13800138000"
PASSWORD = "194201"

def check_photo_urls():
    """检查照片URL的可访问性"""
    print("🔍 检查照片URL可访问性...")
    print(f"用户: {USERNAME}")
    print(f"服务器: {BASE_URL}")
    print("-" * 50)
    
    # 1. 登录获取token
    print("1. 登录获取token...")
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
        
        if login_response.status_code != 200:
            print(f"❌ 登录失败: {login_response.status_code}")
            return
        
        login_result = login_response.json()
        token = login_result.get('token')
        print("✅ 登录成功")
    except Exception as e:
        print(f"❌ 登录请求失败: {e}")
        return
    
    # 2. 获取照片列表
    print("\n2. 获取照片列表...")
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
        
        if photos_response.status_code != 200:
            print(f"❌ 获取照片失败: {photos_response.status_code}")
            return
        
        photos_data = photos_response.json()
        print(f"✅ 获取到 {len(photos_data)} 张照片")
    except Exception as e:
        print(f"❌ 获取照片请求失败: {e}")
        return
    
    # 3. 检查前10张照片的URL
    print("\n3. 检查前10张照片的URL...")
    print("-" * 80)
    
    for i, photo in enumerate(photos_data[:10]):
        photo_id = photo.get('id')
        url = photo.get('url')
        thumbnail_url = photo.get('thumbnail_url')
        
        print(f"照片 {i+1}:")
        print(f"  ID: {photo_id}")
        print(f"  原图URL: {url}")
        print(f"  缩略图URL: {thumbnail_url}")
        
        # 检查原图URL
        if url:
            try:
                response = requests.head(url, timeout=5)
                if response.status_code == 200:
                    print(f"  ✅ 原图可访问 (状态码: {response.status_code})")
                else:
                    print(f"  ❌ 原图不可访问 (状态码: {response.status_code})")
            except Exception as e:
                print(f"  ❌ 原图访问失败: {e}")
        
        # 检查缩略图URL
        if thumbnail_url:
            try:
                response = requests.head(thumbnail_url, timeout=5)
                if response.status_code == 200:
                    print(f"  ✅ 缩略图可访问 (状态码: {response.status_code})")
                else:
                    print(f"  ❌ 缩略图不可访问 (状态码: {response.status_code})")
            except Exception as e:
                print(f"  ❌ 缩略图访问失败: {e}")
        
        print()
    
    print("🔍 检查完成")

if __name__ == "__main__":
    check_photo_urls() 