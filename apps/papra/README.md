# Papra - Document Management System

Papra is a modern document management system that helps you organize, search, and manage your documents efficiently.

## Features

- Document upload and organization
- Full-text search capabilities
- OCR (Optical Character Recognition) support
- Tag-based organization
- User authentication and authorization
- Multi-organization support
- Document encryption at rest
- Email ingestion support

## Configuration

This deployment is configured as an internal app accessible via `papra.ganam.app`.

### Key Environment Variables

- `APP_BASE_URL`: Set to `https://papra.ganam.app`
- `AUTH_SECRET`: Authentication secret (change this!)
- `DATABASE_URL`: SQLite database location
- `DOCUMENT_STORAGE_DRIVER`: File system storage
- `DOCUMENT_STORAGE_FILESYSTEM_ROOT`: Document storage path
- `DOCUMENT_STORAGE_MAX_UPLOAD_SIZE`: 10MB upload limit
- `DOCUMENTS_OCR_LANGUAGES`: English OCR support
- `EMAILS_DRIVER`: Logger (no actual email sending)

### Storage

- Uses Longhorn storage class
- 10Gi persistent volume for documents and database
- Data stored in `/app/app-data/` directory

### Security

- Runs as non-root user (UID 1000)
- Proper security context configuration
- File system group ownership

## Access

Once deployed, access Papra at: https://papra.ganam.app

## Initial Setup

1. Access the application
2. Create your first user account
3. Set up your organization
4. Start uploading and organizing documents

## Configuration Options

For advanced configuration, you can modify the environment variables in the deployment.yaml file. See the [Papra documentation](https://docs.papra.app/self-hosting/configuration/) for all available options.

## Backup

The application data is stored in the persistent volume. Make sure to backup the PVC or the underlying storage to preserve your documents and database.
