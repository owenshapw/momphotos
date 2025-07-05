-- Migration V3: Switch from phone number to username/email authentication

-- Step 1: Drop the existing unique constraint on the old 'username' field.
-- The constraint name might vary depending on your PostgreSQL version and how it was created.
-- You may need to find the correct constraint name using Supabase's UI or a query.
-- Common default names are 'users_username_key' or 'unique_username'.
ALTER TABLE users DROP CONSTRAINT IF EXISTS unique_username;

-- Step 2: Drop the old 'username' column.
ALTER TABLE users DROP COLUMN IF EXISTS username;

-- Step 3: Rename the 'phone' column to 'username'.
-- This will now serve as the primary identifier for login.
ALTER TABLE users RENAME COLUMN phone TO username;

-- Step 4: Add a new 'email' column.
-- It is set to be unique, as it will be used for password recovery and notifications.
ALTER TABLE users ADD COLUMN email VARCHAR(255);
ALTER TABLE users ADD CONSTRAINT unique_email UNIQUE (email);

-- Step 5: Add 'email_verified_at' column to track email verification status.
ALTER TABLE users ADD COLUMN email_verified_at TIMESTAMP WITH TIME ZONE;

-- Verification
SELECT 'Migration V3 completed successfully' as status;

-- 1. 增加密码字段长度到255字符
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'users' AND column_name = 'password') THEN
        ALTER TABLE users ALTER COLUMN password TYPE VARCHAR(255);
    END IF;
END $$;

-- 2. 添加邮箱字段
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'users' AND column_name = 'email') THEN
        ALTER TABLE users ADD COLUMN email VARCHAR(255) UNIQUE;
    END IF;
END $$;

-- 3. 验证迁移结果
SELECT 'Password length migration completed successfully' as status;
SELECT column_name, data_type, character_maximum_length 
FROM information_schema.columns 
WHERE table_name = 'users' AND column_name IN ('password', 'email');