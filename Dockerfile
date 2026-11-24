# Deliberately minimal: n8n and its runners run from the official images in
# compose.yaml. This image only adds the workflow JSON, and it is only needed if
# you want the workflow imported into the database as a step of deployment.
#
# Usage (see .docs/deployment.md, "Import the workflow"):
#   docker compose -f compose.yaml -f compose.import.yaml run --rm workflow-import
ARG N8N_VERSION
FROM docker.n8n.io/n8nio/n8n:${N8N_VERSION}

COPY workflows /import/workflows
