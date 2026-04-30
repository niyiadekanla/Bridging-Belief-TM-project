# Bridging Beliefs Survey Automation Pipeline

**End-to-end Qualtrics → SQLite → Power BI → Claude MCP Analytics Workflow**

Fully automated data collection, transformation, and analysis pipeline for baseline survey research with real-time dashboarding and AI-powered insights via Claude.

---

## 🎯 What This Does

```
Qualtrics Survey (online)
        ↓ [auto every 30 min]
Qualtrics API
        ↓
SQLite Database
        ↓ [real-time]
Power BI Dashboard
        ↓ [queries via MCP]
Claude AI Analysis
```

- **Survey Collection**: Automated Qualtrics API pulls every 30 minutes
- **Data Storage**: Clean SQLite database with deduplication
- **Live Dashboard**: Power BI DirectQuery for real-time visuals
- **Smart Analysis**: Claude via MCP runs statistical tests and interprets results
- **Audit Trail**: All raw data preserved in JSON format

---

## ⚡ Quick Start (5 minutes)

### 1. Clone this repo
```bash
git clone https://github.com/yourusername/bridging-beliefs-survey.git
cd bridging-beliefs-survey
```

### 2. Install dependencies
```powershell
pip install -r requirements.txt
```

### 3. Set up environment variables
```powershell
[System.Environment]::SetEnvironmentVariable("QUALTRICS_API_TOKEN","your_token_here","User")
[System.Environment]::SetEnvironmentVariable("QUALTRICS_DATA_CENTER","eu","User")
[System.Environment]::SetEnvironmentVariable("QUALTRICS_SURVEY_ID","SV_xxxxx","User")
```

Then **close and reopen PowerShell**.

### 4. Run initial setup
```powershell
cd scripts
python setup_database.py
python qualtrics_to_sqlite.py
```

### 5. Open Power BI
- File → Open → `reports/Bridging_Beliefs_Dashboard.pbix`
- Click **Refresh** to load your first data
- Dashboard auto-updates every 30 minutes (via scheduler)

### 6. Connect Claude (optional but recommended)
```powershell
cd ../mcp
# Your SQLite MCP is already configured in Claude Desktop
# Open Claude → ask: "Summarize responses from qualtrics_analytics table"
```

---

## 📁 Project Structure

```
bridging-beliefs-survey/
├── README.md (this file)
├── requirements.txt
├── .env.example
│
├── scripts/
│   ├── setup_database.py           # Initialize SQLite schema (run once)
│   ├── qualtrics_to_sqlite.py      # API pull → SQLite (run manually or via scheduler)
│   ├── transform_qualtrics_data.py # JSON unpacking → analytics tables
│   └── schedule_loader.bat         # Windows Task Scheduler config
│
├── sql/
│   ├── schema.sql                  # Initial table structure
│   ├── transform_qualtrics_analytics.sql  # Clean data & create views
│   └── statistical_tests.sql       # Reliabilty, validity checks (run in Claude)
│
├── reports/
│   └── Bridging_Beliefs_Dashboard.pbix  # Power BI file (Power BI Desktop)
│
├── mcp/
│   ├── claude_desktop_config.json  # MCP server configuration
│   └── sample_claude_prompts.txt   # Example questions to ask Claude
│
├── docs/
│   ├── SETUP.md                    # Detailed installation guide
│   ├── API_CREDENTIALS.md          # How to get Qualtrics API keys
│   ├── TROUBLESHOOTING.md          # Common errors & fixes
│   └── CLAUDE_MCP_USAGE.md         # How to query data via Claude
│
└── logs/
    └── import_log.csv              # History of all data imports
```

---

## 🚀 Full Automation Setup

### Windows Task Scheduler (Auto-sync every 30 minutes)

1. **Open Task Scheduler** (Win + S → search)
2. **Create Basic Task** → name: `Qualtrics SQLite Auto-Loader`
3. **Trigger**: Daily, repeat every 30 minutes
4. **Action**: Start program
   - Program: `python`
   - Arguments: `"C:\path\to\scripts\qualtrics_to_sqlite.py"`
   - Start in: `C:\path\to\scripts`

**Or** run the batch file:
```powershell
.\scripts\schedule_loader.bat
```

---

## 📊 Power BI Setup

### Connect SQLite via ODBC

1. **Install SQLite ODBC Driver** (if not done):
   - Download: http://www.ch-werner.de/sqliteodbc/
   - Run installer, check "64-bit"

2. **Create ODBC DSN**:
   - Win + S → ODBC Data Sources (64-bit)
   - User DSN tab → Add
   - Driver: SQLite3 ODBC Driver
   - Data Source Name: `Bildatabase`
   - Database: `C:\path\to\Bildatabase.db`

3. **Load into Power BI**:
   - Home → Get Data → ODBC
   - Select `Bildatabase` → Load
   - Check: `qualtrics_responses` table loads

4. **Refresh Data**:
   - Home → Refresh (syncs with latest SQLite data)

### Optional: Enable Auto-Refresh
- Format pane → Page refresh → On → 30 minutes

---

## 🤖 Claude MCP Integration

### Prerequisites
- Claude Desktop installed
- SQLite MCP server configured

### Query your data via Claude

In Claude.ai, ask:
```
"How many survey respondents completed the baseline?"
```

