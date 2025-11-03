# Version Quick Reference Card

**Quick access guide for versioning in future sessions**

---

## 🎯 Current Project Version: 2.0.0

**Release Date:** 2025-10-31
**Status:** Production-ready
**Major Feature:** Dual-dataset support (Taxi + TNP trips)

---

## 📚 Key Documentation & Versions

| Document | Version | Purpose | Start Here If... |
|----------|---------|---------|------------------|
| **START_HERE.md** | 2.0.0 | Quick deployment | You want to deploy ASAP |
| **DEPLOYMENT_GUIDE.md** | 2.0.0 | Complete guide | You want step-by-step instructions |
| **README.md** | 2.0 | Architecture | You want to understand the system |
| **CHANGELOG.md** | 2.0.0 | What changed | You want to know what's new |
| **DOC_INDEX.md** | 2.0.0 | All docs | You're looking for specific info |
| **VERSIONS.md** | 1.0.0 | Standards | You're contributing documentation |

---

## 🔢 Version Format

```
MAJOR.MINOR.PATCH

2  .  0  .  1
│     │     │
│     │     └─ Bug fixes, typos
│     └─────── New features (compatible)
└───────────── Breaking changes, new datasets
```

---

## 🚀 What's in Version 2.0.0?

### Added
✅ **TNP Trips Extractor** (m6dm-c72p) - Rideshare data
✅ **BigQuery Table** `raw_tnp_trips` - Storage for TNP trips
✅ **Dual-dataset Backfill** - Process taxi + TNP simultaneously
✅ **Complete Documentation** - Updated all guides for v2.0

### Changed
📝 Cost estimates updated ($1.50 → $3-4 for dual datasets)
📝 Time estimates updated (60 min → 90-120 min)
📝 Partitions count (90 → 180 for both datasets)

### Technical Details
- **Datasets:** Taxi (wrvz-psew) + TNP (m6dm-c72p)
- **Storage:** ~15-20 GB total (Q1 2020)
- **Records:** ~15-20 million trips
- **Compatibility:** Backward compatible with v1.0

---

## 📂 Quick File Finder

### "Where do I start?"
→ `START_HERE.md` (v2.0.0)

### "How do I deploy?"
→ `DEPLOYMENT_GUIDE.md` (v2.0.0)

### "What's the architecture?"
→ `README.md` (v2.0)

### "What changed recently?"
→ `CHANGELOG.md` (v2.0.0)

### "Where are all the docs?"
→ `DOC_INDEX.md` (v2.0.0)

### "How does versioning work?"
→ `VERSIONS.md` (v1.0.0)

---

## 🔍 Finding Information Across Sessions

### Session Context Template

When starting a new session, provide this context:

```
Project: Chicago BI App - MSDS 432
Current Version: 2.0.0
Last Session Date: [DATE]
Current Phase: [Phase description]

Quick Context:
- Dual-dataset architecture (Taxi + TNP trips)
- Q1 2020 historical backfill ready
- Both extractors deployed and tested

Current Status:
- ✅ Infrastructure set up
- ✅ Extractors deployed (taxi v1.0.0, TNP v2.0.0)
- ✅ BigQuery schemas deployed (v2.0, M003)
- ⏳ Next: [Your current task]

Reference:
- See CHANGELOG.md for recent changes
- See DOC_INDEX.md for all documentation
- Project version: 2.0.0
```

### Quick Status Check

```bash
# Check deployed versions
gcloud run jobs list --project=chicago-bi-app-msds-432-476520

# Check schemas
bq ls chicago-bi-app-msds-432-476520:raw_data

# View version info
head -20 README.md
head -20 DEPLOYMENT_GUIDE.md
```

---

## 🗂️ Version History at a Glance

| Version | Date | Key Feature | Impact |
|---------|------|-------------|--------|
| **2.0.0** | 2025-10-31 | TNP trips support | Major - New dataset |
| 1.0.0 | 2025-10-30 | Initial setup | Major - First release |

**Next Planned:** v2.1.0 - Silver layer transformations

---

## 📋 Component Versions

### Extractors
- `extractor-taxi`: v1.0.0 (wrvz-psew dataset)
- `extractor-tnp`: v2.0.0 (m6dm-c72p dataset)

