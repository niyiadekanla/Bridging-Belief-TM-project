-- Bridging Beliefs Baseline Survey — SQL Transformation Script
-- Run via Claude SQLite MCP: copy entire script into Claude chat
-- This creates clean analytics tables from raw Qualtrics data

-- ============================================================================
-- 1. MAIN ANALYTICS TABLE (unpacks raw_json into individual columns)
-- ============================================================================

CREATE TABLE IF NOT EXISTS qualtrics_analytics (
    id                      INTEGER PRIMARY KEY AUTOINCREMENT,
    response_id             TEXT UNIQUE,
    survey_name             TEXT,
    start_date              TEXT,
    end_date                TEXT,
    duration_seconds        INTEGER,
    finished                INTEGER,
    
    -- Section A: Demographics (Q1-Q10)
    q1_consent              TEXT,
    q2_age                  INTEGER,
    q3_influencer           TEXT,
    q4_gender               TEXT,
    q5_relationship         TEXT,
    q6_pregnant_bf          TEXT,
    q7_num_children         INTEGER,
    q8_age_youngest         INTEGER,
    q9_religion             TEXT,
    q10_education           TEXT,
    
    -- Section B: Gender Roles (Q11-Q16) - Likert 1-5
    q11_personal_hh         REAL,
    q12_social_hh           REAL,
    q13_social_media_equal  REAL,
    q14_personal_men_chores REAL,
    q15_social_men_chores   REAL,
    q16_social_media_men    REAL,
    
    -- Section C: Violence (Q17-Q22)
    q17_social_force        REAL,
    q19_personal_force      REAL,
    q22_advise_friend       REAL,
    
    -- Section D: Family Planning (Q23-Q39)
    q23_fp_favor            REAL,
    q24_fp_advantages       TEXT,
    q25_social_fp_use       REAL,
    q26_social_media_fp     REAL,
    q27_social_fp_pressure  REAL,
    q28_social_men_fp       REAL,
    q29_personal_men_fp     REAL,
    q30_religion_fp         REAL,
    q31_currently_using_fp  TEXT,
    q32_fp_method           TEXT,
    q33a_intend_fp_12mo     TEXT,
    q33b_intend_fp_birth    TEXT,
    q33c_duration_fp        TEXT,
    q34_discussed_fp_partner TEXT,
    q35_discussed_fp_social TEXT,
    q36_fp_decision_maker   TEXT,
    q37_fp_autonomy         REAL,
    q38_fp_satisfaction     REAL,
    q39_sought_fp_info      TEXT,
    
    -- Section E: Media (Q40-Q43)
    q40_social_media_freq   TEXT,
    q41_seen_fp_content     TEXT,
    q42_seen_violence_content TEXT,
    q43_agree_followup      TEXT,
    
    transformed_at          DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 2. RESPONSE COMPLETION SUMMARY (for dashboard metrics)
-- ============================================================================

CREATE TABLE IF NOT EXISTS response_summary (
    date_collected      DATE PRIMARY KEY,
    total_responses     INTEGER,
    completed           INTEGER,
    completion_rate     REAL,
    avg_duration_sec    REAL,
    median_duration_sec REAL,
    created_at          DATETIME DEFAULT CURRENT_TIMESTAMP
);

INSERT OR REPLACE INTO response_summary 
SELECT
    DATE(start_date) as date_collected,
    COUNT(*) as total_responses,
    SUM(CASE WHEN finished=1 THEN 1 ELSE 0 END) as completed,
    ROUND(100.0 * SUM(CASE WHEN finished=1 THEN 1 ELSE 0 END) / COUNT(*), 2) as completion_rate,
    ROUND(AVG(duration_seconds), 0) as avg_duration_sec,
    (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY duration_seconds) FROM qualtrics_responses) as median_duration_sec
FROM qualtrics_responses
WHERE start_date IS NOT NULL
GROUP BY DATE(start_date);

-- ============================================================================
-- 3. DEMOGRAPHIC PROFILE (for baseline characteristics)
-- ============================================================================

CREATE TABLE IF NOT EXISTS demographic_profile (
    characteristic      TEXT,
    category            TEXT,
    count               INTEGER,
    percentage          REAL,
    created_at          DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Age distribution
INSERT OR REPLACE INTO demographic_profile
SELECT 
    'Age Group' as characteristic,
    CASE 
        WHEN q2_age < 20 THEN '< 20'
        WHEN q2_age BETWEEN 20 AND 25 THEN '20-25'
        WHEN q2_age BETWEEN 26 AND 30 THEN '26-30'
        WHEN q2_age BETWEEN 31 AND 35 THEN '31-35'
        WHEN q2_age > 35 THEN '> 35'
        ELSE 'Unknown'
    END as category,
    COUNT(*) as count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM qualtrics_analytics WHERE q2_age IS NOT NULL), 2) as percentage
FROM qualtrics_analytics
WHERE q2_age IS NOT NULL
GROUP BY category;

-- Gender distribution
INSERT OR REPLACE INTO demographic_profile
SELECT 
    'Gender' as characteristic,
    COALESCE(q4_gender, 'Unknown') as category,
    COUNT(*) as count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM qualtrics_analytics WHERE q4_gender IS NOT NULL), 2) as percentage
