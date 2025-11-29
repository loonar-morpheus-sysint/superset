# GitHub Copilot Agent Documentation Integration

This file configures Copilot agents to use the modular agent documentation found in `loonar/docs/ia` for Superset automation and configuration.

## Agent Documentation Directory

- All agent mode docs for Superset configuration are now located in:
  - `superset/loonar/docs/ia/`

## Usage Instructions

- Agents should reference these `.config.agent.md` files for:
  - Automated configuration
  - Modular best practices
  - Security and secret rotation
  - Docker Compose integration
  - Feature enablement and validation

## Integration Example

- When Copilot agents are invoked for Superset automation, they should:
  1. Discover available agent docs in `loonar/docs/ia/`
  2. Load relevant `.config.agent.md` for the requested feature or section
  3. Apply best practices and configuration steps as described

## File List

- AlertsReports.config.agent.md
- AsyncQueriesCelery.config.agent.md
- Cache.config.agent.md
- ConfiguringSuperset.config.agent.md
- CountryMapTools.config.agent.md
- Databases.config.agent.md
- EventLogging.config.agent.md
- ImportExportDatasources.config.agent.md
- MapTiles.config.agent.md
- NetworkingSettings.config.agent.md
- SQLTemplating.config.agent.md
- Theming.config.agent.md
- Timezones.config.agent.md

## Maintenance

- Update this directory whenever new agent modes are added or existing ones are changed.
- Ensure all documentation follows modular, automation-ready, and security best practices.

---

This file enables Copilot to discover and utilize all agent documentation for Superset automation and configuration tasks.
