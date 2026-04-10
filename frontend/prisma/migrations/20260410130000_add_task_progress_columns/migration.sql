-- Add progress tracking columns to tasks table
ALTER TABLE "tasks" ADD COLUMN IF NOT EXISTS "progress" INTEGER;
ALTER TABLE "tasks" ADD COLUMN IF NOT EXISTS "progress_message" TEXT;
