## Deployment: container

- `make image` builds the production image; `make up` runs it locally with `compose.yaml`.
- Releases deploy automatically to **staging**; **production** waits for a human to approve
  the GitHub environment. Agents never run `make deploy` for production themselves.
- The image runs as a non-root user and exposes `/health`; keep both. Secrets come from the
  platform's environment, never from the image or the repo.