### Schemas
- `bronze_layer.sql`: v2.0 (Migration 003)
- Tables: raw_taxi_trips, raw_tnp_trips

### Scripts
- `deploy_schemas.sh`: v2.0.0
- `quarterly_backfill_q1_2020.sh`: v1.1.0 (supports both datasets)

### Infrastructure
- GCP Project: `chicago-bi-app-msds-432-476520`
- Region: `us-central1`
- Datasets: raw_data, cleaned_data, analytics, reference, monitoring

---

## 🎨 Documentation Status Colors

Use these when scanning documents:

- 🟢 **Final** - Approved for use
- 🟡 **Review** - Awaiting feedback
- 🔵 **Draft** - Work in progress
- 🔴 **Deprecated** - Use newer version
- ⚫ **Archived** - Historical only

---

## ⚡ Quick Commands

### Check Current Version
```bash
cd ~/Desktop/chicago-bi-app
head -15 README.md | grep Version
```

### View Recent Changes
```bash
head -50 CHANGELOG.md
```

### List All Documentation
```bash
cat DOC_INDEX.md
```

### Check Schema Version
```bash
head -20 bigquery/schemas/bronze_layer.sql
```

---

## 🔄 When Versions Change

### If MAJOR version changed (e.g., 2.0 → 3.0)
- ⚠️ Breaking changes present
- 📖 Read CHANGELOG.md migration guide
- 🔄 May need to redeploy components
- ✅ Check compatibility matrix in DOC_INDEX.md

### If MINOR version changed (e.g., 2.0 → 2.1)
- ✨ New features available
- ✅ Backward compatible
- 📖 Read CHANGELOG.md for new features
- 🆗 Existing deployments continue working

### If PATCH version changed (e.g., 2.0.0 → 2.0.1)
- 🐛 Bug fixes or typo corrections
- ✅ Fully compatible
- 📝 Optional: Read CHANGELOG.md for details

---

## 📞 Quick Help

### "I'm resuming work, where do I start?"
1. Check current version: `head -15 README.md`
2. Read recent changes: `head -50 CHANGELOG.md`
3. Find your task: `cat DOC_INDEX.md`
4. Follow relevant guide

### "I want to add documentation"
1. Read `VERSIONS.md` for standards
2. Add version header (use templates in VERSIONS.md)
3. Update `DOC_INDEX.md`
4. Update `CHANGELOG.md` if significant
5. Commit with proper message

### "I want to know what's compatible"
→ See compatibility matrix in `DOC_INDEX.md`

### "I need context for a new session"
→ Use the session context template above

---

## 🎯 One-Sentence Summary

**v2.0.0:** Added TNP rideshare trips (m6dm-c72p) alongside taxi trips (wrvz-psew) with complete dual-dataset deployment support.

---

## 📊 File Tree with Versions

```
chicago-bi-app/ (v2.0.0)
├── README.md                          v2.0
├── START_HERE.md                      v2.0.0
├── DEPLOYMENT_GUIDE.md                v2.0.0
├── CHANGELOG.md                       v2.0.0
├── VERSIONS.md                        v1.0.0
├── DOC_INDEX.md                       v2.0.0
├── VERSION_QUICK_REFERENCE.md         v1.0.0 ⬅️ This file
│
├── extractors/
│   ├── taxi/
│   │   ├── main.go                    v1.0.0
│   │   └── deploy_with_auth.sh        v1.0.0
│   └── tnp/
│       ├── main.go                    v2.0.0 (NEW)
│       └── deploy_with_auth.sh        v2.0.0 (NEW)
│
├── bigquery/schemas/
│   ├── bronze_layer.sql               v2.0 (M003)
│   └── deploy_schemas.sh              v2.0.0 (NEW)
│
└── backfill/
    └── quarterly_backfill_q1_2020.sh  v1.1.0
```

---

## 💡 Pro Tips

1. **Always check CHANGELOG.md first** when resuming work
2. **Use DOC_INDEX.md** to find documentation quickly
3. **Include version in session context** for AI assistants
4. **Check compatibility matrix** before updating components
5. **Read version headers** to understand document scope

---

**Last Updated:** 2025-10-31
**Next Review:** Week 2 (2025-11-07)
**Maintained By:** Group 2 - MSDS 432

---

**Northwestern MSDS 432 - Group 2**
