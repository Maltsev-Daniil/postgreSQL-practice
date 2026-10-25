#!/bin/sh

set -eu
DB_NAME="magazine"
DB_LOGIN="nitsir"

dropdb --if-exists $DB_NAME
sudo -u postgres psql -d template1 -c 'ALTER ROLE nitsir CREATEDB;'
createdb $DB_NAME
psql -v ON_ERROR_STOP=1 -U $DB_LOGIN -d $DB_NAME -f schema.sql
psql -v ON_ERROR_STOP=1 -U $DB_LOGIN -d $DB_NAME -f seed.sql
.venv/bin/python3 generate_huge_data.py --dbname "$DB_NAME"