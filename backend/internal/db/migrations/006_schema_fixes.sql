-- Migration 006: Schema alignment fixes
-- The notifications table in 001_init.sql only has (type, message)
-- but the application also needs the columns to be consistent.
-- No column changes needed for notifications since model now matches DB.

-- Add estimated_time_minutes to bounties (referenced in AGENT_MASTER_PLAN)
ALTER TABLE bounties ADD COLUMN IF NOT EXISTS estimated_time_minutes INTEGER;