Claude will:
1. Connect to your SQLite database via MCP
2. Write the SQL query
3. Return formatted results
4. Answer follow-up questions

### Example analyses Claude can run:

- **Descriptive stats**: "Show me age distribution"
- **Cross-tabs**: "Gender vs. family planning approval"
- **Scales**: "Calculate construct reliability (Cronbach's alpha) for gender role items"
- **Comparisons**: "Compare personal vs. social norms on FP approval"
- **Anomalies**: "Flag any outliers in response patterns"

See `docs/CLAUDE_MCP_USAGE.md` for detailed examples.

---

## 🧹 Data Transformation

### Step 1: Transform Raw JSON to Columns

Run the Python script:
```powershell
python scripts/transform_qualtrics_data.py
```

This:
- Reads `qualtrics_responses` (raw Qualtrics export)
- Parses `raw_json` field
- Creates `qualtrics_analytics` table with 43 question columns
- Keeps raw data as backup

### Step 2: Create Analytics Tables (Optional)

Ask Claude to run the SQL transformation:
```
Copy this SQL into Claude and run it on my SQLite database:
[paste sql/transform_qualtrics_analytics.sql]
```

This creates:
- `qualtrics_analytics` — clean, tidy data
- `response_summary` — completion rates, durations
- `demographic_profile` — age, gender, education distributions
- `construct_scores` — composite scales (gender roles, violence, FP)
- `vw_respondent_summary` — easy Power BI view
- `vw_scale_results` — scale scores by demographics

---

## 📈 Statistical Analysis

### Reliability Tests (Cronbach's Alpha)

Ask Claude:
```
"Calculate Cronbach's alpha for the gender role items (Q11-Q16)
and the violence acceptance items (Q17, Q19, Q22).
Return both raw alpha and alpha if item deleted."
```

Claude will:
1. Fetch the data
2. Calculate correlations
3. Compute alpha
4. Flag problematic items

### Validity Tests

- **Convergent validity**: Gender roles scale vs. self-report egalitarian beliefs
- **Discriminant validity**: Gender roles vs. FP approval (should differ)
- **Known-groups validity**: Influencers vs. non-influencers (should differ on social norms)

### Approach Comparison

If you have two survey versions:
```
"Compare completion rates, response distributions, and scale 
reliability between the two survey approaches. Which is better?"
```

---

## 🔐 Security

### API Credentials
- **Never** commit `.env` files with real credentials
- Use environment variables (see Quick Start step 3)
- Regenerate API token if exposed

### Database
- SQLite file stored locally (no cloud exposure)
- Raw JSON kept for audit trail
- All imports logged with timestamp and source

### Power BI
- DirectQuery mode recommended (queries SQLite directly)
- Refresh passwords stored securely in Power BI Service (if publishing)

---

## 🐛 Troubleshooting

### "ODBC: Tables not found"
→ Check ODBC DSN path points to correct `.db` file
→ Run `python check_db.py` to verify tables exist

### "Qualtrics API: 400 Bad Request"
→ Verify Data Center ID (usually `eu`, not your org name)
→ Check API token hasn't expired

### "Power BI: Refresh failed"
→ Verify ODBC driver is 64-bit (Power BI is 64-bit)
→ Try importing instead of DirectQuery first

See `docs/TROUBLESHOOTING.md` for more.

---

## 📚 Documentation

- **SETUP.md** — Step-by-step installation
- **API_CREDENTIALS.md** — How to find your Qualtrics keys
- **CLAUDE_MCP_USAGE.md** — Query examples and prompts
- **TROUBLESHOOTING.md** — Common issues & fixes

---

## 🔄 Typical Workflow

**Day 1**: Setup
1. Clone repo, install, set credentials
2. Run `setup_database.py`
3. Pull initial data with `qualtrics_to_sqlite.py`
4. Load into Power BI
5. Open in Claude, ask: "How many responses so far?"

**Daily** (automatic):
- 8:00 AM: Task Scheduler runs auto-sync
- Power BI dashboard updates on next refresh
- You see new data in Claude when queried

**Weekly**:
- Review Power BI dashboard
- Ask Claude: "Any changes in response patterns?"
- Check data quality report

**End of study**:
- Ask Claude: "Generate final analysis report"
- Export Power BI visuals
- Archive SQLite database

---

## 📝 Requirements

- Python 3.10+
- Windows 10+ (Task Scheduler)
- Power BI Desktop (free or Pro)
- Claude Desktop with MCP SQLite server connected
- Qualtrics account (any plan with API access)

---

## 🤝 Contributing

Found a bug? Have a feature idea?
1. Fork the repo
2. Create a branch: `git checkout -b feature/your-feature`
3. Commit: `git commit -m "Add feature"`
4. Push: `git push origin feature/your-feature`
5. Open a Pull Request

---

## 📄 License

MIT License - Use freely for research and non-commercial purposes

---

## 👤 Author

Built for Bridging Beliefs research project  
Questions? See `docs/TROUBLESHOOTING.md` or email niyiadekanla@gmail.com.

---

## 📞 Support

- **Claude MCP issues** → Check `docs/CLAUDE_MCP_USAGE.md`
- **Power BI issues** → See `docs/TROUBLESHOOTING.md`
- **Qualtrics API issues** → See `docs/API_CREDENTIALS.md`
- **General setup** → Follow `docs/SETUP.md` step-by-step

Happy surveying! 🎯
