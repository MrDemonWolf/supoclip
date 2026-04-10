-- Migration: add_missing_models_and_columns
-- Safe for existing databases: uses IF NOT EXISTS / ADD COLUMN IF NOT EXISTS

-- Add missing columns to sources
ALTER TABLE "sources" ADD COLUMN IF NOT EXISTS "url" VARCHAR(1000);

-- Add missing columns to tasks
ALTER TABLE "tasks" ADD COLUMN IF NOT EXISTS "caption_template" VARCHAR(50) DEFAULT 'default';
ALTER TABLE "tasks" ADD COLUMN IF NOT EXISTS "include_broll" BOOLEAN DEFAULT false;
ALTER TABLE "tasks" ADD COLUMN IF NOT EXISTS "processing_mode" VARCHAR(20) NOT NULL DEFAULT 'fast';
ALTER TABLE "tasks" ADD COLUMN IF NOT EXISTS "started_at" TIMESTAMPTZ;
ALTER TABLE "tasks" ADD COLUMN IF NOT EXISTS "completed_at" TIMESTAMPTZ;
ALTER TABLE "tasks" ADD COLUMN IF NOT EXISTS "cache_hit" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "tasks" ADD COLUMN IF NOT EXISTS "error_code" VARCHAR(80);
ALTER TABLE "tasks" ADD COLUMN IF NOT EXISTS "stage_timings_json" TEXT;

-- Update font defaults from TikTokSans-Regular to Roboto
ALTER TABLE "tasks" ALTER COLUMN "font_family" SET DEFAULT 'Roboto';
ALTER TABLE "users" ALTER COLUMN "default_font_family" SET DEFAULT 'Roboto';

-- Add type check constraint to sources if not exists
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'check_source_type'
  ) THEN
    ALTER TABLE "sources" ADD CONSTRAINT "check_source_type"
      CHECK (type IN ('youtube', 'twitch', 'video_url'));
  END IF;
END $$;

-- Create generated_clips table
CREATE TABLE IF NOT EXISTS "generated_clips" (
    "id" VARCHAR(36) NOT NULL,
    "task_id" VARCHAR(36) NOT NULL,
    "filename" VARCHAR(255) NOT NULL,
    "file_path" VARCHAR(500) NOT NULL,
    "start_time" VARCHAR(20) NOT NULL,
    "end_time" VARCHAR(20) NOT NULL,
    "duration" DOUBLE PRECISION NOT NULL,
    "text" TEXT,
    "relevance_score" DOUBLE PRECISION NOT NULL,
    "reasoning" TEXT,
    "clip_order" INTEGER NOT NULL,
    "virality_score" INTEGER DEFAULT 0,
    "hook_score" INTEGER DEFAULT 0,
    "engagement_score" INTEGER DEFAULT 0,
    "value_score" INTEGER DEFAULT 0,
    "shareability_score" INTEGER DEFAULT 0,
    "hook_type" VARCHAR(50),
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "generated_clips_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "generated_clips_task_id_fkey" FOREIGN KEY ("task_id")
        REFERENCES "tasks"("id") ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS "generated_clips_task_id_idx" ON "generated_clips"("task_id");
CREATE INDEX IF NOT EXISTS "generated_clips_clip_order_idx" ON "generated_clips"("clip_order");
CREATE INDEX IF NOT EXISTS "generated_clips_created_at_idx" ON "generated_clips"("created_at");

-- Create processing_cache table
CREATE TABLE IF NOT EXISTS "processing_cache" (
    "cache_key" VARCHAR(255) NOT NULL,
    "source_url" TEXT NOT NULL,
    "source_type" VARCHAR(20) NOT NULL,
    "video_path" TEXT,
    "transcript_text" TEXT,
    "analysis_json" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "processing_cache_pkey" PRIMARY KEY ("cache_key")
);

CREATE INDEX IF NOT EXISTS "processing_cache_source_url_idx" ON "processing_cache"("source_url");

-- Updated_at trigger for generated_clips
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_generated_clips_updated_at ON "generated_clips";
CREATE TRIGGER update_generated_clips_updated_at
    BEFORE UPDATE ON "generated_clips"
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_processing_cache_updated_at ON "processing_cache";
CREATE TRIGGER update_processing_cache_updated_at
    BEFORE UPDATE ON "processing_cache"
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
