# Documentation Versioning Standards

**Document Version:** 1.0.0
**Last Updated:** 2025-10-31
**Maintained By:** Group 2 - MSDS 432

---

## Overview

This document defines the versioning standards for all project documentation, code, and configurations in the Chicago BI App project. Following these standards ensures clear context across sessions and facilitates collaboration.

---

## Versioning Scheme

We use **Semantic Versioning 2.0.0** ([semver.org](https://semver.org)):

```
MAJOR.MINOR.PATCH

Example: 2.1.3
```

### Version Number Meanings

**MAJOR (X.0.0)** - Increment when:
- Breaking changes to APIs, schemas, or interfaces
- Major architectural changes
- Significant new features requiring migration
- Changes that make previous versions incompatible

**MINOR (x.Y.0)** - Increment when:
- New features added (backward compatible)
- New datasets or extractors added
- New documentation sections
- Enhanced functionality without breaking existing code

**PATCH (x.y.Z)** - Increment when:
- Bug fixes
- Documentation corrections
- Minor improvements
- Typo fixes
- Clarifications

---

## Documentation Types & Versioning

### Type 1: Architecture Documentation
**Versioning:** MAJOR.MINOR only (no PATCH)
**Examples:** README.md, ARCHITECTURE_GAP_ANALYSIS.md

**Why:** Architectural decisions are significant; minor corrections don't warrant version changes.

```markdown
# README.md
**Version:** 2.0
**Last Updated:** 2025-10-31
```

### Type 2: Guides & Tutorials
**Versioning:** Full MAJOR.MINOR.PATCH
**Examples:** DEPLOYMENT_GUIDE.md, QUICKSTART_CLOUD_BACKFILL.md

**Why:** Guides evolve frequently with clarifications and corrections.

```markdown
# DEPLOYMENT_GUIDE.md
**Version:** 2.0.1
**Last Updated:** 2025-10-31
```

### Type 3: Reference Documentation
**Versioning:** Full MAJOR.MINOR.PATCH + Document Date
**Examples:** API docs, schema definitions, configuration references

**Why:** Reference docs need precise tracking and date stamps.

```markdown
# API_REFERENCE.md
**Document Version:** 2.1.0
**Schema Version:** 2.0
**Published:** 2025-10-31
```

### Type 4: Code & Scripts
**Versioning:** Git tags + inline version constants
**Examples:** Extractors, backfill scripts, infrastructure scripts

**Why:** Code is tracked by git, but version constants help runtime identification.

```go
// main.go
const (
    Version = "2.0.0"
    BuildDate = "2025-10-31"
)
```

### Type 5: Schemas (BigQuery/Database)
**Versioning:** MAJOR.MINOR + Schema Migration Number
**Examples:** bronze_layer.sql, silver_layer.sql

**Why:** Schema changes are critical and need migration tracking.

```sql
-- Schema Version: 2.0
-- Migration: 003
-- Date: 2025-10-31
-- Description: Added raw_tnp_trips table
```

---

## Version Header Format

### Standard Header (All Documents)

```markdown
---
**Document:** [Document Name]
**Version:** [MAJOR.MINOR.PATCH]
**Date:** [YYYY-MM-DD]
**Status:** [Draft | Review | Final | Deprecated]
**Supersedes:** [Previous version] (if applicable)
**Authors:** [Author names or Group 2]
---
```

### Extended Header (Complex Documents)

```markdown
---
**Document:** Chicago BI App - Deployment Guide
**Version:** 2.0.1
**Document Type:** Tutorial/Guide
**Date:** 2025-10-31
**Last Reviewed:** 2025-10-31
**Status:** Final
**Supersedes:** v1.0.0
**Authors:** Group 2 - MSDS 432
**Reviewers:** Dr. Abid Ali
**Related Docs:** START_HERE.md v2.0, README.md v2.0
**Changelog:** See CHANGELOG.md
---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 2.0.1 | 2025-10-31 | Group 2 | Fixed typo in Step 3 |
| 2.0.0 | 2025-10-31 | Group 2 | Added TNP trips support |
| 1.0.0 | 2025-10-30 | Group 2 | Initial release |
```

---

## Version Control Workflow

### Git Tags

Tag all major and minor releases:

```bash
# Major/minor release
git tag -a v2.0.0 -m "Release 2.0.0: TNP trips support"
git push origin v2.0.0

# Patch release
git tag -a v2.0.1 -m "Release 2.0.1: Documentation fixes"
git push origin v2.0.1
```

### Branch Strategy

- `main` - Current stable version
- `develop` - Next version in development
- `feature/*` - Feature branches
- `hotfix/*` - Urgent fixes for main

### Commit Message Format

```
type(scope): subject

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting)
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(extractor): add TNP trips extractor for m6dm-c72p

- Implements authenticated SODA API calls
- Matches m6dm-c72p schema exactly
- Includes deployment and test scripts

Closes #42

---

docs(guide): update deployment guide to v2.0.0

- Add TNP extractor deployment steps
- Update schema deployment section
- Add troubleshooting for TNP-specific issues

---

fix(schema): correct TNP trips field types

- Change trips_pooled from STRING to INT64
- Add missing _api_response_code field

Breaking change: Requires schema redeployment
```

---

## File Naming Conventions

### Documentation Files

```
DOCUMENT_NAME.md           # Main document
DOCUMENT_NAME_v2.md        # Version-specific (if needed)
DOCUMENT_NAME_ARCHIVE.md   # Archived versions
```

### Avoid:
- ❌ `deployment-guide-new.md`
- ❌ `readme_updated.md`
- ❌ `schema_final_v3.sql`

### Use:
- ✅ `DEPLOYMENT_GUIDE.md` (with version header)
- ✅ `README.md` (with version header)
- ✅ `bronze_layer.sql` (with schema version comment)

---

## When to Increment Versions

### MAJOR Version Increment

**Scenarios:**
- New dataset type added (e.g., TNP trips alongside taxi)
- Breaking schema changes
- New architecture tier (e.g., adding platinum layer)
- Changed API contracts
- Migration required from previous version

**Example:**
- v1.0.0 → v2.0.0: Added TNP trips support (new dataset type)

**Actions:**
- Update CHANGELOG.md
- Create migration guide
- Tag git release
- Update all documentation headers
- Notify team

### MINOR Version Increment

**Scenarios:**
- New feature within existing scope
- New documentation sections
- Enhanced scripts (backward compatible)
- New optional fields

**Example:**
- v2.0.0 → v2.1.0: Added data quality checks

**Actions:**
- Update CHANGELOG.md
- Tag git release
- Update affected documentation

### PATCH Version Increment

**Scenarios:**
- Bug fixes
- Documentation typos
- Clarifications
- Minor script improvements

**Example:**
- v2.0.0 → v2.0.1: Fixed deployment guide typos

**Actions:**
- Update CHANGELOG.md (optional for minor patches)
- Commit with descriptive message
- No git tag needed (unless critical hotfix)

---

## Documentation Status Levels

| Status | Meaning | Action Required |
|--------|---------|-----------------|
| **Draft** | Work in progress, not reviewed | Review before use |
| **Review** | Complete, awaiting peer review | Provide feedback |
| **Final** | Reviewed and approved for use | Use as-is |
| **Deprecated** | Superseded by newer version | Migrate to new version |
| **Archived** | Historical reference only | Do not use for new work |

---

## Cross-Document Version Dependencies

Some documents depend on specific versions of others. Track this:

```markdown
## Dependencies

This document (DEPLOYMENT_GUIDE.md v2.0.0) depends on:

- README.md v2.0 or higher
- bronze_layer.sql schema v2.0 or higher
- extractors/taxi v1.0.0 or higher
- extractors/tnp v2.0.0 or higher

Incompatible with:
- bronze_layer.sql schema v1.x (missing raw_tnp_trips table)
```

---

## Version Matrix

| Component | Current Version | Minimum Compatible | Notes |
|-----------|----------------|-------------------|-------|
| Project | 2.0.0 | 2.0.0 | Full version |
| README.md | 2.0 | 2.0 | Architecture docs |
| DEPLOYMENT_GUIDE.md | 2.0.0 | 2.0.0 | Guides |
| bronze_layer.sql | 2.0 (M003) | 2.0 | Schema + migration |
| extractor-taxi | 1.0.0 | 1.0.0 | Code version |
| extractor-tnp | 2.0.0 | 2.0.0 | Code version |
| quarterly_backfill | 1.1.0 | 1.0.0 | Backward compatible |

---

## Review & Update Schedule

| Document Type | Review Frequency | Update Trigger |
|---------------|------------------|----------------|
| Architecture | Per phase | Major changes |
| Guides | Weekly | User feedback |
| Reference | On schema change | Schema updates |
| Code docs | Per commit | Code changes |
| CHANGELOG.md | Every release | All changes |

---

## Archive Policy

### When to Archive

- Document superseded by 2+ major versions
- Component deprecated/removed
- Significant architecture change makes doc obsolete

### How to Archive

1. Move to `docs/archive/` directory
2. Add `[ARCHIVED]` prefix to filename
3. Update header with deprecation notice
4. Link to current version
5. Keep for historical reference

**Example:**
```
docs/archive/[ARCHIVED]_DEPLOYMENT_GUIDE_v1.0.0.md
```

---

## Tools & Automation

### Recommended Tools

- **Version bumping:** `bump2version` or manual
- **Changelog generation:** Manual (Keep a Changelog format)
- **Git tagging:** GitHub releases
- **Documentation linting:** `markdownlint`

### Scripts

```bash
# Bump version (example)
./scripts/bump_version.sh minor  # 2.0.0 → 2.1.0
./scripts/bump_version.sh major  # 2.0.0 → 3.0.0
./scripts/bump_version.sh patch  # 2.0.0 → 2.0.1

# Update all documentation headers
./scripts/update_doc_headers.sh 2.1.0
```

---

## FAQ

### Q: Do I need to version every markdown file?
**A:** Major documentation files should be versioned. Minor notes, TODOs, and scratch files don't need versions.

### Q: What if I make a small typo fix?
**A:** For guides, increment PATCH. For architecture docs, just commit without version change unless it's a significant correction.

### Q: How do I handle conflicting versions across documents?
**A:** Use the version matrix and dependency tracking. Update DOC_INDEX.md to show compatible version sets.

### Q: Should I version code and docs together?
**A:** They share the project version, but can have independent minor/patch versions. Document this in DOC_INDEX.md.

### Q: What about schema versions vs. project versions?
**A:** Schemas use `MAJOR.MINOR + Migration Number`. They align with project major versions but can have independent minor updates.

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────┐
│ VERSIONING QUICK REFERENCE                              │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Format:       MAJOR.MINOR.PATCH                         │
│                                                         │
│ MAJOR:        Breaking changes, new datasets            │
│ MINOR:        New features (compatible)                 │
│ PATCH:        Bug fixes, typos                          │
│                                                         │
│ Architecture: MAJOR.MINOR only                          │
│ Guides:       Full MAJOR.MINOR.PATCH                    │
│ Schemas:      MAJOR.MINOR + Migration #                 │
│                                                         │
│ Git Tag:      v2.0.0, v2.1.0, etc.                      │
│ Status:       Draft → Review → Final → Deprecated       │
│                                                         │
│ Files:        CHANGELOG.md (all changes)                │
│               VERSIONS.md (this file)                   │
│               DOC_INDEX.md (version matrix)             │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Contact & Contributions

For questions about versioning standards:
- **Team:** Group 2 - MSDS 432
- **Course:** Northwestern University
- **Instructor:** Dr. Abid Ali

To propose changes to this standard:
1. Open an issue describing the change
2. Create a pull request with proposed updates
3. Get team consensus
4. Update this document with new version number

---

**Document Version History:**

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-10-31 | Initial versioning standards document |

---

**Northwestern MSDS 432 - Group 2**
