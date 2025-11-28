# Changelog - Loonar Superset Customizations

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Changelog Format

- **Added:** for new features.
- **Changed:** for changes in existing functionality.
- **Deprecated:** for soon-to-be removed features.
- **Removed:** for now removed features.
- **Fixed:** for any bug fixes.
- **Security:** in case of vulnerabilities.

---

## [Unreleased]

### Added
- Initial setup of customizations directory structure
- Documentation framework and templates
- Utility scripts for deployment and maintenance
- Git workflow guidelines for contributions

### Changed
- None

### Fixed
- None

### Security
- None

---

## Version 1.0.0 - 2025-11-28

### Added
- **Infrastructure**
  - Created `docs/loonar-customizations` directory
  - Comprehensive README documentation
  - Changelog template (this file)
  - Deployment procedures guide
  - Configuration documentation
  - Contributing guidelines
  
- **Scripts**
  - `update-from-upstream.sh` - Sync with Apache Superset updates
  - `deploy.sh` - Automated deployment script
  - `backup-config.sh` - Configuration backup utility
  - `generate-changelog.sh` - Changelog generator from git commits
  
- **Templates**
  - `docker-compose.override.yml` - Docker Compose override configuration
  - `superset_config_loonar.py` - Example Loonar configuration file
  
- **Features**
  - LDAP auto-role creation system
  - Morpheus Data integration templates
  - Custom theme and branding system

### Changed
- Repository structure now clearly separates Apache Superset code from Loonar customizations
- Git workflow standardized with semantic commit messages

### Documentation
- Complete setup guide for local development
- Step-by-step deployment procedures for multiple environments
- Guidelines for contributing changes back to Apache Superset
- Configuration examples and best practices

---

## Maintenance Notes

### How to Use This Changelog

When making changes to this repository:

1. **Update Section**: Add your change to the appropriate section under `[Unreleased]`
2. **Semantic Format**: Use one of the standard categories (Added, Changed, Removed, etc.)
3. **Include Details**: Be specific about what changed and why
4. **Link Issues**: Reference GitHub issues and PRs when applicable
5. **Release Process**: When releasing, move all items from `[Unreleased]` to a new version section

### Version Numbering

This project follows Semantic Versioning:
- **MAJOR** (X.0.0): Incompatible API changes or significant features
- **MINOR** (0.X.0): New features, backwards compatible
- **PATCH** (0.0.X): Bug fixes, backwards compatible

Example: `1.2.3` means Major version 1, Minor version 2, Patch version 3

### Commit Message Integration

Git commits using the semantic format will be automatically categorized:
```
feat(loonar):   -> Added
fix(loonar):    -> Fixed
docs(loonar):   -> Documentation updates
config(loonar): -> Configuration changes
perf(loonar):   -> Performance improvements
refactor(loonar): -> Code refactoring (usually under Changed)
security(loonar): -> Security improvements
```

Run `./scripts/generate-changelog.sh` to automatically generate sections from commits.

---

## References

- **Apache Superset**: https://github.com/apache/superset
- **Keep a Changelog**: https://keepachangelog.com/en/1.0.0/
- **Semantic Versioning**: https://semver.org/
- **Conventional Commits**: https://www.conventionalcommits.org/

---

## Questions?

Refer to the main README.md or check the documentation in the docs/loonar-customizations/ directory.
