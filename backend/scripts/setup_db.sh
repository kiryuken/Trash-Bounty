#!/bin/bash
set -e

MIGRATIONS_DIR="/mnt/c/Users/ASUS/Code/temporary_assignment/backend/internal/db/migrations"
DB_USER="trashbounty"
DB_PASSWORD="trashbounty_secret_2026"
DB_NAME="trashbounty_db"

echo "=== Creating user and database ==="
sudo -u postgres psql <<EOSQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN
    CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';
    RAISE NOTICE 'User ${DB_USER} created.';
  ELSE
    ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';
    RAISE NOTICE 'User ${DB_USER} already exists, password updated.';
  END IF;
END
\$\$;
EOSQL

sudo -u postgres psql <<EOSQL
SELECT 'CREATE DATABASE ${DB_NAME} OWNER ${DB_USER}'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${DB_NAME}')\gexec
EOSQL

sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"

echo ""
echo "=== Running migrations ==="
for f in $(ls ${MIGRATIONS_DIR}/*.sql | sort); do
  echo "--> Applying: $(basename $f)"
  sudo -u postgres psql -d "${DB_NAME}" -f "$f"
done

echo ""
echo "=== Granting schema permissions ==="
sudo -u postgres psql -d "${DB_NAME}" <<EOSQL
GRANT USAGE ON SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${DB_USER};
EOSQL

echo ""
echo "=== Done! Testing connection ==="
PGPASSWORD="${DB_PASSWORD}" psql -h 127.0.0.1 -U "${DB_USER}" -d "${DB_NAME}" -c "\dt" 2>&1
