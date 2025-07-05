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