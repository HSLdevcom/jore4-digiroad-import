DO $$
DECLARE
    tables_to_truncate text;
BEGIN
    SELECT string_agg(format('%I.%I', namespace.nspname, class.relname), ', ')
    INTO tables_to_truncate
    FROM pg_class class
    JOIN pg_namespace namespace ON namespace.oid = class.relnamespace
    WHERE class.relkind IN ('r', 'p')
      AND namespace.nspname NOT IN ('public', 'pg_catalog', 'information_schema')
      AND namespace.nspname !~ '^pg_toast'
      AND class.relname <> 'flyway_schema_history'
      AND NOT EXISTS (
          SELECT 1
          FROM pg_depend dependency
          WHERE dependency.classid = 'pg_class'::regclass
            AND dependency.objid = class.oid
            AND dependency.deptype = 'e'
      );

    IF tables_to_truncate IS NOT NULL THEN
        EXECUTE 'TRUNCATE TABLE ' || tables_to_truncate;
    END IF;
END
$$;