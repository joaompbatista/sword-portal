-- ============================================================
-- Sword Health / Bloom – Schema Alterations v2
-- 1. Remove condition_id from fact_sessions (redundant: already in dim_users)
-- 2. Add FK from fact_program_outcomes.program_end_date to dim_date
-- ============================================================

-- ── 1. Drop condition_id from fact_sessions ───────────────
ALTER TABLE fact_sessions DROP COLUMN condition_id;

-- ── 2. Link fact_program_outcomes.program_end_date to dim_date ─
ALTER TABLE fact_program_outcomes
    ADD CONSTRAINT fk_program_end_date
    FOREIGN KEY (program_end_date) REFERENCES dim_date(date_id);
