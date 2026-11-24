# Deployment

Standing up the self-hosted n8n instance for the email organizer on a Linux
server. For using the instance afterwards, see [usage.md](usage.md).

## What runs

| Service      | Image                       | Role                                                       |
| ------------ | --------------------------- | ---------------------------------------------------------- |
| `postgres`   | `postgres:18`               | n8n's database. Healthchecked before n8n starts.           |
| `n8n`        | `docker.n8n.io/n8nio/n8n`   | The editor, webhooks, and workflow execution.              |
| `n8n-runner` | `n8nio/runners`             | Runs Code node JavaScript outside the n8n process.         |
| `caddy`      | `caddy:2.11.9`              | HTTPS on 80/443, forwards to n8n. Only in the TLS override. |

n8n never publishes a port. Only Caddy is reachable from the host.

## Requirements

- Docker with the Compose plugin on a Linux server.
- A hostname whose DNS `A` record points at the server, if you want a publicly
  trusted certificate.
- Ports 80 and 443 reachable from the internet for that certificate.

## First deploy

```bash
cp .env.example .env
```

Fill in `.env`. Generate the two secrets rather than inventing them:

```bash
openssl rand -hex 32   # N8N_ENCRYPTION_KEY
openssl rand -hex 32   # RUNNERS_AUTH_TOKEN
```

Set both Postgres passwords and `OPENAI_API_KEY` too. Then start the stack:

```bash
mkdir -p local-files
docker compose -f compose.yaml -f compose.tls.yaml up -d
docker compose -f compose.yaml -f compose.tls.yaml logs -f n8n
```

Watch the logs until n8n reports it is ready, then open
`https://<SUBDOMAIN>.<DOMAIN_NAME>`. **Create the owner account immediately:** the
first account to sign up becomes the instance owner.

## Certificates

`TLS_ACME` in `.env` decides where the certificate comes from.

| `TLS_ACME`      | Effect                                                           |
| --------------- | ---------------------------------------------------------------- |
| empty (default) | Caddy's internal CA. Works without public DNS; browsers warn.    |
| `true`          | Let's Encrypt. Needs public DNS and 80/443 open.                 |
| anything else   | Broken. The value is concatenated in front of a Caddy directive. |

That last row is why [Caddyfile](../.infra/caddy/Caddyfile) glues `{$TLS_ACME}`
to `local_certs`: an empty value has to produce empty output. Caddy's Caddyfile
adapter has no way to branch on a variable, so `true` is prepended as
`truelocal_certs`, which is why any other value fails validation.

Switching to `true` after the fact works; Caddy requests the certificate on its
next start.

## The encryption key is the account

`N8N_ENCRYPTION_KEY` encrypts every saved credential. Losing or changing it makes
the credentials in the database unreadable and they have to be re-entered.

It lives in `.env` rather than the volume on purpose, so a recreated volume does
not orphan credentials. Back `.env` up with the database dump, and never commit
it.

## Import the workflow

Workflows live in `workflows/`, one JSON file each:

```bash
docker compose -f compose.yaml -f compose.import.yaml run --rm workflow-import
```

Re-running the same command is how workflow updates ship: n8n overwrites
workflows whose ID already exists. Imported workflows arrive **deactivated**, so
activate them in the UI once their credentials are attached.

## Back up and restore

Two things hold state and both matter:

- `db_data`: workflows, executions, encrypted credentials.
- `n8n_data`: instance settings, logs, and any key n8n wrote before
  `N8N_ENCRYPTION_KEY` was set in `.env`.

```bash
docker compose exec -T postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > n8n-backup.sql

docker compose stop n8n
docker run --rm -v n8n-ai-email-organizer_n8n_data:/data -v "$PWD":/backup \
  alpine tar czf /backup/n8n_data.tar.gz -C /data .
docker compose start n8n
```

> **Warning:** never run `docker compose down -v`. It deletes `db_data` and
> `n8n_data`. Losing `n8n_data` alongside a restored database is what makes
> credentials unreadable.

## Upgrading

n8n migrates its database forward on startup, so the backup above is your way
back. To move versions:

1. Change `N8N_VERSION` in `.env`.
2. Read the n8n breaking-changes notes for any major version you cross.
3. Take a backup.
4. `docker compose -f compose.yaml -f compose.tls.yaml up -d`.
5. Open **Settings > Migration Report** in the UI.

## Repository layout

| Path                            | Purpose                                             |
| ------------------------------- | --------------------------------------------------- |
| `compose.yaml`                  | Base stack: postgres, n8n, task runner.             |
| `compose.tls.yaml`              | Adds Caddy and the HTTPS port mapping.              |
| `compose.import.yaml`           | One-off job that imports `workflows/*.json`.        |
| `Dockerfile`                    | Adds workflow JSON to the official n8n image.       |
| `.infra/caddy/Caddyfile`        | TLS and headers for the reverse proxy.              |
| `.infra/postgres/init-data.sh`  | Creates the unprivileged role n8n connects as.      |
| `workflows/`                    | Workflow JSON, one file per workflow.               |
| `.docs/`                        | This documentation.                                 |

## Configuration choices worth knowing

- n8n connects to Postgres as `POSTGRES_NON_ROOT_USER`, not the superuser. The
  superuser is only used to create the database and role on first boot.
- `.infra/postgres/init-data.sh` runs once, on an empty volume. Changing it later
  has no effect without dropping the database volume.
- `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` is deliberate: workflows read
  `OPENAI_API_KEY` from the environment. Anything with editor access can read
  that key.
- `N8N_RESTRICT_FILE_ACCESS_TO=/files` limits the filesystem nodes to the
  `local-files/` directory, which is bind-mounted to `/files`.
- The `Dockerfile` only carries workflow JSON into the import job. It is not the
  application image.
