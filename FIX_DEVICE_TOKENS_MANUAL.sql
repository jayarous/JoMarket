-- Manual Fix for Device Tokens Constraint Error
-- 
-- INSTRUCTIONS:
-- 1. Go to your Supabase Dashboard: https://supabase.com/dashboard/project/qjwnudofsiznvfcgzwuv
-- 2. Navigate to the SQL Editor (left sidebar)
-- 3. Create a new query
-- 4. Copy and paste this entire SQL script
-- 5. Click "Run" to execute
--
-- This script will:
-- - Add a unique constraint on (user_id, token) to the device_tokens table
-- - Create indexes for better performance
-- - Fix the "no unique or exclusion constraint matching the ON CONFLICT specification" error

-- Add unique constraint on (user_id, token) combination
-- This allows the same token to be used across different users (unlikely but possible)
-- and prevents duplicate tokens for the same user
ALTER TABLE public.device_tokens
  ADD CONSTRAINT device_tokens_user_token_unique
  UNIQUE (user_id, token);

-- Create an index for performance on user_id lookups
CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id
  ON public.device_tokens(user_id);

-- Create an index for performance on token lookups
CREATE INDEX IF NOT EXISTS idx_device_tokens_token
  ON public.device_tokens(token);

-- Verify the constraint was added
SELECT 
  conname AS constraint_name,
  contype AS constraint_type,
  pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.device_tokens'::regclass
  AND conname = 'device_tokens_user_token_unique';
