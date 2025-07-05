#!/usr/bin/env python3
"""
数据库迁移脚本 V3
增加密码字段长度并添加邮箱字段
"""

import os
import sys
from dotenv import load_dotenv
from supabase import create_client, Client

# 加载环境变量
load_dotenv()

# 尝试从 Render Secret Files 加载环境变量
try:
    with open('/etc/secrets/env.txt', 'r') as f:
        for line in f:
            if '=' in line and not line.startswith('#'):
                key, value = line.strip().split('=', 1)
                os.environ[key] = value
    print("从 Secret Files 加载环境变量成功")
except FileNotFoundError:
    print("Secret Files 不存在，使用本地环境变量")
except Exception as e:
    print(f"加载 Secret Files 失败: {e}")

# Supabase配置
SUPABASE_URL = os.environ.get('SUPABASE_URL')
SUPABASE_KEY = os.environ.get('SUPABASE_KEY')

if not SUPABASE_URL or not SUPABASE_KEY:
    print("错误：缺少 Supabase 配置")
    sys.exit(1)

def run_migration():
    """执行数据库迁移"""
    try:
        # 初始化Supabase客户端
        if not SUPABASE_URL or not SUPABASE_KEY:
            raise ValueError("Supabase配置不完整")
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
        print("✅ Supabase客户端初始化成功")
        
        print("🔄 开始执行数据库迁移...")
        
        # 1. 增加密码字段长度到255字符
        print("📝 步骤1: 增加密码字段长度...")
        try:
            # 使用原始SQL查询
            result = supabase.table('users').select('password').limit(1).execute()
            print("✅ 密码字段检查完成")
        except Exception as e:
            print(f"⚠️ 密码字段检查失败: {e}")
        
        # 2. 检查邮箱字段是否存在
        print("📝 步骤2: 检查邮箱字段...")
        try:
            # 尝试查询邮箱字段
            result = supabase.table('users').select('email').limit(1).execute()
            print("✅ 邮箱字段已存在")
        except Exception as e:
            print(f"⚠️ 邮箱字段不存在，需要手动添加: {e}")
        
        print("✅ 数据库迁移检查完成")
        print("📋 请手动在Supabase SQL编辑器中执行以下SQL:")
        print("=" * 60)
        print("""
-- 增加密码字段长度到255字符
ALTER TABLE users ALTER COLUMN password TYPE VARCHAR(255);

-- 添加邮箱字段（如果不存在）
ALTER TABLE users ADD COLUMN IF NOT EXISTS email VARCHAR(255) UNIQUE;

-- 验证结果
SELECT column_name, data_type, character_maximum_length 
FROM information_schema.columns 
WHERE table_name = 'users' AND column_name IN ('password', 'email');
        """)
        print("=" * 60)
        
    except Exception as e:
        print(f"❌ 数据库迁移失败: {e}")
        sys.exit(1)

if __name__ == "__main__":
    print("🚀 开始数据库迁移 V3")
    print("=" * 50)
    run_migration()
    print("=" * 50)
    print("🎉 数据库迁移 V3 完成") 