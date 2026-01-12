# Infisical

Infisical is an open-source secret management platform.

## Configuration

This deployment uses the `infisical-standalone` Helm chart.

### Files

- `Chart.yaml`: Wrapper chart depending on `infisical-standalone`.
- `app.yaml`: ArgoCD application definition.
- `values.yaml`: Configuration for the chart (Ingress, Persistence, etc.).
- `create-secret.sh`: Helper script to generate the required `infisical-secrets`.

## Setup

Before deploying (or syncing via ArgoCD), you **must** create the required secrets.

1.  Run the secret creation script:
    ```bash
    ./create-secret.sh
    ```
    This will generate `ENCRYPTION_KEY` and `AUTH_SECRET`, and configure the connection strings for the bundled PostgreSQL and Redis instances.

2.  Sync the application in ArgoCD.

## Access

The application will be available at `https://infisical.buildin.group`.

## Notes

-   **Database**: Uses the bundled PostgreSQL (non-HA).
-   **Redis**: Uses the bundled Redis (non-HA).
-   **Ingress**: Configured for `nginx` class.