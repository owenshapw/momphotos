#!/usr/bin/env python3
"""
数据库迁移脚本
"""
import os
from dotenv import load_dotenv

# 加载环境变量
load_dotenv()

# Supabase配置
SUPABASE_URL = os.environ.get('SUPABASE_URL', 'your-supabase-url')
SUPABASE_KEY = os.environ.get('SUPABASE_KEY', 'your-supabase-key')

def run_migration():
    """执行数据库迁移"""
    if SUPABASE_URL == 'your-supabase-url' or SUPABASE_KEY == 'your-supabase-key':
        print("❌ 请先配置Supabase环境变量")
        return
    
    try:
        from supabase import create_client, Client
        supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
        print("✅ Supabase客户端初始化成功")
        
        # 读取迁移脚本
        with open('database_migration_v2.sql', 'r', encoding='utf-8') as f:
            migration_sql = f.read()
        
        print("🔧 开始执行数据库迁移...")
        
        # 执行迁移
        result = supabase.rpc('exec_sql', {'sql': migration_sql}).execute()
        
        print("✅ 数据库迁移完成！")
        print(f"结果: {result}")
        
    except Exception as e:
        print(f"❌ 迁移失败: {e}")

if __name__ == '__main__':
    run_migration() 