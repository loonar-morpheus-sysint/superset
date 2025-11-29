# Superset Country Map Tools Configuration Agent Mode

## Overview
Automates management of country map visualizations, including GeoJSON assets and ISO-3166-2 codes. Supports adding new countries and customizing map sources.

## Key Configurations & Variables
- `legacy-plugin-chart-country-map/src/countries.ts` (country list)
- GeoJSON files for new countries
- `MAPBOX_API_KEY` (if using Mapbox)

## Best Practices
- Use ISO-3166-2 codes for subdivisions
- Generate GeoJSON with provided Jupyter notebook
- Validate new maps in Superset plugins storybook
- Use npm scripts for plugin management

## Docker Compose Integration
- Mount custom country map assets
- Use `.env` for Mapbox API keys
- Install frontend dependencies as needed

## Security & Automation Notes
- Restrict access to custom map assets
- Rotate Mapbox API keys if used
