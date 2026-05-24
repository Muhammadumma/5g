-- ====================================================
-- Migration: Make phone_primary nullable
-- Run this in your Supabase SQL Editor ONLY if you
-- already applied supabase_schema.sql previously.
-- This removes the NOT NULL constraint so patients
-- can be registered without a phone number.
-- ====================================================

ALTER TABLE patients ALTER COLUMN phone_primary DROP NOT NULL;
