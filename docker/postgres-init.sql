-- PostgreSQL initialization script
-- This script runs automatically when the database is first created
-- It creates the required btree_gin extension with superuser privileges

-- Connect to the docuseal_dev database
\c docuseal_dev

-- Create the btree_gin extension
-- This requires superuser privileges, which postgres user has
CREATE EXTENSION IF NOT EXISTS btree_gin;

-- Optionally grant usage to the postgres user (it already has it, but this is explicit)
-- No additional grants needed as postgres is the owner
