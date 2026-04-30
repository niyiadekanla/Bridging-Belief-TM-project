"""
Qualtrics Data Transformation Script
Unpacks raw_json into individual question columns and creates analytics tables
Run manually: python transform_qualtrics_data.py

This script:
- Reads raw survey responses from qualtrics_responses table
- Parses JSON to extract individual question answers
- Creates clean analytics tables for Power BI
- Keeps raw data intact for audit trail
"""

import sqlite3
import json
import pandas as pd
import os
from datetime import datetime

DB_PATH = os.path.join(os.path.expanduser("~"), "Desktop", "Database", "Bildatabase.db")

def transform_json_to_columns(conn):
    """Extract JSON fields from raw_json and create analytics table."""
    print("\n📊 Transforming Qualtrics data...")
    
    cursor = conn.cursor()
    
    # Create analytics table with 43 question columns
    cursor.execute("""
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
            
            -- Section B: Gender Roles (Q11-Q16)
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
        )
    """)
    
    # Read raw data and transform
    cursor.execute("SELECT response_id, raw_json FROM qualtrics_responses WHERE response_id IS NOT NULL")
    rows = cursor.fetchall()
    
    transformed = 0
    errors = 0
    
    for response_id, raw_json_str in rows:
        try:
            data = json.loads(raw_json_str)
            
            # Check if already transformed
            exists = cursor.execute(
                "SELECT 1 FROM qualtrics_analytics WHERE response_id=?",
                (response_id,)
            ).fetchone()
            if exists:
                continue
            
            # Safe getter for any data type
            def safe_get(key, dtype=str):
                val = data.get(key)
                if val is None:
                    return None
                if isinstance(val, float) and pd.isna(val):
                    return None
                if dtype == int:
                    try:
                        return int(val)
                    except:
                        return None
                elif dtype == float:
                    try:
                        return float(val)
                    except:
                        return None
                return str(val) if val else None
            
            cursor.execute("""
                INSERT OR IGNORE INTO qualtrics_analytics (
                    response_id, survey_name, start_date, end_date,
                    duration_seconds, finished,
                    q1_consent, q2_age, q3_influencer, q4_gender,
                    q5_relationship, q6_pregnant_bf, q7_num_children,
                    q8_age_youngest, q9_religion, q10_education,
                    q11_personal_hh, q12_social_hh, q13_social_media_equal,
                    q14_personal_men_chores, q15_social_men_chores,
                    q16_social_media_men,
                    q17_social_force, q19_personal_force, q22_advise_friend,
                    q23_fp_favor, q24_fp_advantages, q25_social_fp_use,
                    q26_social_media_fp, q27_social_fp_pressure,
                    q28_social_men_fp, q29_personal_men_fp,
                    q30_religion_fp, q31_currently_using_fp, q32_fp_method,
                    q33a_intend_fp_12mo, q33b_intend_fp_birth,
                    q33c_duration_fp, q34_discussed_fp_partner,
                    q35_discussed_fp_social, q36_fp_decision_maker,
                    q37_fp_autonomy, q38_fp_satisfaction, q39_sought_fp_info,
                    q40_social_media_freq, q41_seen_fp_content,
                    q42_seen_violence_content, q43_agree_followup
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            """, (
                response_id,
                safe_get("survey_name"),
                safe_get("StartDate"),
                safe_get("EndDate"),
                safe_get("Duration (in seconds)", int),
                1 if safe_get("Finished") == "True" else 0,
                # Demographics
                safe_get("Q1"), safe_get("Q2", int), safe_get("Q3"),
                safe_get("Q4"), safe_get("Q5"), safe_get("Q6"),
                safe_get("Q7", int), safe_get("Q8", int), safe_get("Q9"),
                safe_get("Q10"),
                # Gender Roles
                safe_get("Q11", float), safe_get("Q12", float),
                safe_get("Q13", float), safe_get("Q14", float),
                safe_get("Q15", float), safe_get("Q16", float),
                # Violence
                safe_get("Q17", float), safe_get("Q19", float),
                safe_get("Q22", float),
                # Family Planning
                safe_get("Q23", float), safe_get("Q24"), safe_get("Q25", float),
                safe_get("Q26", float), safe_get("Q27", float),
                safe_get("Q28", float), safe_get("Q29", float),
                safe_get("Q30", float), safe_get("Q31"), safe_get("Q32"),
                safe_get("Q33a"), safe_get("Q33b"), safe_get("Q33c"),
                safe_get("Q34"), safe_get("Q35"), safe_get("Q36"),
                safe_get("Q37", float), safe_get("Q38", float), safe_get("Q39"),
                # Media
                safe_get("Q40"), safe_get("Q41"), safe_get("Q42"),
                safe_get("Q43")
            ))
            transformed += 1
        except json.JSONDecodeError:
            errors += 1
        except Exception as e:
            errors += 1

    conn.commit()
    print(f"✅ Transformed {transformed} rows | Errors: {errors}")
    return transformed

def create_summary_tables(conn):
    """Create summary/aggregation tables for dashboards."""
    print("\n📈 Creating summary tables...")
    
    cursor = conn.cursor()
    
    # Response completeness summary
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS response_summary (
            date_collected      DATE,
            total_responses     INTEGER,
            completed           INTEGER,
            completion_rate     REAL,
            avg_duration_sec    REAL,
            created_at          DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    # Insert today's summary
    cursor.execute("""
        INSERT OR REPLACE INTO response_summary 
        (date_collected, total_responses, completed, completion_rate, avg_duration_sec)
        SELECT
            DATE(start_date),
            COUNT(*),
            SUM(finished),
            ROUND(100.0 * SUM(finished) / COUNT(*), 2),
            ROUND(AVG(duration_seconds), 0)
        FROM qualtrics_analytics
        GROUP BY DATE(start_date)
    """)
    
    conn.commit()
    print("✅ Summary tables created")

def main():
    print("=" * 60)
    print("  Qualtrics Data Transformation")
    print("  " + datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    print("=" * 60)
    
    if not os.path.exists(DB_PATH):
        print(f"❌ Database not found: {DB_PATH}")
        return
    
    conn = sqlite3.connect(DB_PATH)
    
    try:
        transformed = transform_json_to_columns(conn)
        create_summary_tables(conn)
        
        print("\n" + "=" * 60)
        print(f"✅ Complete! {transformed} records ready for Power BI")
        print("=" * 60)
    finally:
        conn.close()

if __name__ == "__main__":
    main()
