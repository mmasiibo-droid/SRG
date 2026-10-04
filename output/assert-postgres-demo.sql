DO $$
BEGIN
    IF (
        SELECT count(*)
        FROM warehouse.fact_sales_line
        WHERE source_order_id IN ('P001', 'P003', 'P004', 'P005', 'P006', 'P007', 'P008')
    ) <> 7 THEN
        RAISE EXCEPTION 'Expected exactly seven accepted synthetic sales lines';
    END IF;

    IF (
        SELECT count(*)
        FROM warehouse.fact_sales_line
        WHERE source_order_id = 'P002'
    ) <> 0 THEN
        RAISE EXCEPTION 'Ambiguous-date sales line P002 must not load to the fact';
    END IF;

    IF (
        SELECT quantity
        FROM warehouse.fact_sales_line
        WHERE source_order_id = 'P005'
    ) <> -1 THEN
        RAISE EXCEPTION 'Documented return quantity must remain negative';
    END IF;

    IF (
        SELECT count(*)
        FROM staging.sales_line
        WHERE batch_id = '11111111-1111-4111-8111-111111111111'
    ) <> 7 THEN
        RAISE EXCEPTION 'Expected seven staged source rows for the fixed demo batch';
    END IF;
END
$$;

SELECT 'synthetic sales fact rows' AS check_name, count(*) AS result
FROM warehouse.fact_sales_line
WHERE source_order_id IN ('P001', 'P003', 'P004', 'P005', 'P006', 'P007', 'P008')
UNION ALL
SELECT 'ambiguous-date P002 fact rows', count(*)
FROM warehouse.fact_sales_line
WHERE source_order_id = 'P002'
UNION ALL
SELECT 'negative return rows', count(*)
FROM warehouse.fact_sales_line
WHERE source_order_id = 'P005' AND quantity = -1;
