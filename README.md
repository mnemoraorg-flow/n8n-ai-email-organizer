# n8n AI Email Organizer

Automatically organizes incoming emails into the right categories, keeping your
inbox clean, organized, and easier to manage without the manual work.

This repository ships the whole self-hosted stack: n8n, PostgreSQL, a task
runner for the Code node, and a TLS-terminating Caddy proxy, plus the workflow
JSON that does the sorting.

## Start here

- **[Usage](.docs/usage.md)** — you have a running instance and want to use it:
  credentials, activating the workflow, testing one email, changing categories.
- **[Deployment](.docs/deployment.md)** — you are standing the instance up:
  `.env`, certificates, importing the workflow, backups, upgrades.

## Quick start

```bash
cp .env.example .env         # then fill in every CHANGE_ME value
mkdir -p local-files
docker compose -f compose.yaml -f compose.tls.yaml up -d
```

Full steps, including the secrets to generate and why, are in
[Deployment](.docs/deployment.md#first-deploy).

## Layout

```
compose.yaml            base stack: postgres, n8n, task runner
compose.tls.yaml        adds Caddy and HTTPS
compose.import.yaml     one-off job to load workflows/*.json
Dockerfile              carries workflow JSON into that import job
.env.example            configuration template; copy to .env
.infra/caddy/           Caddyfile
.infra/postgres/        database init script
.docs/                  usage and deployment documentation
workflows/              workflow JSON, one file each
```

## Two things that will bite you

- **`N8N_ENCRYPTION_KEY` is the account.** Lose it and every saved credential
  becomes unreadable. It lives in `.env`, which is gitignored.
- **Never run `docker compose down -v`.** It deletes the database and the n8n
  data volume.

Both are covered in [Deployment](.docs/deployment.md).
