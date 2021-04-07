# list all tables
\dt+

# list all schemas
\dn

# set schema
SET SEARCH_PATH TO $schema-name;

# show current schemas
SHOW SEARCH_PATH;

# list tables that match table name regex
SELECT table_schema, table_name FROM information_schema.tables WHERE table_name ILIKE '%abc%';