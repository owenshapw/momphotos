import os
import io
import requests
try:
    from PIL import Image, ExifTags
except ImportError:
    raise ImportError("Pillow (PIL) is required. Install it with 'pip install pillow'.")

try:
    from supabase import create_client, Client
except ImportError:
    raise ImportError("supabase-py is required. Install it with 'pip install supabase'.")

import uuid

# ========== 配置你的 Supabase ==========
SUPABASE_URL = os.environ.get("SUPABASE_URL") or "https://ufxuetpndfqqvuapfjli.supabase.co"
SUPABASE_KEY = os.environ.get("SUPABASE_KEY") or "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVmeHVldHBuZGZxcXZ1YXBmamxpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTExNzkyNTEsImV4cCI6MjA2Njc1NTI1MX0.8476yI58Hvm99mo67R-Ga-AfZh9QGlFfLdX0yDavNlQ"
BUCKET_NAME = "photos"
# =======================================

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def correct_image_orientation(img):
    try:
        exif = img._getexif()
        if exif is not None:
            for orientation in ExifTags.TAGS.keys():
                if ExifTags.TAGS[orientation] == 'Orientation':
                    break
            orientation_value = exif.get(orientation, None)
            if orientation_value == 3:
                img = img.rotate(180, expand=True)
            elif orientation_value == 6:
                img = img.rotate(270, expand=True)
            elif orientation_value == 8:
                img = img.rotate(90, expand=True)
    except Exception as e:
        pass
    return img

def generate_and_upload_thumbnail(photo):
    url = photo['url']
    photo_id = photo['id']
    filename = url.split('/')[-1]
    thumb_path = f"thumbnails/{filename}"

    # 跳过已有缩略图的
    if photo.get('thumbnail_url') and 'thumbnails/' in photo['thumbnail_url']:
        print(f"跳过已有缩略图: {photo_id}")
        return

    # 下载原图
    try:
        resp = requests.get(url)
        resp.raise_for_status()
        img = Image.open(io.BytesIO(resp.content))
        img = correct_image_orientation(img)
        img.thumbnail((300, 300))
        thumb_io = io.BytesIO()
        save_format = img.format if img.format else 'JPEG'
        img.save(thumb_io, format=save_format)
        thumb_io.seek(0)
        thumbnail_content = thumb_io.read()
    except Exception as e:
        print(f"下载或生成缩略图失败: {photo_id}, {e}")
        return

    # 上传缩略图
    try:
        supabase.storage.from_(BUCKET_NAME).upload(thumb_path, thumbnail_content)
        thumbnail_url = supabase.storage.from_(BUCKET_NAME).get_public_url(thumb_path)
        print(f"缩略图已上传: {thumbnail_url}")
    except Exception as e:
        print(f"上传缩略图失败: {photo_id}, {e}")
        return

    # 更新数据库
    try:
        supabase.table('photos').update({'thumbnail_url': thumbnail_url}).eq('id', photo_id).execute()
        print(f"数据库已更新: {photo_id}")
    except Exception as e:
        print(f"数据库更新失败: {photo_id}, {e}")

def main():
    # 获取所有照片
    photos = supabase.table('photos').select('*').execute().data
    print(f"共{len(photos)}张照片")
    for photo in photos:
        generate_and_upload_thumbnail(photo)

if __name__ == '__main__':
    main()