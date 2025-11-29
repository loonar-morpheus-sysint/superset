# Superset Map Tiles Configuration Agent Mode

## Overview
Automates configuration of map tile sources for geospatial visualizations. Supports OSM, Mapbox, and custom tile URLs.

## Key Configurations & Variables
- `DECKGL_BASE_MAP` (tile source list)
- `CORS_OPTIONS` (allowed origins)
- `TALISMAN_CONFIG` (CSP for map tiles)
- `ENABLE_CORS` (CORS enablement)
- `MAPBOX_API_KEY` (Mapbox support)

## Best Practices
- Use OSM for free/public maps, Mapbox for advanced features
- Set CORS and CSP to allow required tile sources
- Validate tile URLs and access
- Use environment variables for API keys

## Docker Compose Integration
- Mount custom config for tile sources
- Use `.env` for Mapbox API keys
- Validate map rendering in UI

## Security & Automation Notes
- Rotate API keys regularly
- Restrict access to custom tile URLs
# Superset Map Tiles Configuration Agent Mode

## Overview
Automates configuration of map tile sources for geospatial visualizations. Supports OSM, Mapbox, and custom tile URLs.

## Key Configurations & Variables
- `DECKGL_BASE_MAP` (tile source list)
- `CORS_OPTIONS` (allowed origins)
- `TALISMAN_CONFIG` (CSP for map tiles)
- `ENABLE_CORS` (CORS enablement)
- `MAPBOX_API_KEY` (Mapbox support)

## Best Practices
- Use OSM for free/public maps, Mapbox for advanced features
- Set CORS and CSP to allow required tile sources
- Validate tile URLs and access
- Use environment variables for API keys

## Docker Compose Integration
- Mount custom config for tile sources
- Use `.env` for Mapbox API keys
- Validate map rendering in UI

## Security & Automation Notes
- Rotate API keys regularly
- Restrict access to custom tile URLs
