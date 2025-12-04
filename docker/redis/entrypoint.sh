#!/bin/bash
# Redis entrypoint script for Superset
# This script ensures proper permissions for the Redis data directory

# Ensure /data directory exists with correct permissions
mkdir -p /data
chmod 755 /data

# If there are any RDB files, ensure they have correct permissions
if [ -f /data/dump.rdb ]; then
    chmod 644 /data/dump.rdb
fi

# Start Redis server with the configuration file
exec redis-server /etc/redis/redis.conf
