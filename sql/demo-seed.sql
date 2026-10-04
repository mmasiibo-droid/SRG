-- Synthetic-only setup for the disposable savanna_edm_demo database.
-- This script does not insert customer or transaction data.
BEGIN;

DELETE FROM staging.sales_line
WHERE batch_id = '11111111-1111-4111-8111-111111111111';

INSERT INTO core.product (canonical_sku, product_name, category_code, unit_code)
VALUES
    ('SNK-001', 'Roasted groundnuts', 'Snacks', 'kg'),
    ('DRK-002', 'Passion juice', 'Beverages', 'L'),
    ('DRK-003', 'Mango juice', 'Beverages', 'L'),
    ('HOM-004', 'Sample storage basket', 'Household', 'each'),
    ('GRN-005', 'Green beans', 'Produce', 'kg')
ON CONFLICT (canonical_sku) DO NOTHING;

INSERT INTO core.store (store_code, district_code, channel_code)
VALUES
    ('KLA01', 'Kampala', 'POS'),
    ('GUL01', 'Gulu', 'POS'),
    ('JIN01', 'Jinja', 'POS'),
    ('MBR01', 'Mbarara', 'POS')
ON CONFLICT (store_code) DO NOTHING;

INSERT INTO warehouse.dim_product (
    canonical_sku, product_name, category_code, unit_code,
    valid_from, valid_to, is_current
)
VALUES
    ('SNK-001', 'Roasted groundnuts', 'Snacks', 'kg', '2026-01-01 00:00:00+00', NULL, true),
    ('DRK-002', 'Passion juice', 'Beverages', 'L', '2026-01-01 00:00:00+00', NULL, true),
    ('DRK-003', 'Mango juice', 'Beverages', 'L', '2026-01-01 00:00:00+00', NULL, true),
    ('HOM-004', 'Sample storage basket', 'Household', 'each', '2026-01-01 00:00:00+00', NULL, true),
    ('GRN-005', 'Green beans', 'Produce', 'kg', '2026-01-01 00:00:00+00', NULL, true)
ON CONFLICT (canonical_sku, valid_from) DO NOTHING;

INSERT INTO warehouse.dim_store (
    store_code, district_code, channel_code,
    valid_from, valid_to, is_current
)
VALUES
    ('KLA01', 'Kampala', 'POS', '2026-01-01 00:00:00+00', NULL, true),
    ('GUL01', 'Gulu', 'POS', '2026-01-01 00:00:00+00', NULL, true),
    ('JIN01', 'Jinja', 'POS', '2026-01-01 00:00:00+00', NULL, true),
    ('MBR01', 'Mbarara', 'POS', '2026-01-01 00:00:00+00', NULL, true)
ON CONFLICT (store_code, valid_from) DO NOTHING;

COMMIT;
