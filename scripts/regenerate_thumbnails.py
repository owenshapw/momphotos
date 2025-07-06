import os
from supabase import create_client, Client
from PIL import Image
import io
import requests
from urllib.parse import urlparse

# 配置你的 Supabase
url = "https://ufxuetpndfqqvuapfjli.supabase.co"
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVmeHVldHBuZGZxcXZ1YXBmamxpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTExNzkyNTEsImV4cCI6MjA2Njc1NTI1MX0.8476yI58Hvm99mo67R-Ga-AfZh9QGlFfLdX0yDavNlQ"
BUCKET_NAME = "photos"

supabase: Client = create_client(url, key)

def download_image(image_url):
    """下载图片"""
    try:
        response = requests.get(image_url, timeout=30)
        response.raise_for_status()
        image = Image.open(io.BytesIO(response.content))
        
        # 处理 EXIF 方向信息
        try:
            # 获取 EXIF 数据
            exif = image.getexif()
            if exif is not None:
                # 获取方向信息
                orientation = exif.get(274)  # 274 是方向标签的 ID
                if orientation is not None:
                    # 根据方向信息旋转图片
                    if orientation == 3:
                        image = image.rotate(180, expand=True)
                    elif orientation == 6:
                        image = image.rotate(270, expand=True)
                    elif orientation == 8:
                        image = image.rotate(90, expand=True)
        except Exception:
            pass
        
        # 确保图片方向正确
        try:
            # 转换为 RGB 模式
            if image.mode != 'RGB':
                image = image.convert('RGB')
        except Exception:
            pass
        
        return image
    except Exception as e:
        print(f"下载图片失败 {image_url}: {e}")
        return None

def create_thumbnail(image, target_width=300, target_height=400):
    """创建缩略图，固定300x400尺寸，从原图中心截取"""
    try:
        img_width, img_height = image.size
        
        # 计算缩放比例，确保图片能完全覆盖目标尺寸
        scale_x = target_width / img_width
        scale_y = target_height / img_height
        scale = max(scale_x, scale_y)  # 使用较大的缩放比例
        
        # 计算缩放后的尺寸
        new_width = int(img_width * scale)
        new_height = int(img_height * scale)
        
        # 调整图片大小
        resized_image = image.resize((new_width, new_height), Image.Resampling.LANCZOS)
        
        # 从中心截取目标尺寸
        left = (new_width - target_width) // 2
        top = (new_height - target_height) // 2
        right = left + target_width
        bottom = top + target_height
        
        # 截取中心部分
        thumbnail = resized_image.crop((left, top, right, bottom))
        
        return thumbnail
    except Exception as e:
        print(f"创建缩略图失败: {e}")
        return None

def upload_thumbnail(thumbnail, photo_id):
    """上传缩略图到Supabase存储"""
    try:
        # 将图片转换为字节流
        img_byte_arr = io.BytesIO()
        thumbnail.save(img_byte_arr, format='JPEG', quality=95, optimize=True)
        img_byte_arr.seek(0)
        
        # 上传到Supabase
        file_path = f"thumbnails/{photo_id}.jpg"
        
        # 先尝试删除旧文件（如果存在）
        try:
            supabase.storage.from_(BUCKET_NAME).remove([file_path])
            print(f"  - 删除旧文件: {file_path}")
        except Exception as e:
            # 文件不存在，忽略错误
            pass
        
        # 上传新文件
        supabase.storage.from_(BUCKET_NAME).upload(
            file_path,
            img_byte_arr.getvalue(),
            {"content-type": "image/jpeg"}
        )
        
        # 获取公共URL
        public_url = supabase.storage.from_(BUCKET_NAME).get_public_url(file_path)
        return public_url
    except Exception as e:
        print(f"上传缩略图失败 {photo_id}: {e}")
        return None

def update_database_thumbnail_url(photo_id, thumbnail_url):
    """更新数据库中的缩略图URL"""
    try:
        supabase.table('photos').update({
            'thumbnail_url': thumbnail_url
        }).eq('id', photo_id).execute()
        return True
    except Exception as e:
        print(f"更新数据库失败 {photo_id}: {e}")
        return False

def main():
    print("开始重新生成缩略图...")
    
    # 获取所有照片，增加重试机制
    photos = None
    for attempt in range(3):
        try:
            photos = supabase.table('photos').select('id, url').execute().data
            print(f"找到 {len(photos)} 张照片需要生成缩略图")
            break
        except Exception as e:
            print(f"获取照片列表失败 (尝试 {attempt + 1}/3): {e}")
            if attempt < 2:
                import time
                time.sleep(2)  # 等待2秒后重试
            else:
                print("无法获取照片列表，退出程序")
                return
    
    if photos is None:
        return
        
    success_count = 0
    error_count = 0
    
    for i, photo in enumerate(photos, 1):
        photo_id = photo['id']
        image_url = photo['url']
        
        print(f"[{i}/{len(photos)}] 处理照片 {photo_id}...")
        
        try:
            # 下载原图
            image = download_image(image_url)
            if image is None:
                error_count += 1
                continue
            
            # 创建缩略图
            thumbnail = create_thumbnail(image)
            if thumbnail is None:
                error_count += 1
                continue
            
            # 上传缩略图
            thumbnail_url = upload_thumbnail(thumbnail, photo_id)
            if thumbnail_url is None:
                error_count += 1
                continue
            
            # 更新数据库
            if update_database_thumbnail_url(photo_id, thumbnail_url):
                success_count += 1
                print(f"  ✓ 成功生成缩略图: {photo_id}")
            else:
                error_count += 1
                
        except Exception as e:
            print(f"  ✗ 处理失败 {photo_id}: {e}")
            error_count += 1
    
    print(f"\n缩略图生成完成！")
    print(f"成功: {success_count} 张")
    print(f"失败: {error_count} 张")

if __name__ == '__main__':
    main() 