-- PostgreSQL initialization script
-- This script runs automatically when the database is first created
-- It creates the required btree_gin extension with superuser privileges
--
-- Note: This script runs in the context of the database specified by POSTGRES_DB
-- environment variable, so no need to explicitly connect

-- Create the btree_gin extension
-- This requires superuser privileges, which postgres user has
CREATE EXTENSION IF NOT EXISTS btree_gin;
