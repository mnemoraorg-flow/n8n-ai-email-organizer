#!/bin/bash
# Runs once, on an empty database volume. Creates the unprivileged role n8n
# connects as, so n8n never holds superuser credentials.
set -e

if [ -z "${POSTGRES_NON_ROOT_USER:-}" ] || [ -z "${POSTGRES_NON_ROOT_PASSWORD:-}" ]; then
	echo "init-data.sh: POSTGRES_NON_ROOT_USER/PASSWORD not set, skipping role creation"
	exit 0
fi

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
	CREATE ROLE "${POSTGRES_NON_ROOT_USER}" WITH LOGIN PASSWORD '${POSTGRES_NON_ROOT_PASSWORD}';
	GRANT ALL PRIVILEGES ON DATABASE "${POSTGRES_DB}" TO "${POSTGRES_NON_ROOT_USER}";
	GRANT CREATE ON SCHEMA public TO "${POSTGRES_NON_ROOT_USER}";
EOSQL
