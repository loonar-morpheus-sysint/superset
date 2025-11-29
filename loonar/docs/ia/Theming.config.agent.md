# Superset Theming Configuration Agent Mode

## Overview
Automates management of UI themes, including Ant Design tokens, custom fonts, ECharts overrides, and dashboard-specific themes.

## Key Configurations & Variables
- `ENABLE_UI_THEME_ADMINISTRATION` (UI theme admin)
- `THEME_DEFAULT`, `THEME_DARK` (theme JSON)
- `CUSTOM_FONT_URLS` (font sources)
- `TALISMAN_CONFIG` (CSP for fonts/styles)
- `echartsOptionsOverrides`, `echartsOptionsOverridesByChartType` (ECharts)

## Best Practices
- Use UI for theme management when possible
- Export/import themes via YAML for portability
- Use Ant Design Theme Editor for design
- Document theme tokens and overrides
- Validate theme application on dashboards

## Docker Compose Integration
- Mount custom config for themes/fonts
- Use `.env` for theme feature flags
- Validate theme rendering in UI

## Security & Automation Notes
- Restrict theme editing to admins
- Validate font sources and CSP
