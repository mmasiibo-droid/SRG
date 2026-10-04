-- Apply with a database administrator in a disposable PostgreSQL database.
-- Create login principals separately through the approved identity process.
DO $roles$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'srg_analytics') THEN
        CREATE ROLE srg_analytics NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'srg_steward') THEN
        CREATE ROLE srg_steward NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'srg_etl') THEN
        CREATE ROLE srg_etl NOLOGIN;
    END IF;
END
$roles$;

REVOKE ALL ON SCHEMA core, staging, warehouse FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA core, staging, warehouse FROM PUBLIC;

GRANT USAGE ON SCHEMA warehouse TO srg_analytics;
GRANT SELECT ON warehouse.fact_sales_line,
                warehouse.dim_product,
                warehouse.dim_store TO srg_analytics;

CREATE OR REPLACE VIEW warehouse.customer_masked_v AS
SELECT
    golden_customer_id,
    CASE WHEN phone_e164 IS NULL THEN NULL
         ELSE left(phone_e164, 4) || '******' || right(phone_e164, 4)
    END AS phone_masked,
    CASE WHEN email_normalized IS NULL THEN NULL
         ELSE left(email_normalized, 1) || '***@' ||
              split_part(email_normalized, '@', 2)
    END AS email_masked,
    district_code
FROM core.customer_contact_restricted;

REVOKE ALL ON core.customer_contact_restricted FROM PUBLIC, srg_analytics;
REVOKE ALL ON warehouse.customer_masked_v FROM PUBLIC;
GRANT USAGE ON SCHEMA warehouse TO srg_analytics;
GRANT SELECT ON warehouse.customer_masked_v TO srg_analytics;

GRANT USAGE ON SCHEMA core TO srg_steward;
GRANT SELECT ON core.customer, core.customer_source_link, core.product,
                core.product_source_link TO srg_steward;
GRANT UPDATE (status) ON core.customer TO srg_steward;
GRANT INSERT, UPDATE ON core.customer_source_link,
                       core.product_source_link TO srg_steward;
REVOKE ALL ON core.customer_contact_restricted FROM srg_steward;

GRANT USAGE ON SCHEMA staging, warehouse TO srg_etl;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA staging TO srg_etl;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA warehouse TO srg_etl;
REVOKE ALL ON core.customer_contact_restricted FROM srg_etl;

-- Test in a separate session after assigning an approved login to srg_analytics:
--   SET ROLE srg_analytics;
--   SELECT * FROM warehouse.customer_masked_v LIMIT 1; -- must succeed
--   SELECT * FROM core.customer_contact_restricted LIMIT 1; -- must fail: permission denied
--   RESET ROLE;
-- Save the actual psql output and tested database/role as evidence. This script
-- does not fabricate a successful negative-access test.
