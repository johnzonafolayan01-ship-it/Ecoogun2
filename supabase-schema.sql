-- EcoVoice Ogun Database Schema
-- Run this SQL in your Supabase SQL Editor at https://supabase.com/dashboard

-- Create ENUM types (skip if already exist)
DO $$ BEGIN
  CREATE TYPE report_category AS ENUM ('Waste', 'Flood', 'Pothole');
EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN
  CREATE TYPE report_status AS ENUM ('Pending', 'Agency Notified', 'Resolved');
EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN
  CREATE TYPE report_source AS ENUM ('Web', 'Voice AI');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- Create reports table
CREATE TABLE IF NOT EXISTS reports (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at   TIMESTAMPTZ DEFAULT now() NOT NULL,
  category     TEXT NOT NULL,
  description  TEXT NOT NULL DEFAULT '',
  latitude     FLOAT,
  longitude    FLOAT,
  image_url    TEXT,
  status       TEXT DEFAULT 'Pending' NOT NULL,
  source       TEXT DEFAULT 'Web' NOT NULL,
  phone_number TEXT,          -- caller ID from Voice AI reports
  admin_notes  TEXT           -- internal notes from agency staff
);

-- ── Migrations for existing databases ────────────────────────────────────
ALTER TABLE reports ADD COLUMN IF NOT EXISTS phone_number TEXT;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS admin_notes  TEXT;

-- ── Row Level Security ────────────────────────────────────────────────────
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- Allow anyone to read reports (public heatmap + agency dashboard)
CREATE POLICY IF NOT EXISTS "reports_select_public"
  ON reports FOR SELECT USING (true);

-- Allow anyone to insert reports (anonymous web + voice AI)
CREATE POLICY IF NOT EXISTS "reports_insert_public"
  ON reports FOR INSERT WITH CHECK (true);

-- Allow authenticated users (agency staff & admins) AND service role to update
CREATE POLICY IF NOT EXISTS "reports_update_authed"
  ON reports FOR UPDATE
  USING (auth.role() IN ('authenticated', 'service_role'));

-- Allow authenticated users with an admin email to delete
CREATE POLICY IF NOT EXISTS "reports_delete_admin"
  ON reports FOR DELETE 
  USING (auth.role() = 'authenticated' AND auth.email() = 'admin@ecovgg.ng');

-- ── Storage bucket for report images ─────────────────────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('report-images', 'report-images', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY IF NOT EXISTS "report_images_upload"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'report-images');

CREATE POLICY IF NOT EXISTS "report_images_select"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'report-images');

