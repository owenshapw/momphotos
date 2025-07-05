 -- 多用户功能数据库迁移脚本
-- 执行前请备份现有数据

-- 1. 创建用户表
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone VARCHAR(20) UNIQUE NOT NULL,
    username VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. 为照片表添加用户ID字段
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'photos' AND column_name = 'user_id') THEN
        ALTER TABLE photos ADD COLUMN user_id UUID;
    END IF;
END $$;

-- 3. 创建默认用户
INSERT INTO users (id, phone, username) 
VALUES (
    '00000000-0000-0000-0000-000000000000',
    '13800000000',
    '默认用户'
) ON CONFLICT (phone) DO NOTHING;

-- 4. 将现有照片关联到默认用户
UPDATE photos 
SET user_id = '00000000-0000-0000-0000-000000000000' 
WHERE user_id IS NULL;

-- 5. 设置user_id为NOT NULL
ALTER TABLE photos ALTER COLUMN user_id SET NOT NULL;

-- 6. 添加外键约束
ALTER TABLE photos 
ADD CONSTRAINT fk_photos_user_id 
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

-- 7. 创建索引
CREATE INDEX IF NOT EXISTS idx_photos_user_id ON photos(user_id);
CREATE INDEX IF NOT EXISTS idx_photos_user_created_at ON photos(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_photos_user_year ON photos(user_id, year DESC);

-- 8. 验证迁移结果
SELECT 'Migration completed successfully' as status;
SELECT COUNT(*) as total_users FROM users;
SELECT COUNT(*) as total_photos FROM photos;