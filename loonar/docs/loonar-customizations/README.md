# Loonar Customizations for Apache Superset 6.0

## Overview

This directory tracks all Loonar-specific modifications to Apache Superset 6.0. It maintains a clear separation between upstream Apache Superset code and Loonar customizations, facilitating easier updates and potential contributions back to the main project.

**Branch:** `6.0`  
**Base Version:** Apache Superset 6.0.x  
**Last Updated:** November 28, 2025

## Directory Structure

```
docs/loonar-customizations/
├── README.md                    # This file - Overview of all customizations
├── CHANGELOG.md                 # Detailed change log of all modifications
├── deployment.md                # Deployment procedures and guides
├── configuration.md             # Loonar-specific configuration details
├── contributing.md              # Guidelines for contributing changes upstream
├── scripts/
│   ├── update-from-upstream.sh  # Sync with Apache Superset updates
│   ├── deploy.sh                # Automated deployment script
│   ├── backup-config.sh         # Backup configuration and customizations
│   └── generate-changelog.sh    # Generate changelog from commits
├── templates/
│   └── docker-compose.override.yml  # Docker Compose override template
└── examples/
    └── superset_config_loonar.py    # Example Loonar-specific configurations
```

## Customizations

### 1. LDAP Auto-Role Creation
- **Status:** Active
- **Files Modified:** `superset/security/manager.py`
- **Reason:** Automatic role mapping based on LDAP groups
- **Documentation:** See `configuration.md`
- **Upstream Candidate:** Potentially

### 2. Morpheus Data Integration
- **Status:** Active
- **Files Modified:** Custom dashboard templates
- **Reason:** Integration with Morpheus Data platform
- **Documentation:** See `configuration.md`
- **Upstream Candidate:** No (organization-specific)

### 3. Custom Theme & Branding
- **Status:** Active
- **Files Modified:** `superset/assets/stylesheets/`, custom logos
- **Reason:** Loonar corporate branding
- **Documentation:** See `configuration.md`
- **Upstream Candidate:** No

## Quick Start

### Local Development
```bash
# Clone repository
git clone https://github.com/loonar-morpheus-sysint/superset.git
cd superset

# Checkout customization branch
git checkout 6.0

# Create feature branch
git checkout -b loonar/feature-name

# Set up development environment
./docs/loonar-customizations/scripts/setup-dev.sh
```

### Deployment
```bash
# See deployment.md for detailed instructions
./docs/loonar-customizations/scripts/deploy.sh production
```

### Updating from Upstream
```bash
# Automatically sync with latest Apache Superset 6.0
./docs/loonar-customizations/scripts/update-from-upstream.sh
```

## Git Workflow

### Commit Message Format
Use semantic commits to facilitate tracking and changelog generation:

```
feat(loonar):   new feature
fix(loonar):    bug fix
docs(loonar):   documentation changes
config(loonar): configuration updates
perf(loonar):   performance improvements
refactor(loonar): code refactoring
```

### Example Commits
```bash
# For integrations
git commit -m "feat(loonar): add LDAP auto-role creation"

# For configurations
git commit -m "config(loonar): update Morpheus Data API endpoint"

# For documentation
git commit -m "docs(loonar): add setup guide"
```

## Branches

- **6.0** - Main development branch (based on Apache Superset 6.0)
- **6.0-stable** - Production-ready releases
- **feature/*** - Feature branches
- **bugfix/*** - Bug fix branches

## Contributing Back to Upstream

To submit improvements to Apache Superset:

1. Identify upstream-compatible changes
2. Create a feature branch from `6.0`
3. Cherry-pick relevant commits
4. Open Pull Request to `apache/superset:master` or appropriate version branch
5. Reference this repository in PR description for context

See `contributing.md` for detailed guidelines.

## Maintenance

### Regular Tasks
- **Weekly:** Review upstream Apache Superset releases
- **Monthly:** Update CHANGELOG.md
- **Quarterly:** Full sync with upstream Apache Superset
- **On Each Deployment:** Backup configurations using `backup-config.sh`

### Monitoring
- Check GitHub Actions CI/CD pipeline: `.github/workflows/`
- Review security alerts in repository settings
- Monitor Apache Superset security announcements

## Documentation Files

| File | Purpose |
|------|---------|
| `README.md` | You are here - Overview and quick start |
| `CHANGELOG.md` | Detailed log of all changes and versions |
| `deployment.md` | Step-by-step deployment procedures |
| `configuration.md` | Environment variables and config options |
| `contributing.md` | Guidelines for contributions and PRs |

## Support & Resources

- **Apache Superset Docs:** https://superset.apache.org/docs/
- **Apache Superset GitHub:** https://github.com/apache/superset
- **Loonar Superset Fork:** https://github.com/loonar-morpheus-sysint/superset

## License

Apache License 2.0 - Same as Apache Superset

For modifications and custom code:
- Maintain compliance with Apache License 2.0
- Document all changes with clear comments
- Consider contributing improvements upstream
