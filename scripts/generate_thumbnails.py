import os
import requests
from PIL import Image
from io import BytesIO
from supabase import create_client
import traceback
from dotenv import load_dotenv
import os

# 加载 .env 文件
load_dotenv()


# 从环境变量中获取 Supabase 的 URL 和密钥
url = "https://ufxuetpndfqqvuapfjli.supabase.co"
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVmeHVldHBuZGZxcXZ1YXBmamxpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTExNzkyNTEsImV4cCI6MjA2Njc1NTI1MX0.8476yI58Hvm99mo67R-Ga-AfZh9QGlFfLdX0yDavNlQ"
supabase = create_client(url, key)

def generate_thumbnail(image_url):
    try:
        response = requests.get(image_url)
        response.raise_for_status()  # 检查请求是否成功
        img = Image.open(BytesIO(response.content))
        img = img.convert("RGB")
        img.thumbnail((300, 300))  # 设置缩略图的最大尺寸为 300x300
        output = BytesIO()
        img.save(output, format='JPEG', quality=80)  # 保存为 JPEG 格式
        output.seek(0)
        return output
    except Exception as e:
        print(f"缩略图生成失败: {e}")
        raise

def main():
    try:
        # 查询所有没有thumbnail_url的照片，仅选择需要的字段（id, url）
        photos = supabase.table('photos').select('id, url').is_('thumbnail_url', None).execute().data
        print(f"待处理照片数量: {len(photos)}")

        for photo in photos:
            try:
                print(f"处理照片: {photo['id']}")
                thumb_io = generate_thumbnail(photo['url'])
                thumb_path = f"photos/thumbnails/{photo['id']}_thumb.jpg"
                
                # 上传缩略图到 Supabase 存储
                supabase.storage.from_('photos').upload(thumb_path, thumb_io, file_options={"content-type": "image/jpeg", "upsert": True})

                # 获取缩略图的公共 URL
                thumb_url = supabase.storage.from_('photos').get_public_url(thumb_path)
                
                # 更新数据库中的 thumbnail_url 字段
                supabase.table('photos').update({'thumbnail_url': thumb_url}).eq('id', photo['id']).execute()

                print(f"缩略图已生成并更新: {thumb_url}")
            except Exception as e:
                print(f"处理照片 {photo['id']} 失败: {e}")
                continue  # 跳过当前照片，继续处理下一张

    except Exception as e:
        print(f"查询照片失败: {e}")
        traceback.print_exc()  # 打印详细的异常信息

if __name__ == '__main__':
    main()
