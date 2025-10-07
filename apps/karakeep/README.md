# Karakeep

Karakeep is a bookmark manager with AI-powered tagging capabilities.

## Quick Setup

Use the automated setup script to generate secrets and deploy:

```bash
./setup.sh
```

The script will:
- Generate random secrets automatically
- Prompt for your OpenAI API key (optional)
- Deploy all resources
- Provide helpful next steps

## Manual Configuration

If you prefer manual setup, you can create the ConfigMap and Secret manually. Key settings:

- `KARAKEEP_VERSION`: Set to "release" for latest stable version
- `NEXTAUTH_URL`: Internal domain for authentication
- `MEILI_ADDR`: Internal service address for Meilisearch
- `BROWSER_WEB_URL`: Internal service address for Chrome browser

## Secrets

Secrets are generated automatically by the setup script:
- `NEXTAUTH_SECRET`: Generated with `openssl rand -base64 36`
- `MEILI_MASTER_KEY`: Generated with `openssl rand -base64 36`
- `OPENAI_API_KEY`: Prompted during setup (optional)

## Storage

- Karakeep data: 100Mi PVC using Longhorn storage
- Meilisearch data: 50Mi PVC using Longhorn storage

## Access

- Internal URL: `http://karakeep.buildin.group`
- Automatically discovered by Homepage

## Components

1. **karakeep-web**: Main application (port 3000)
2. **karakeep-chrome**: Chrome browser for web scraping (port 9222)
3. **karakeep-meilisearch**: Search engine (port 7700)

## Deployment

```bash
kubectl apply -k .
```

## Optional Features

To enable additional features, update the ConfigMap:

- Full page archival
- Full page screenshots
- Custom inference languages
- Ollama integration for local AI

See the [Karakeep documentation](https://docs.karakeep.app/configuration/) for more configuration options.
