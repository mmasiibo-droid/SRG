BEGIN;

CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS warehouse;

CREATE TABLE IF NOT EXISTS core.customer (
    golden_customer_id UUID PRIMARY KEY,
    status TEXT NOT NULL CHECK (status IN ('active', 'provisional', 'merged', 'suppressed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS core.customer_source_link (
    source_system TEXT NOT NULL,
    source_record_id TEXT NOT NULL,
    golden_customer_id UUID NOT NULL REFERENCES core.customer(golden_customer_id),
    link_status TEXT NOT NULL CHECK (link_status IN ('provisional', 'reviewed', 'rejected')),
    match_rule_version TEXT NOT NULL,
    confidence NUMERIC(5,2),
    reviewed_by TEXT,
    reviewed_at TIMESTAMPTZ,
    PRIMARY KEY (source_system, source_record_id),
    CHECK (confidence IS NULL OR confidence BETWEEN 0 AND 100)
);

CREATE TABLE IF NOT EXISTS core.customer_contact_restricted (
    golden_customer_id UUID PRIMARY KEY REFERENCES core.customer(golden_customer_id),
    display_name TEXT,
    phone_e164 TEXT,
    email_normalized TEXT,
    district_code TEXT,
    consent_state JSONB NOT NULL DEFAULT '{}'::jsonb,
    source_provenance JSONB NOT NULL DEFAULT '{}'::jsonb,
    valid_from TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_to TIMESTAMPTZ,
    CHECK (valid_to IS NULL OR valid_to > valid_from)
);

CREATE TABLE IF NOT EXISTS core.product (
    product_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    canonical_sku TEXT NOT NULL UNIQUE,
    product_name TEXT NOT NULL,
    category_code TEXT NOT NULL,
    unit_code TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT true,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS core.product_source_link (
    source_system TEXT NOT NULL,
    source_sku TEXT NOT NULL,
    product_id BIGINT NOT NULL REFERENCES core.product(product_id),
    reviewed_by TEXT,
    reviewed_at TIMESTAMPTZ,
    PRIMARY KEY (source_system, source_sku)
);

CREATE TABLE IF NOT EXISTS core.store (
    store_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    store_code TEXT NOT NULL UNIQUE,
    district_code TEXT NOT NULL,
    channel_code TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS core.sales_order (
    order_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_system TEXT NOT NULL,
    source_order_id TEXT NOT NULL,
    store_id BIGINT REFERENCES core.store(store_id),
    golden_customer_id UUID REFERENCES core.customer(golden_customer_id),
    ordered_at TIMESTAMPTZ NOT NULL,
    currency_code CHAR(3) NOT NULL,
    channel_code TEXT NOT NULL,
    UNIQUE (source_system, source_order_id)
);

CREATE TABLE IF NOT EXISTS core.order_line (
    order_id BIGINT NOT NULL REFERENCES core.sales_order(order_id),
    line_number INTEGER NOT NULL CHECK (line_number > 0),
    product_id BIGINT NOT NULL REFERENCES core.product(product_id),
    quantity NUMERIC(14,3) NOT NULL,
    unit_price NUMERIC(14,2) NOT NULL CHECK (unit_price >= 0),
    return_reason TEXT,
    PRIMARY KEY (order_id, line_number),
    CHECK (quantity >= 0 OR NULLIF(btrim(return_reason), '') IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS core.payment (
    payment_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES core.sales_order(order_id),
    tender_type TEXT NOT NULL,
    provider_reference TEXT,
    paid_amount NUMERIC(14,2) NOT NULL CHECK (paid_amount >= 0),
    currency_code CHAR(3) NOT NULL,
    UNIQUE (tender_type, provider_reference)
);

CREATE TABLE IF NOT EXISTS core.supplier (
    supplier_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    supplier_code TEXT NOT NULL UNIQUE,
    supplier_name TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS core.supplier_product (
    supplier_id BIGINT NOT NULL REFERENCES core.supplier(supplier_id),
    product_id BIGINT NOT NULL REFERENCES core.product(product_id),
    supplier_sku TEXT NOT NULL,
    pack_size NUMERIC(14,3) NOT NULL CHECK (pack_size > 0),
    unit_code TEXT NOT NULL,
    PRIMARY KEY (supplier_id, product_id, supplier_sku)
);

CREATE TABLE IF NOT EXISTS staging.sales_line (
    batch_id UUID NOT NULL,
    source_system TEXT NOT NULL,
    source_order_id TEXT NOT NULL,
    source_line_number TEXT NOT NULL,
    source_customer_id TEXT,
    source_sku TEXT NOT NULL,
    source_store_code TEXT NOT NULL,
    order_timestamp_raw TEXT NOT NULL,
    quantity_raw TEXT NOT NULL,
    unit_price_raw TEXT NOT NULL,
    currency_raw TEXT NOT NULL,
    payment_reference_raw TEXT,
    channel_raw TEXT NOT NULL,
    return_reason_raw TEXT,
    landed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (batch_id, source_system, source_order_id, source_line_number)
);

CREATE TABLE IF NOT EXISTS warehouse.dim_product (
    product_sk BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    canonical_sku TEXT NOT NULL,
    product_name TEXT NOT NULL,
    category_code TEXT NOT NULL,
    unit_code TEXT NOT NULL,
    valid_from TIMESTAMPTZ NOT NULL,
    valid_to TIMESTAMPTZ,
    is_current BOOLEAN NOT NULL,
    UNIQUE (canonical_sku, valid_from),
    CHECK ((is_current AND valid_to IS NULL) OR (NOT is_current AND valid_to IS NOT NULL))
);

CREATE UNIQUE INDEX IF NOT EXISTS dim_product_one_current
    ON warehouse.dim_product (canonical_sku) WHERE is_current;

CREATE TABLE IF NOT EXISTS warehouse.dim_store (
    store_sk BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    store_code TEXT NOT NULL,
    district_code TEXT NOT NULL,
    channel_code TEXT NOT NULL,
    valid_from TIMESTAMPTZ NOT NULL,
    valid_to TIMESTAMPTZ,
    is_current BOOLEAN NOT NULL,
    UNIQUE (store_code, valid_from),
    CHECK ((is_current AND valid_to IS NULL) OR (NOT is_current AND valid_to IS NOT NULL))
);

CREATE UNIQUE INDEX IF NOT EXISTS dim_store_one_current
    ON warehouse.dim_store (store_code) WHERE is_current;

CREATE TABLE IF NOT EXISTS warehouse.fact_sales_line (
    source_system TEXT NOT NULL,
    source_order_id TEXT NOT NULL,
    source_line_number INTEGER NOT NULL,
    order_date DATE NOT NULL,
    product_sk BIGINT NOT NULL REFERENCES warehouse.dim_product(product_sk),
    store_sk BIGINT NOT NULL REFERENCES warehouse.dim_store(store_sk),
    source_customer_id TEXT,
    quantity NUMERIC(14,3) NOT NULL,
    net_amount NUMERIC(14,2) NOT NULL,
    currency_code CHAR(3) NOT NULL,
    channel_code TEXT NOT NULL,
    batch_id UUID NOT NULL,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (source_system, source_order_id, source_line_number)
);

COMMIT;
