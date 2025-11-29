# Superset Async Queries & Celery Configuration Agent Mode

## Overview
Manages long-running SQL queries using Celery workers and message brokers (Redis/RabbitMQ). Enables asynchronous query execution and result caching.

## Key Configurations & Variables
- `CELERY_CONFIG` (class in `superset_config.py`)
  - `broker_url`, `result_backend`, `imports`, `worker_prefetch_multiplier`, `task_acks_late`, `task_annotations`, `beat_schedule`
- `RESULTS_BACKEND` (cache for query results)
- `RESULTS_BACKEND_USE_MSGPACK` (serialization)

## Best Practices
- Use Redis for broker and backend (recommended)
- Only one Celery beat instance per deployment
- Share metadata DB across all workers/web servers
- Enable async query execution in DB settings
- Monitor with Flower (`celery ... flower`)

## Docker Compose Integration
- Add Redis service
- Add Celery worker and beat services
- Mount custom `superset_config.py`
- Use `.env` for broker/backend URLs

## Security & Automation Notes
- Use strong Redis passwords
- Automate rotation of broker/backend secrets
- Monitor worker logs for errors and duplicate scheduling
