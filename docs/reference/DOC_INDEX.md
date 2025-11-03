# Documentation Index

**Index Version:** 2.0.0
**Last Updated:** 2025-10-31
**Project:** Chicago BI App - MSDS 432

---

## Quick Navigation

- **Getting Started:** [START_HERE.md](#start_heremd) → [DEPLOYMENT_GUIDE.md](#deployment_guidemd)
- **Architecture:** [README.md](#readmemd) → [ARCHITECTURE_GAP_ANALYSIS.md](#architecture_gap_analysismd)
- **Versioning:** [CHANGELOG.md](#changelogmd) → [VERSIONS.md](#versionsmd)
- **Implementation:** [FINAL_IMPLEMENTATION_PLAN.md](#final_implementation_planmd)

---

## Documentation Catalog

### 🚀 Getting Started (Priority 1)

#### START_HERE.md
- **Version:** 2.0.0
- **Type:** Quick Start Guide
- **Status:** Final
- **Purpose:** Primary entry point for Q1 2020 backfill setup
- **Audience:** Developers, team members
- **Prerequisites:** None
- **Estimated Time:** 60-90 minutes (includes backfill)
- **Related:** DEPLOYMENT_GUIDE.md, QUICKSTART_CLOUD_BACKFILL.md

#### DEPLOYMENT_GUIDE.md
- **Version:** 2.0.0
- **Type:** Tutorial/Guide
- **Status:** Final
- **Purpose:** Complete step-by-step deployment for taxi & TNP extractors
- **Audience:** Developers, DevOps
- **Prerequisites:** GCP project, Docker, Socrata credentials
- **Estimated Time:** 90-120 minutes
- **New in v2.0:** TNP trips support, dual-dataset deployment
- **Related:** START_HERE.md, CHANGELOG.md

---

### 📚 Architecture & Design (Priority 2)

#### README.md
- **Version:** 2.0
- **Type:** Architecture Documentation
- **Status:** Final
- **Purpose:** Project overview, architecture, cost analysis
- **Audience:** All stakeholders
- **Prerequisites:** None
- **Key Sections:** Architecture diagram, cost breakdown, technology stack
- **New in v2.0:** Updated to include TNP dataset support
- **Related:** ARCHITECTURE_GAP_ANALYSIS.md

#### ARCHITECTURE_GAP_ANALYSIS.md
- **Version:** 1.0
- **Type:** Architecture Documentation
- **Status:** Final
- **Purpose:** Analysis of original vs. simplified architecture
- **Audience:** Technical leads, architects
- **Prerequisites:** Understanding of data lakehouse concepts
- **Key Decisions:** Removed Cloud SQL, removed Cloud Composer
- **Related:** README.md, FINAL_IMPLEMENTATION_PLAN.md

#### FINAL_IMPLEMENTATION_PLAN.md
- **Version:** 1.1
- **Type:** Planning Document
- **Status:** In Progress
- **Purpose:** Week-by-week implementation plan
- **Audience:** Project team, instructors
- **Prerequisites:** Architecture understanding
- **Current Phase:** Week 1 - Foundation & Setup
- **Related:** UPDATED_WEEK1_PLAN.md

#### UPDATED_WEEK1_PLAN.md
- **Version:** 1.2
- **Type:** Planning Document
- **Status:** In Progress
- **Purpose:** Detailed Week 1 tasks and timeline
- **Audience:** Project team
- **Prerequisites:** FINAL_IMPLEMENTATION_PLAN.md
- **Related:** FINAL_IMPLEMENTATION_PLAN.md

---

### 🛠️ Technical Guides (Priority 2)

#### QUICKSTART_CLOUD_BACKFILL.md
- **Version:** 1.0
- **Type:** Tutorial/Guide
- **Status:** Final
- **Purpose:** Run backfill on Cloud Shell (recommended approach)
- **Audience:** Developers
- **Prerequisites:** Deployed extractors
- **Estimated Time:** 5 minutes setup + 45 minutes execution
- **Related:** DEPLOYMENT_GUIDE.md, START_HERE.md

#### DEPLOY_AUTHENTICATED_EXTRACTOR.md
- **Version:** 1.0
- **Type:** Tutorial/Guide
- **Status:** Final
- **Purpose:** Deploy taxi extractor with authentication
- **Audience:** Developers
- **Prerequisites:** Socrata API credentials in Secret Manager
- **Estimated Time:** 15 minutes
- **Note:** Covers taxi only; see DEPLOYMENT_GUIDE.md v2.0 for TNP
- **Related:** DEPLOYMENT_GUIDE.md

#### SETUP_SUMMARY.md
- **Version:** 1.0
- **Type:** Reference Documentation
- **Status:** Final
- **Purpose:** Summary of completed infrastructure setup
- **Audience:** All team members
- **Prerequisites:** None (informational)
- **Related:** setup_gcp_infrastructure.sh

---

### 📖 Reference Documentation (Priority 3)

#### CHANGELOG.md
- **Version:** 2.0.0
- **Type:** Version History
- **Status:** Maintained
- **Purpose:** Track all project changes by version
- **Audience:** All team members, future maintainers
- **Format:** Keep a Changelog standard
- **Update Frequency:** Every release
- **Related:** VERSIONS.md

#### VERSIONS.md
- **Version:** 1.0.0
- **Type:** Standards Documentation
- **Status:** Final
- **Purpose:** Define versioning standards for project
- **Audience:** All contributors
- **Scope:** Documentation, code, schemas
- **Related:** CHANGELOG.md, DOC_INDEX.md

#### DOC_INDEX.md
- **Version:** 2.0.0
- **Type:** Index/Catalog
- **Status:** Maintained
- **Purpose:** This file - central documentation catalog
- **Audience:** All team members
- **Update Frequency:** When documentation added/updated
- **Related:** All documentation

---

### 🔧 Scripts & Configuration

#### setup_gcp_infrastructure.sh
- **Version:** 1.0.0
- **Type:** Bash Script
- **Status:** Final
- **Purpose:** Automated GCP project setup
- **Estimated Time:** 15-20 minutes
- **Creates:** Buckets, datasets, IAM, secrets
- **Related:** SETUP_SUMMARY.md

#### setup_budget_shutdown.sh
- **Version:** 1.0.0
- **Type:** Bash Script
- **Status:** Final
- **Purpose:** Configure budget alerts and auto-shutdown
- **Estimated Time:** 5 minutes
- **Safety:** Prevents cost overruns
- **Related:** setup_gcp_infrastructure.sh

---

### 📂 Subdirectory Documentation

#### docs/AUTHENTICATION_AND_DATASETS.md
- **Version:** 1.0
- **Type:** Reference/Guide
- **Status:** Final (needs v2.0 update for TNP)
- **Purpose:** Explain SODA API auth and dataset configuration
- **Audience:** Developers adding new datasets
- **Related:** DEPLOY_AUTHENTICATED_EXTRACTOR.md

#### docs/DATA_INGESTION_WORKFLOW.md
- **Version:** 1.0
- **Type:** Technical Documentation
- **Status:** Final
- **Purpose:** End-to-end ingestion workflow explanation
- **Audience:** Technical team
- **Related:** DEPLOYMENT_GUIDE.md

#### docs/SOCRATA_SECRETS_USAGE.md
- **Version:** 1.0
- **Type:** Reference/Guide
- **Status:** Final
- **Purpose:** Using Socrata API credentials with Secret Manager
- **Audience:** Developers
- **Related:** AUTHENTICATION_AND_DATASETS.md

#### docs/RUN_BACKFILL_ON_CLOUD.md
- **Version:** 1.0
- **Type:** Tutorial/Guide
- **Status:** Final
- **Purpose:** Three approaches for running backfill on cloud
- **Audience:** Developers, DevOps
- **Related:** QUICKSTART_CLOUD_BACKFILL.md

#### extractors/taxi/FIX_DOCKER_AUTH_ERROR.md
- **Version:** 1.0
- **Type:** Troubleshooting Guide
- **Status:** Final
- **Purpose:** Resolve Docker authentication issues
- **Audience:** Developers
- **Scope:** Docker, GCR, authentication

#### extractors/taxi/TESTING_GUIDE.md
- **Version:** 1.0
- **Type:** Testing Documentation
- **Status:** Final
- **Purpose:** Test taxi extractor with known good dates
- **Audience:** Developers, QA
- **Related:** test_single_date.sh

#### geospatial/GEOMETRY_VALIDATION_REPORT.md
- **Version:** 1.0
- **Type:** Technical Report
- **Status:** Final
- **Purpose:** Geospatial data validation results
- **Audience:** Data engineers, analysts
- **Related:** GeoPandas scripts

#### backfill/README.md
- **Version:** 1.0
- **Type:** Reference Documentation
- **Status:** Final
- **Purpose:** Explain backfill scripts usage
- **Audience:** Developers
- **Related:** QUICKSTART_CLOUD_BACKFILL.md

---

## Version Compatibility Matrix

| Component | Version | Requires | Compatible With | Notes |
|-----------|---------|----------|-----------------|-------|
| **Project** | 2.0.0 | - | All v2.x components | Current version |
| **DEPLOYMENT_GUIDE.md** | 2.0.0 | bronze_layer.sql v2.0 | Both taxi & TNP | Complete guide |
| **START_HERE.md** | 2.0.0 | DEPLOYMENT_GUIDE v2.0 | Both datasets | Updated for v2.0 |
| **README.md** | 2.0 | - | All components | Architecture |
| **bronze_layer.sql** | 2.0 (M003) | - | extractors v1.0+ | Schema v2.0 |
| **extractor-taxi** | 1.0.0 | bronze_layer v1.0+ | All versions | Backward compatible |
| **extractor-tnp** | 2.0.0 | bronze_layer v2.0+ | v2.0+ only | New in v2.0 |
| **backfill scripts** | 1.1.0 | extractor-taxi v1.0<br>extractor-tnp v2.0 | Both datasets | Already compatible |

---

## Document Status Legend

| Status | Meaning |
|--------|---------|
| **Draft** | Work in progress, not reviewed |
| **Review** | Complete, awaiting peer review |
| **Final** | Reviewed and approved for use |
| **Maintained** | Living document, continuously updated |
| **In Progress** | Actively being developed |
| **Deprecated** | Superseded by newer version |
| **Archived** | Historical reference only |

---

## Documentation Roadmap

### Planned for v2.1.0
- [ ] Update AUTHENTICATION_AND_DATASETS.md for TNP
- [ ] Create TNP_TRIPS_SCHEMA.md reference
- [ ] Update DATA_INGESTION_WORKFLOW.md for dual datasets
- [ ] Create COMPARATIVE_ANALYTICS_GUIDE.md (taxi vs TNP)

### Planned for v2.2.0
- [ ] SILVER_LAYER_GUIDE.md
- [ ] DATA_QUALITY_FRAMEWORK.md
- [ ] MONITORING_AND_ALERTS.md
- [ ] COST_OPTIMIZATION_GUIDE.md

### Planned for v3.0.0
- [ ] REALTIME_INGESTION_GUIDE.md
- [ ] DASHBOARD_CREATION_GUIDE.md
- [ ] PRODUCTION_DEPLOYMENT.md
- [ ] MAINTENANCE_RUNBOOK.md

---

## Finding Documentation

### By Use Case

**"I want to deploy extractors and run backfill"**
→ START_HERE.md → DEPLOYMENT_GUIDE.md

**"I want to understand the architecture"**
→ README.md → ARCHITECTURE_GAP_ANALYSIS.md

**"I want to know what changed"**
→ CHANGELOG.md

**"I want to add a new dataset"**
→ docs/AUTHENTICATION_AND_DATASETS.md

**"I'm having authentication issues"**
→ extractors/taxi/FIX_DOCKER_AUTH_ERROR.md
→ docs/SOCRATA_SECRETS_USAGE.md

**"I want to run backfill on Cloud Shell"**
→ QUICKSTART_CLOUD_BACKFILL.md

### By Role

**Developers:**
- START_HERE.md
- DEPLOYMENT_GUIDE.md
- docs/DATA_INGESTION_WORKFLOW.md
- extractors/taxi/TESTING_GUIDE.md

**DevOps/Infrastructure:**
- setup_gcp_infrastructure.sh
- setup_budget_shutdown.sh
- DEPLOYMENT_GUIDE.md

**Data Engineers:**
- README.md (architecture)
- bigquery/schemas/bronze_layer.sql
- geospatial/GEOMETRY_VALIDATION_REPORT.md

**Project Managers:**
- FINAL_IMPLEMENTATION_PLAN.md
- UPDATED_WEEK1_PLAN.md
- CHANGELOG.md

**Instructors/Reviewers:**
- README.md
- ARCHITECTURE_GAP_ANALYSIS.md
- FINAL_IMPLEMENTATION_PLAN.md

---

## Documentation Metrics

### Coverage Statistics
- **Total Documents:** 20+ files
- **Versioned Documents:** 15 files
- **Status Final:** 12 files
- **In Progress:** 3 files
- **Guides & Tutorials:** 8 files
- **Architecture Docs:** 3 files
- **Reference Docs:** 4 files

### Maintenance Status
- **Last Major Update:** 2025-10-31 (v2.0.0)
- **Next Review:** 2025-11-07 (Week 2)
- **Version Control:** Git + Semantic Versioning
- **Change Tracking:** CHANGELOG.md

---

## Contributing to Documentation

### Adding New Documentation

1. **Choose document type** (see VERSIONS.md)
2. **Add version header** (use appropriate format)
3. **Update this index** (DOC_INDEX.md)
4. **Update CHANGELOG.md** (if significant)
5. **Link from related docs**
6. **Commit with proper message** (see VERSIONS.md)

### Updating Existing Documentation

1. **Check current version** (in document header)
2. **Determine version bump** (MAJOR/MINOR/PATCH)
3. **Update version header**
4. **Add to document history table**
5. **Update CHANGELOG.md**
6. **Update DOC_INDEX.md if needed**

### Review Process

1. Self-review against style guide
2. Peer review (optional for minor changes)
3. Update status to Final
4. Tag git release (for MAJOR/MINOR)

---

## Quick Links

### External Resources
- [Chicago Data Portal](https://data.cityofchicago.org/)
- [Socrata API Docs](https://dev.socrata.com/)
- [Google Cloud Documentation](https://cloud.google.com/docs)
- [BigQuery Documentation](https://cloud.google.com/bigquery/docs)
- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)

### Project Resources
- **Repository:** (Add GitHub URL when available)
- **Issue Tracker:** (Add link)
- **Team Communication:** (Add Slack/Teams channel)
- **Course Site:** Northwestern Canvas

---

## Contact & Support

**Team:** Group 2 - MSDS 432
- Albin Anto Jose
- Myetchae Thu
- Ansh Gupta
- Bickramjit Basu

**Course:** MSDSP 432 - Foundations of Data Engineering
**Institution:** Northwestern University
**Instructor:** Dr. Abid Ali

**For Documentation Issues:**
- Check CHANGELOG.md for recent changes
- Review VERSIONS.md for standards
- Contact team member responsible for that component

---

**Last Updated:** 2025-10-31 by Group 2
**Next Review:** Week 2 (2025-11-07)
**Document Status:** Maintained (continuously updated)
