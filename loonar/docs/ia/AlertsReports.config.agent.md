# Superset Alerts & Reports Configuration Agent Mode

## Overview
Automates and manages Superset's Alerts & Reports system, enabling scheduled and conditional notifications via email and Slack. Integrates with Celery, Redis, SMTP, and Slack APIs.

## Key Configurations & Variables
- `FEATURE_FLAGS["ALERT_REPORTS"]` (enable alerts/reports)
- `ALERT_REPORTS_NOTIFICATION_DRY_RUN` (set to `False` for production)
- `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_MAIL_FROM` (email)
- `SLACK_API_TOKEN`, `SLACK_API_RATE_LIMIT_RETRY_COUNT`, `SLACK_CACHE_TIMEOUT` (Slack)
- `REDIS_HOST`, `REDIS_PORT` (Celery broker)
- `WEBDRIVER_TYPE`, `WEBDRIVER_BASEURL`, `WEBDRIVER_BASEURL_USER_FRIENDLY` (headless browser)
- `ALERT_MINIMUM_INTERVAL`, `REPORT_MINIMUM_INTERVAL` (rate limiting)

## Best Practices
- Use Playwright with Chrome for screenshots (recommended)
- Run a single Celery beat scheduler, multiple workers
- Use strong SMTP credentials and secure Slack tokens
- Set minimum intervals to avoid notification spam
- Use environment variables for secrets, automate rotation

## Docker Compose Integration
- Ensure Redis and PostgreSQL are present
- Add Celery worker and beat services
- Mount custom `superset_config.py` for overrides
- Use `.env` for all secrets and rotatable keys

## Security & Automation Notes
- Mark all secrets as `[ROTATABLE]` in `.env`
- Use automation script for secret rotation
- Restrict Celery concurrency for resource management
- Validate SMTP/Slack connectivity with test commands
