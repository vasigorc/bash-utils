-- select all columns in a database that match 'name'
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'company' 
  AND column_name LIKE '%name%';
