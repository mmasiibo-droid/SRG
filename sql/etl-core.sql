-- Run after schema.sql in a development database. Stage files through an
-- approved encrypted landing process; never point COPY at an untrusted export.
BEGIN;

-- Illustrative normalization. Production should parse dates using an explicit
-- per-source format contract and quarantine ambiguous values.
CREATE TEMP TABLE valid_sales_line ON COMMIT DROP AS
SELECT
    s.batch_id,
    s.source_system,
    s.source_order_id,
    s.source_line_number::INTEGER AS line_number,
    s.source_customer_id,
    upper(btrim(s.source_sku)) AS canonical_sku,
    s.source_store_code,
    CASE
        WHEN s.order_timestamp_raw ~ '^\d{4}-\d{2}-\d{2}$'
         AND to_char(to_date(s.order_timestamp_raw, 'YYYY-MM-DD'), 'YYYY-MM-DD') = s.order_timestamp_raw
        THEN to_date(s.order_timestamp_raw, 'YYYY-MM-DD')
        ELSE NULL
    END AS order_date,
    btrim(s.quantity_raw)::NUMERIC(14,3) AS quantity,
    btrim(s.unit_price_raw)::NUMERIC(14,2) AS unit_price,
    upper(btrim(s.currency_raw)) AS currency_code,
    nullif(btrim(s.payment_reference_raw), '') AS payment_reference,
    upper(btrim(s.channel_raw)) AS channel_code,
    nullif(btrim(s.return_reason_raw), '') AS return_reason
FROM staging.sales_line AS s
WHERE btrim(s.source_line_number) ~ '^\d+$'
  AND btrim(s.quantity_raw) ~ '^-?\d+(\.\d+)?$'
  AND btrim(s.unit_price_raw) ~ '^\d+(\.\d+)?$'
  AND upper(btrim(s.currency_raw)) ~ '^[A-Z]{3}$';

-- Inspect invalid and ambiguous rows before advancing the batch watermark.
SELECT s.*
FROM staging.sales_line AS s
LEFT JOIN valid_sales_line AS v
  ON v.batch_id = s.batch_id
 AND v.source_system = s.source_system
 AND v.source_order_id = s.source_order_id
 AND v.line_number::TEXT = s.source_line_number
WHERE v.batch_id IS NULL OR v.order_date IS NULL;

-- Type-2 example: close the previous version only when governed attributes
-- actually change; use one source-consistent timestamp for the batch.
-- Populate warehouse.dim_product first from steward-approved core.product rows.
-- Similar logic applies to warehouse.dim_store; do not treat current names as
-- historical truth without an effective-dated source.

-- Resolve product/store surrogate keys as of the order's business date.
INSERT INTO warehouse.fact_sales_line (
    source_system, source_order_id, source_line_number, order_date,
    product_sk, store_sk, source_customer_id, quantity, net_amount,
    currency_code, channel_code, batch_id
)
SELECT
    v.source_system,
    v.source_order_id,
    v.line_number,
    v.order_date,
    dp.product_sk,
    ds.store_sk,
    v.source_customer_id,
    v.quantity,
    round(v.quantity * v.unit_price, 2),
    v.currency_code,
    v.channel_code,
    v.batch_id
FROM valid_sales_line AS v
JOIN warehouse.dim_product AS dp
  ON dp.canonical_sku = v.canonical_sku
 AND v.order_date::TIMESTAMPTZ >= dp.valid_from
 AND (dp.valid_to IS NULL OR v.order_date::TIMESTAMPTZ < dp.valid_to)
JOIN warehouse.dim_store AS ds
  ON ds.store_code = v.source_store_code
 AND v.order_date::TIMESTAMPTZ >= ds.valid_from
 AND (ds.valid_to IS NULL OR v.order_date::TIMESTAMPTZ < ds.valid_to)
ON CONFLICT (source_system, source_order_id, source_line_number)
DO UPDATE SET
    order_date = EXCLUDED.order_date,
    product_sk = EXCLUDED.product_sk,
    store_sk = EXCLUDED.store_sk,
    source_customer_id = EXCLUDED.source_customer_id,
    quantity = EXCLUDED.quantity,
    net_amount = EXCLUDED.net_amount,
    currency_code = EXCLUDED.currency_code,
    channel_code = EXCLUDED.channel_code,
    batch_id = EXCLUDED.batch_id,
    loaded_at = now();

-- Before committing/marking the batch complete, reconcile counts, currency
-- control totals, rejected rows, and source-specific returns. A mismatch must
-- leave the watermark unchanged and route the batch to investigation.
COMMIT;
