-- 39_fix_device_tokens_constraint.sql
-- Add unique constraint to device_tokens to support ON CONFLICT in upsert operations

-- Add unique constraint on (user_id, token) combination
-- This allows the same token to be used across different users (unlikely but possible)
-- and prevents duplicate tokens for the same user
alter table public.device_tokens
  add constraint device_tokens_user_token_unique
  unique (user_id, token);

-- Create an index for performance on user_id lookups
create index if not exists idx_device_tokens_user_id
  on public.device_tokens(user_id);

-- Create an index for performance on token lookups
create index if not exists idx_device_tokens_token
  on public.device_tokens(token);
