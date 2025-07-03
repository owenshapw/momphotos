-- 多用户功能数据库迁移脚本 V2
-- 添加密码字段到用户表

-- 1. 为用户表添加密码字段
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'users' AND column_name = 'password') THEN
        ALTER TABLE users ADD COLUMN password VARCHAR(100);
    END IF;
END $$;

-- 2. 为默认用户设置密码
UPDATE users 
SET password = '194201' 
WHERE id = '00000000-0000-0000-0000-000000000000' AND password IS NULL;

-- 3. 设置密码字段为NOT NULL（可选，如果要求所有用户都有密码）
-- ALTER TABLE users ALTER COLUMN password SET NOT NULL;

-- 4. 验证迁移结果
SELECT 'Password migration completed successfully' as status;
SELECT id, phone, username, password IS NOT NULL as has_password FROM users; 