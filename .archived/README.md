# Archived Files

This directory contains redundant and debug scripts that were cleaned up from the workspace root.

## Contents

### `debug_scripts/` 
One-off debug, investigation, and diagnostic scripts used for troubleshooting specific issues:
- `investigate_*.js` - RevenueCat, subscription, and verification investigation scripts
- `fix_*.js` - One-off fixes for specific user issues or bugs
- `lock_*.js` - Scripts to lock/unlock user verification status
- `restore_*.js` - Scripts to restore archived profiles
- `get_audit_log.js` - Firebase audit log retrieval
- `rc_webhook_check.js` - RevenueCat webhook debugging
- `preview_rejected_profiles.js` - Preview rejected dating profiles
- `verify_dating_profile.js` - Dating profile verification debug
- `update_subscription_expiry.js` - One-off subscription updates
- `update_verification_status.js` - One-off verification status updates
- `ROOT_CAUSE_ANDROID_SUBSCRIPTIONS.js` - Android subscription analysis

### `audit_reports/`
JSON audit and verification reports from various verification passes and migrations.

### `debug_docs/`
Markdown documentation about specific bugs, issues, and implementations:
- Feature implementation guides
- Bug analysis and root cause documentation
- Verification reports
- Deployment summaries

### `data_files/`
Data files and old configuration files:
- `nexus1_onboarding_lists_v1.json` - V1 onboarding data
- `teaching_card_text.txt` - Old card content

### `backups/`
Backup files created during development.

## Note

These files were archived rather than deleted to preserve them in case they're needed for reference or debugging. All core application code and essential configuration remains in the workspace root.

**Important Scripts Kept:**
- `migrate_v1_to_v2_subscription.js` - Migration utility
- `query_revenuecat_api.js` - RevenueCat API utility
- `verify_fix.py` - Python verification utility
- All `activate_*.js` scripts
- All `verify_*.js` and `award_*.js` scripts

**Updated:** March 27, 2026