FROM qualtrics_analytics
WHERE q4_gender IS NOT NULL
GROUP BY q4_gender;

-- Education distribution
INSERT OR REPLACE INTO demographic_profile
SELECT 
    'Education' as characteristic,
    COALESCE(q10_education, 'Unknown') as category,
    COUNT(*) as count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM qualtrics_analytics WHERE q10_education IS NOT NULL), 2) as percentage
FROM qualtrics_analytics
WHERE q10_education IS NOT NULL
GROUP BY q10_education;

-- ============================================================================
-- 4. CONSTRUCT SCALES (Composite scores for multi-item scales)
-- ============================================================================

CREATE TABLE IF NOT EXISTS construct_scores (
    response_id             TEXT PRIMARY KEY,
    gender_role_attitudes   REAL,      -- Average of Q11-Q16 (6 items)
    violence_attitudes      REAL,      -- Average of Q17, Q19, Q22 (3 items)
    fp_approval             REAL,      -- Average of Q23, Q25, Q26, Q28, Q29 (5 items)
    fp_autonomy             REAL,      -- Q37 single item
    created_at              DATETIME DEFAULT CURRENT_TIMESTAMP
);

INSERT OR IGNORE INTO construct_scores
SELECT
    response_id,
    -- Gender role attitudes (higher = more egalitarian)
    ROUND((COALESCE(q11_personal_hh,0) + COALESCE(q12_social_hh,0) + 
           COALESCE(q13_social_media_equal,0) + COALESCE(q14_personal_men_chores,0) + 
           COALESCE(q15_social_men_chores,0) + COALESCE(q16_social_media_men,0)) / 6.0, 2) as gender_role_attitudes,
    -- Violence attitudes (higher = less accepting of violence)
    ROUND((COALESCE(q17_social_force,0) + COALESCE(q19_personal_force,0) + 
           COALESCE(q22_advise_friend,0)) / 3.0, 2) as violence_attitudes,
    -- FP approval (higher = more favorable)
    ROUND((COALESCE(q23_fp_favor,0) + COALESCE(q25_social_fp_use,0) + 
           COALESCE(q26_social_media_fp,0) + COALESCE(q28_social_men_fp,0) + 
           COALESCE(q29_personal_men_fp,0)) / 5.0, 2) as fp_approval,
    -- FP autonomy (single item)
    q37_fp_autonomy
FROM qualtrics_analytics;

-- ============================================================================
-- 5. DATA QUALITY CHECKS
-- ============================================================================

CREATE TABLE IF NOT EXISTS data_quality_report (
    metric              TEXT,
    value               TEXT,
    created_at          DATETIME DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO data_quality_report
SELECT 'Total Responses', COUNT(*) FROM qualtrics_analytics
UNION ALL
SELECT 'Completed Responses', SUM(CASE WHEN finished=1 THEN 1 ELSE 0 END) FROM qualtrics_analytics
UNION ALL
SELECT 'Missing Age Values', SUM(CASE WHEN q2_age IS NULL THEN 1 ELSE 0 END) FROM qualtrics_analytics
UNION ALL
SELECT 'Missing Gender Values', SUM(CASE WHEN q4_gender IS NULL THEN 1 ELSE 0 END) FROM qualtrics_analytics
UNION ALL
SELECT 'Using FP Currently', SUM(CASE WHEN q31_currently_using_fp='Yes' THEN 1 ELSE 0 END) FROM qualtrics_analytics
UNION ALL
SELECT 'Mean Age', ROUND(AVG(q2_age), 1) FROM qualtrics_analytics
UNION ALL
SELECT 'Mean Duration (sec)', ROUND(AVG(duration_seconds), 0) FROM qualtrics_analytics;

-- ============================================================================
-- 6. VIEWS FOR POWER BI (easier to refresh)
-- ============================================================================

CREATE VIEW IF NOT EXISTS vw_respondent_summary AS
SELECT
    response_id,
    survey_name,
    DATE(start_date) as survey_date,
    duration_seconds,
    finished,
    q2_age,
    q4_gender,
    q10_education,
    q31_currently_using_fp,
    q37_fp_autonomy
FROM qualtrics_analytics
ORDER BY start_date DESC;

CREATE VIEW IF NOT EXISTS vw_scale_results AS
SELECT
    cs.response_id,
    qa.q2_age,
    qa.q4_gender,
    qa.q10_education,
    cs.gender_role_attitudes,
    cs.violence_attitudes,
    cs.fp_approval,
    cs.fp_autonomy
FROM construct_scores cs
LEFT JOIN qualtrics_analytics qa ON cs.response_id = qa.response_id;

-- ============================================================================
-- Verify tables created
-- ============================================================================

SELECT 'Setup complete! Tables created:' as status
UNION ALL
SELECT '  - qualtrics_analytics' 
UNION ALL
SELECT '  - response_summary'
UNION ALL
SELECT '  - demographic_profile'
UNION ALL
SELECT '  - construct_scores'
UNION ALL
SELECT '  - data_quality_report'
UNION ALL
SELECT '  - vw_respondent_summary (view)'
UNION ALL
SELECT '  - vw_scale_results (view)';
