## Deployment: container

- `make image` builds the production image; `make up` runs it locally with `compose.yaml`. <!-- kept: none -->
- The image runs as a non-root user and exposes `/health`; keep both. Secrets come from the
  platform's environment, never from the image or the repo. <!-- kept: word -->
