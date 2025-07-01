import os
from supabase import create_client, Client

# 配置你的 Supabase
SUPABASE_URL = os.environ.get("SUPABASE_URL") or "你的supabase url"
SUPABASE_KEY = os.environ.get("SUPABASE_KEY") or "你的supabase key"
BUCKET_NAME = "photos"

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def main():
    # 列出 thumbnails 目录下所有文件
    files = supabase.storage.from_(BUCKET_NAME).list("thumbnails")
    print(f"将要删除 {len(files)} 个缩略图文件")
    for f in files:
        path = f"thumbnails/{f['name']}"
        supabase.storage.from_(BUCKET_NAME).remove([path])
        print(f"已删除: {path}")

if __name__ == '__main__':
    main()