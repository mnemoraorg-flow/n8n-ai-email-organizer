# Usage

How to use an instance of the email organizer once it is running. For standing
one up, see [deployment.md](deployment.md).

## Open the editor

Go to `https://<SUBDOMAIN>.<DOMAIN_NAME>`, the URL you configured in `.env`. If
Caddy is using its internal CA (`TLS_ACME` empty), the browser warns that the
certificate is not trusted. That is expected outside a real deployment; see
[deployment.md](deployment.md#certificates).

Sign in with the account you created at first launch.

## What the workflow does

```
Incoming email
      |
      v
  [ Trigger ]  polls or receives the mailbox
      |
      v
 [ Classify ]  asks the AI which category the email is
      |
      v
  [ Route ]    applies the category's label / folder
```

The workflow ships **deactivated**. Activate it after the credentials below are
in place, or nothing runs.

## Attach credentials

Each workflow needs an email credential before it can run. Open the workflow,
then open the trigger node and create a credential there:

| Provider | What you need                                                   |
| -------- | --------------------------------------------------------------- |
| IMAP     | Host, port (usually 993), username, password or app password    |
| Gmail    | A Google Cloud OAuth client, plus the redirect URL n8n shows you |
| Outlook  | A Microsoft Entra app registration and its client secret        |

Use an app password rather than the account password where the provider offers
one. Credentials are encrypted with `N8N_ENCRYPTION_KEY`, so they stop working if
that key changes.

## The AI credential

The classifier reads its API key from the environment, not from n8n's credential
store:

```
{{ $env.OPENAI_API_KEY }}
```

Set `OPENAI_API_KEY` in `.env` and restart n8n to change it:

```bash
docker compose -f compose.yaml -f compose.tls.yaml up -d n8n
```

Because env access is enabled for nodes, anyone who can open the editor can read
that key. Treat editor access as equivalent to having your AI provider key.

## Run it on one email

1. Open the workflow and select **Execute workflow**.
2. The trigger returns the pending emails and the rest of the workflow runs on
   them.
3. Inspect the output on the classification node before trusting it with real
   mail: open the node, look at the JSON tab, and check the category matches what
   you expect.

Do this before activating. A misconfigured classifier will relabel every new
email.

## Categories

The workflow routes on a fixed list of categories. To change them, edit the list
in the classification node, then update the routing node's conditions to match.
Make both changes together: a category with no route is silently dropped.

## Check that it is running

- **Executions** in the left sidebar lists every run, green for success and red
  for failure. This is the first place to look when mail stops being sorted.
- A workflow that is present but always idle is usually deactivated, or its
  trigger has no credential.

## Save a change back to the repository

Changes made in the editor live in the database, not in this repository. To keep
them:

1. Open the workflow menu (the three dots) and choose **Download**.
2. Save the file over the matching file in `workflows/`.
3. Commit it.

Otherwise the next deploy from `workflows/` overwrites the workflow with the old
version.
