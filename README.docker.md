# Docker Development Setup for DocuSeal

This guide explains how to use Docker for DocuSeal development with live code reloading.

## Overview

DocuSeal now has two Docker configurations:

1. **`Dockerfile.prod`** - Production-optimized multi-stage build (original Dockerfile)
2. **`Dockerfile.dev`** - Development build with volume mounting for live code changes

## Quick Start

### Development with Live Code Reloading

```bash
# Start the development environment
docker compose -f docker-compose.dev.yml up

# Access the application at http://localhost:3000
```

That's it! Your source code is now mounted as volumes, so any changes you make will be reflected immediately:
- Ruby files will reload automatically (Rails auto-reloading)
- JavaScript/Vue files will hot-reload via Webpack dev server
- CSS changes will be reflected instantly

## Common Tasks

### Initial Setup

```bash
# Build and start services
docker compose -f docker-compose.dev.yml up --build
```

### Running Commands Inside the Container

```bash
# Open Rails console
docker compose -f docker-compose.dev.yml exec app bundle exec rails c

# Run migrations
docker compose -f docker-compose.dev.yml exec app bundle exec rails db:migrate

# Run tests
docker compose -f docker-compose.dev.yml exec app bundle exec rspec

# Run rubocop
docker compose -f docker-compose.dev.yml exec app bundle exec rubocop

# Access bash shell
docker compose -f docker-compose.dev.yml exec app bash
```

### Managing Dependencies

When you update `Gemfile` or `package.json`, you need to rebuild:

```bash
# Stop containers
docker compose -f docker-compose.dev.yml down

# Rebuild with new dependencies
docker compose -f docker-compose.dev.yml up --build
```

### Database Operations

```bash
# Create database
docker compose -f docker-compose.dev.yml exec app bundle exec rails db:create

# Run migrations
docker compose -f docker-compose.dev.yml exec app bundle exec rails db:migrate

# Seed database
docker compose -f docker-compose.dev.yml exec app bundle exec rails db:seed

# Reset database
docker compose -f docker-compose.dev.yml exec app bundle exec rails db:reset
```

### Viewing Logs

```bash
# View all logs
docker compose -f docker-compose.dev.yml logs -f

# View app logs only
docker compose -f docker-compose.dev.yml logs -f app

# View PostgreSQL logs
docker compose -f docker-compose.dev.yml logs -f postgres
```

### Stopping the Environment

```bash
# Stop containers (preserves data)
docker compose -f docker-compose.dev.yml stop

# Stop and remove containers (preserves volumes)
docker compose -f docker-compose.dev.yml down

# Stop, remove containers AND volumes (complete cleanup)
docker compose -f docker-compose.dev.yml down -v
```

## What Gets Mounted?

The following directories are mounted as volumes for live editing:

- `./app` - Rails application code (models, controllers, views, JavaScript)
- `./lib` - Custom libraries and modules
- `./config` - Configuration files
- `./db` - Database migrations and schema
- `./spec` - Tests
- `./public` - Static assets
- `./bin` - Executable scripts
- `./Gemfile` & `./Gemfile.lock` - Ruby dependencies
- `./package.json` & `./yarn.lock` - JavaScript dependencies

## Performance Optimization

The `node_modules` and `bundle` directories are stored in Docker volumes (not mounted from host) for better performance, especially on macOS and Windows.

## Environment Variables

You can customize the environment by editing the `environment` section in `docker-compose.dev.yml`:

```yaml
environment:
  - RAILS_ENV=development
  - DATABASE_URL=postgresql://postgres:postgres@postgres:5432/docuseal_dev
  - SIGNATURE_TYPE=pades  # Enable PAdES signatures
  # Add your custom variables here
```

## Production Build

To build the production Docker image:

```bash
# Build production image
docker build -f Dockerfile.prod -t docuseal:prod .

# Run production image
docker run -p 3000:3000 -v ./data:/data docuseal:prod
```

Or use the original `docker-compose.yml`:

```bash
docker-compose up
```

## Troubleshooting

### Port Already in Use

If port 3000 is already in use, edit `docker-compose.dev.yml` and change:
```yaml
ports:
  - "3001:3000"  # Change 3001 to any free port
```

### Permission Issues

If you encounter permission issues with volumes:
```bash
# Fix ownership (run on host)
sudo chown -R $(id -u):$(id -g) ./data
```

### Fresh Start

To start completely fresh:
```bash
# Remove everything including volumes
docker compose -f docker-compose.dev.yml down -v

# Remove Docker images
docker rmi $(docker images -q docuseal*)

# Rebuild from scratch
docker compose -f docker-compose.dev.yml up --build
```

### Webpack Not Compiling

If webpack isn't compiling assets:
```bash
# Check webpack logs
docker compose -f docker-compose.dev.yml logs -f app | grep webpack

# Manually run webpack
docker compose -f docker-compose.dev.yml exec app yarn shakapacker
```

## Architecture Differences

### Dockerfile.dev
- Installs development dependencies
- Includes build tools and debugging utilities
- Expects source code as volume mounts
- Runs in development mode
- Includes hot reloading

### Dockerfile.prod
- Multi-stage build for minimal image size
- Precompiles all assets
- Copies source code into image
- Optimized for production
- No development dependencies

## Tips

1. **Keep containers running**: Leave `docker compose` running in a terminal for the best development experience
2. **Use VS Code Remote**: Install the "Dev Containers" extension to develop inside the container
3. **Database persistence**: Your PostgreSQL data is stored in a Docker volume and persists between restarts
4. **Code sync**: Changes to code files are instant - no need to restart containers

## Need Help?

- Check logs: `docker compose -f docker-compose.dev.yml logs -f`
- Open an issue on GitHub: https://github.com/docusealco/docuseal/issues
- Join the Discord: https://discord.gg/qygYCDGck9
