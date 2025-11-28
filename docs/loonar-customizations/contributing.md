# Contributing to Loonar Superset 6.0 Customizations

Thank you for considering contributing to our Loonar-customized Apache Superset fork! This guide will help you understand our workflow and how to submit your improvements.

## Overview

This repository maintains customizations on top of Apache Superset 6.0. All contributions should:

1. Be well-documented with clear commit messages
2. Include tests when applicable
3. Maintain backward compatibility when possible
4. Follow semantic versioning principles

## Getting Started

### Fork the Repository

```bash
# Visit GitHub and fork the repository
# https://github.com/loonar-morpheus-sysint/superset

# Clone your fork
git clone https://github.com/YOUR_USERNAME/superset.git
cd superset

# Add upstream
git remote add upstream https://github.com/loonar-morpheus-sysint/superset.git
```

### Create a Feature Branch

```bash
# Always branch from 6.0
git checkout -b loonar/your-feature-name 6.0
```

## Commit Message Format

We use semantic commit messages for automatic changelog generation:

```
<type>(loonar): <subject>

<body>

<footer>
```

### Types

- **feat**: A new feature
- **fix**: A bug fix
- **docs**: Documentation changes
- **config**: Configuration updates
- **refactor**: Code refactoring without behavior change
- **perf**: Performance improvements
- **security**: Security-related changes

### Example Commits

```bash
# Feature
git commit -m "feat(loonar): add LDAP role auto-provisioning"

# Bug fix
git commit -m "fix(loonar): resolve Morpheus API timeout issue"

# Documentation
git commit -m "docs(loonar): update configuration guide for LDAP"

# Configuration
git commit -m "config(loonar): increase database connection pool size"
```

## Development Workflow

### 1. Set Up Development Environment

```bash
./docs/loonar-customizations/scripts/setup-dev.sh
```

### 2. Make Your Changes

- Create focused commits for logical units of work
- Document significant changes in the code
- Update relevant documentation files

### 3. Test Your Changes

```bash
# Run unit tests
pytest tests/

# Test deployment locally
docker-compose up -d
docker-compose exec superset pytest

# Manual testing
# Navigate to http://localhost:8088
```

### 4. Update CHANGELOG

Add an entry to `CHANGELOG.md` under `[Unreleased]` section:

```markdown
### Added
- LDAP role auto-provisioning system

### Fixed
- Morpheus API timeout errors
```

### 5. Push and Open a Pull Request

```bash
git push origin loonar/your-feature-name
```

Then:
1. Go to GitHub
2. Create a Pull Request against `6.0` branch
3. Fill in the PR template
4. Request review from maintainers

## PR Review Process

- At least one maintainer review required
- CI/CD pipeline must pass
- Changelog must be updated
- Code should follow project style guides
- Documentation should be current

## Contributing Improvements Back to Apache Superset

If your changes are suitable for upstream:

1. Identify upstream-compatible features
2. Create a separate PR against `apache/superset`
3. Reference this fork in PR description for context
4. Follow Apache Superset's contribution guidelines

### Upstream PR Checklist

- [ ] Tested against latest Apache Superset
- [ ] All conflicts resolved
- [ ] Apache Superset CONTRIBUTING.md followed
- [ ] License compatibility verified
- [ ] No Loonar-specific code included

## Code Style

- Follow PEP 8 for Python code
- Use 4 spaces for indentation
- Maximum line length: 100 characters
- Use type hints where applicable

## Documentation

- Update README.md for user-facing changes
- Update deployment.md for deployment changes
- Add comments for complex logic
- Include examples where helpful

## Issues and Bug Reports

When reporting issues:

1. Check existing issues first
2. Include reproduction steps
3. Specify your environment (OS, Python version, etc.)
4. Attach relevant logs

## Questions?

- Check README.md for general information
- See deployment.md for deployment questions
- Review configuration.md for configuration help
- Check existing issues and PRs for answers

## License

By contributing, you agree that your contributions will be licensed under Apache License 2.0, same as Apache Superset.

## Code of Conduct

Be respectful and inclusive. All contributions are welcome, regardless of background or experience level.

---

Thank you for contributing to Loonar Superset!
