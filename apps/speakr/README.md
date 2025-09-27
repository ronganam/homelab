# Speakr

A personal, self-hosted web application for transcribing audio recordings using AI.

## Secrets

Before applying the manifests, create the configuration secret with your API keys and admin password:

```bash
kubectl -n speakr create secret generic speakr-config \
  --from-literal=text_model_api_key='your_openrouter_api_key_here' \
  --from-literal=transcription_api_key='your_openai_api_key_here' \
  --from-literal=admin_password='your_strong_admin_password_here'
```

Replace the placeholders with your actual values. The `text_model_api_key` is for OpenRouter (or compatible service) for text generation tasks like summaries. The `transcription_api_key` is for OpenAI Whisper API. The `admin_password` sets the initial admin account password.

## Apply

Managed by Argo CD via `apps/speakr/kustomization.yaml`.

### Internal Access

This app is internal-only but accessible via Ingress for domain routing.

Service DNS inside the cluster:

```
http://speakr.speakr.svc.cluster.local:8899
```

Via Ingress (internal):

```
http://speakr.buildin.group
```

### Login

Use the admin credentials:

- Username: `admin`

- Email: `admin@example.com`

- Password: The value you set in the secret (`admin_password`)

### Notes

- Database: SQLite stored in the `speakr-instance` PVC.

- Uploads: Audio files stored in the `speakr-uploads` PVC (10Gi).

- Port: 8899 (internal).

- Timezone: Set to Asia/Jerusalem.

- For external access or changes (e.g., enabling registration, inquire mode), edit the `deployment.yaml` environment variables and reapply.

- Documentation: [Getting Started](https://murtaza-nasir.github.io/speakr/getting-started/)

- GitHub: [murtaza-nasir/speakr](https://github.com/murtaza-nasir/speakr)

- The deployment uses default settings for a simple setup with OpenAI Whisper and OpenRouter for text generation. Adjust env vars as needed for custom ASR or other configurations.
