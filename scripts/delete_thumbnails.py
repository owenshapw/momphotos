import os
from supabase import create_client, Client

# 配置你的 Supabase
url = "https://ufxuetpndfqqvuapfjli.supabase.co"
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVmeHVldHBuZGZxcXZ1YXBmamxpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTExNzkyNTEsImV4cCI6MjA2Njc1NTI1MX0.8476yI58Hvm99mo67R-Ga-AfZh9QGlFfLdX0yDavNlQ"
BUCKET_NAME = "photos"

supabase: Client = create_client(url, key)

def main():
    # 列出 thumbnails 目录下所有文件
    files = supabase.storage.from_(BUCKET_NAME).list("thumbnails")
    print(f"将要删除 {len(files)} 个缩略图文件")
    for f in files:
        path = f"thumbnails/{f['name']}"
        supabase.storage.from_(BUCKET_NAME).remove([path])
        print(f"已删除: {path}")

    # 删除存储中的缩略图文件
    files = supabase.storage.from_(BUCKET_NAME).list("thumbnails")
    print(f"将要删除 {len(files)} 个缩略图文件")
    for f in files:
        path = f"thumbnails/{f['name']}"
        supabase.storage.from_(BUCKET_NAME).remove([path])
        print(f"已删除: {path}")
    
    # 清空数据库中所有照片的 thumbnail_url 字段
    print("正在清空数据库中的 thumbnail_url 记录...")
    photos = supabase.table('photos').select('id').execute().data
    ids = [p['id'] for p in photos]
    print(f"将要清空 {len(ids)} 条记录的 thumbnail_url 字段")

    batch_size = 100
    for i in range(0, len(ids), batch_size):
        batch_ids = ids[i:i+batch_size]
        supabase.table('photos').update({'thumbnail_url': None}).in_('id', batch_ids).execute()
        print(f"已清空 {len(batch_ids)} 条记录的 thumbnail_url 字段")
    print("数据库 thumbnail_url 字段清空完成！")
    
    print("删除完成！")

if __name__ == '__main__':
    main()