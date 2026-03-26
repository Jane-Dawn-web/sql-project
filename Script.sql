DROP MATERIALIZED VIEW IF EXISTS mv_monthly_sales;
DROP VIEW IF EXISTS vw_daily_store_sales;
DROP VIEW IF EXISTS vw_promo_effectiveness;
DROP VIEW IF EXISTS vw_low_stock_products;

DROP FUNCTION IF EXISTS get_store_revenue(INT, DATE, DATE);
DROP FUNCTION IF EXISTS get_low_stock_products(INT, DATE);

DROP TABLE IF EXISTS sales;
DROP TABLE IF EXISTS inventory_snapshots;
DROP TABLE IF EXISTS promotions;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS stores;

CREATE TABLE stores (
    store_id      SERIAL PRIMARY KEY,
    store_name    VARCHAR(100) NOT NULL,
    city          VARCHAR(80) NOT NULL,
    region        VARCHAR(80) NOT NULL,
    format        VARCHAR(30) NOT NULL
);

CREATE TABLE products (
    product_id    SERIAL PRIMARY KEY,
    sku           VARCHAR(40) NOT NULL UNIQUE,
    product_name  VARCHAR(120) NOT NULL,
    category      VARCHAR(60) NOT NULL,
    brand         VARCHAR(60) NOT NULL,
    cost_price    NUMERIC(12,2) NOT NULL CHECK (cost_price >= 0)
);

CREATE TABLE promotions (
    promo_id       SERIAL PRIMARY KEY,
    promo_name     VARCHAR(120) NOT NULL,
    start_dt       DATE NOT NULL,
    end_dt         DATE NOT NULL,
    discount_pct   NUMERIC(5,2) NOT NULL CHECK (discount_pct >= 0 AND discount_pct <= 100),
    CHECK (end_dt >= start_dt)
);

CREATE TABLE sales (
    sale_id        BIGSERIAL PRIMARY KEY,
    sale_dt        DATE NOT NULL,
    store_id       INT NOT NULL REFERENCES stores(store_id),
    product_id     INT NOT NULL REFERENCES products(product_id),
    qty            INT NOT NULL CHECK (qty > 0),
    sale_price     NUMERIC(12,2) NOT NULL CHECK (sale_price >= 0),
    promo_id       INT NULL REFERENCES promotions(promo_id)
);

CREATE TABLE inventory_snapshots (
    snapshot_id    BIGSERIAL PRIMARY KEY,
    snapshot_dt    DATE NOT NULL,
    store_id       INT NOT NULL REFERENCES stores(store_id),
    product_id     INT NOT NULL REFERENCES products(product_id),
    stock_qty      INT NOT NULL CHECK (stock_qty >= 0),
    UNIQUE (snapshot_dt, store_id, product_id)
);

-- 2. INDEXES
CREATE INDEX idx_sales_sale_dt
    ON sales(sale_dt);

CREATE INDEX idx_sales_store_product_dt
    ON sales(store_id, product_id, sale_dt);

CREATE INDEX idx_sales_promo_id
    ON sales(promo_id);

CREATE INDEX idx_inventory_store_product_dt
    ON inventory_snapshots(store_id, product_id, snapshot_dt);

CREATE INDEX idx_products_category_brand
    ON products(category, brand);

-- 3. DATA
INSERT INTO stores (store_name, city, region, format) VALUES
('ТРЦ Центр', 'Москва', 'Центр', 'mall'),
('Галерея', 'Санкт-Петербург', 'Северо-Запад', 'mall'),
('Семейный', 'Казань', 'Поволжье', 'street');

INSERT INTO products (sku, product_name, category, brand, cost_price) VALUES
('SKU-1001', 'Футболка basic', 'Футболки', 'UrbanLine', 550.00),
('SKU-1002', 'Джинсы slim', 'Джинсы', 'UrbanLine', 1400.00),
('SKU-1003', 'Худи oversize', 'Худи', 'StreetMood', 1700.00),
('SKU-1004', 'Куртка демисезонная', 'Верхняя одежда', 'StreetMood', 3200.00),
('SKU-1005', 'Рубашка casual', 'Рубашки', 'CityWear', 1100.00),
('SKU-1006', 'Брюки classic', 'Брюки', 'CityWear', 1500.00);

INSERT INTO promotions (promo_name, start_dt, end_dt, discount_pct) VALUES
('Winter Sale', '2026-01-10', '2026-01-31', 15.00),
('Weekend Promo', '2026-02-06', '2026-02-08', 10.00),
('Spring Start', '2026-03-01', '2026-03-10', 12.00);

INSERT INTO sales (sale_dt, store_id, product_id, qty, sale_price, promo_id) VALUES
('2026-01-12', 1, 1, 12, 899.00, 1),
('2026-01-12', 1, 2, 5, 2499.00, 1),
('2026-01-13', 2, 1, 8, 899.00, 1),
('2026-01-13', 2, 3, 4, 2990.00, 1),
('2026-01-14', 3, 4, 2, 5490.00, 1),
('2026-01-15', 1, 5, 7, 1890.00, NULL),
('2026-01-16', 2, 6, 6, 2790.00, NULL),
('2026-02-07', 1, 3, 6, 3190.00, 2),
('2026-02-07', 2, 2, 3, 2690.00, 2),
('2026-02-08', 3, 1, 10, 990.00, 2),
('2026-03-02', 1, 4, 3, 5690.00, 3),
('2026-03-03', 2, 5, 5, 1990.00, 3),
('2026-03-05', 3, 6, 4, 2890.00, 3);

INSERT INTO inventory_snapshots (snapshot_dt, store_id, product_id, stock_qty) VALUES
('2026-01-12', 1, 1, 15),
('2026-01-12', 1, 2, 9),
('2026-01-13', 2, 1, 10),
('2026-01-13', 2, 3, 5),
('2026-01-14', 3, 4, 3),
('2026-01-15', 1, 5, 12),
('2026-01-16', 2, 6, 8),
('2026-02-07', 1, 3, 7),
('2026-02-07', 2, 2, 4),
('2026-02-08', 3, 1, 11),
('2026-03-02', 1, 4, 6),
('2026-03-03', 2, 5, 9),
('2026-03-05', 3, 6, 5);

-- 4. VIEWS
CREATE OR REPLACE VIEW vw_daily_store_sales AS
SELECT
    s.sale_dt,
    s.store_id,
    st.store_name,
    st.city,
    SUM(s.qty) AS total_qty,
    ROUND(SUM(s.qty * s.sale_price), 2) AS revenue,
    ROUND(SUM(s.qty * (s.sale_price - p.cost_price)), 2) AS gross_profit
FROM sales s
JOIN stores st ON st.store_id = s.store_id
JOIN products p ON p.product_id = s.product_id
GROUP BY s.sale_dt, s.store_id, st.store_name, st.city;

CREATE OR REPLACE VIEW vw_promo_effectiveness AS
SELECT
    COALESCE(pr.promo_name, 'Без промо') AS promo_name,
    COUNT(*) AS sales_rows,
    SUM(s.qty) AS units_sold,
    ROUND(SUM(s.qty * s.sale_price), 2) AS revenue,
    ROUND(AVG(s.sale_price), 2) AS avg_sale_price
FROM sales s
LEFT JOIN promotions pr ON pr.promo_id = s.promo_id
GROUP BY COALESCE(pr.promo_name, 'Без промо');

CREATE OR REPLACE VIEW vw_low_stock_products AS
SELECT
    i.snapshot_dt,
    st.city,
    p.sku,
    p.product_name,
    p.category,
    i.stock_qty
FROM inventory_snapshots i
JOIN stores st ON st.store_id = i.store_id
JOIN products p ON p.product_id = i.product_id
WHERE i.stock_qty <= 10;

CREATE MATERIALIZED VIEW mv_monthly_sales AS
SELECT
    DATE_TRUNC('month', s.sale_dt)::date AS month_dt,
    s.store_id,
    st.city,
    s.product_id,
    p.product_name,
    p.category,
    SUM(s.qty) AS total_qty,
    ROUND(SUM(s.qty * s.sale_price), 2) AS revenue,
    ROUND(SUM(s.qty * (s.sale_price - p.cost_price)), 2) AS gross_profit
FROM sales s
JOIN stores st ON st.store_id = s.store_id
JOIN products p ON p.product_id = s.product_id
GROUP BY DATE_TRUNC('month', s.sale_dt)::date, s.store_id, st.city, s.product_id, p.product_name, p.category;

-- 5. FUNCTIONS (PL/pgSQL)
CREATE OR REPLACE FUNCTION get_store_revenue(
    p_store_id INT,
    p_date_from DATE,
    p_date_to DATE
)
RETURNS TABLE (
    sale_dt DATE,
    revenue NUMERIC(14,2)
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.sale_dt,
        ROUND(SUM(s.qty * s.sale_price), 2) AS revenue
    FROM sales s
    WHERE s.store_id = p_store_id
      AND s.sale_dt BETWEEN p_date_from AND p_date_to
    GROUP BY s.sale_dt
    ORDER BY s.sale_dt;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_low_stock_products(
    p_threshold INT,
    p_snapshot_dt DATE
)
RETURNS TABLE (
    snapshot_dt DATE,
    store_name VARCHAR(100),
    city VARCHAR(80),
    sku VARCHAR(40),
    product_name VARCHAR(120),
    stock_qty INT
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        i.snapshot_dt,
        st.store_name,
        st.city,
        p.sku,
        p.product_name,
        i.stock_qty
    FROM inventory_snapshots i
    JOIN stores st ON st.store_id = i.store_id
    JOIN products p ON p.product_id = i.product_id
    WHERE i.snapshot_dt = p_snapshot_dt
      AND i.stock_qty <= p_threshold
    ORDER BY i.stock_qty ASC, st.city, p.product_name;
END;
$$ LANGUAGE plpgsql;

-- 6. Revenue and gross profit by store and category
SELECT
    s.store_id,
    st.city,
    p.category,
    SUM(s.qty) AS total_qty,
    ROUND(SUM(s.qty * s.sale_price), 2) AS revenue,
    ROUND(SUM(s.qty * (s.sale_price - p.cost_price)), 2) AS gross_profit
FROM sales s
JOIN stores st ON st.store_id = s.store_id
JOIN products p ON p.product_id = s.product_id
WHERE s.sale_dt BETWEEN DATE '2026-01-01' AND DATE '2026-01-31'
GROUP BY s.store_id, st.city, p.category
ORDER BY revenue DESC;

-- 7. Products with low stock and high sales
SELECT
    st.city,
    p.sku,
    p.product_name,
    SUM(s.qty) AS sold_qty,
    MAX(i.stock_qty) AS current_stock
FROM sales s
JOIN stores st ON st.store_id = s.store_id
JOIN products p ON p.product_id = s.product_id
JOIN inventory_snapshots i
  ON i.store_id = s.store_id
 AND i.product_id = s.product_id
 AND i.snapshot_dt = s.sale_dt
GROUP BY st.city, p.sku, p.product_name
HAVING SUM(s.qty) >= 8 AND MAX(i.stock_qty) <= 15
ORDER BY sold_qty DESC, current_stock ASC;

-- 8. Promo effectiveness
SELECT
    COALESCE(pr.promo_name, 'Без промо') AS promo_name,
    COUNT(*) AS sales_rows,
    SUM(s.qty) AS units_sold,
    ROUND(SUM(s.qty * s.sale_price), 2) AS revenue
FROM sales s
LEFT JOIN promotions pr ON pr.promo_id = s.promo_id
GROUP BY COALESCE(pr.promo_name, 'Без промо')
ORDER BY revenue DESC;

-- 9. Top-3 products by revenue in each city
WITH sales_agg AS (
    SELECT
        st.city,
        p.product_name,
        p.category,
        ROUND(SUM(s.qty * s.sale_price), 2) AS revenue
    FROM sales s
    JOIN stores st ON st.store_id = s.store_id
    JOIN products p ON p.product_id = s.product_id
    GROUP BY st.city, p.product_name, p.category
),
ranked AS (
    SELECT
        city,
        product_name,
        category,
        revenue,
        RANK() OVER (PARTITION BY city ORDER BY revenue DESC) AS revenue_rank
    FROM sales_agg
)
SELECT *
FROM ranked
WHERE revenue_rank <= 3
ORDER BY city, revenue_rank, revenue DESC;

-- 10. Sales share by category in total revenue
WITH category_sales AS (
    SELECT
        p.category,
        ROUND(SUM(s.qty * s.sale_price), 2) AS revenue
    FROM sales s
    JOIN products p ON p.product_id = s.product_id
    GROUP BY p.category
),
total_revenue AS (
    SELECT SUM(revenue) AS total_revenue
    FROM category_sales
)
SELECT
    cs.category,
    cs.revenue,
    ROUND(100.0 * cs.revenue / tr.total_revenue, 2) AS revenue_share_pct
FROM category_sales cs
CROSS JOIN total_revenue tr
ORDER BY cs.revenue DESC;

-- =========================
-- 11. WINDOW FUNCTIONS
-- =========================

-- 11.1 Running revenue by store over time
SELECT
    s.sale_dt,
    st.city,
    ROUND(SUM(s.qty * s.sale_price), 2) AS daily_revenue,
    ROUND(
        SUM(SUM(s.qty * s.sale_price)) OVER (
            PARTITION BY st.city
            ORDER BY s.sale_dt
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ),
        2
    ) AS running_revenue
FROM sales s
JOIN stores st ON st.store_id = s.store_id
GROUP BY s.sale_dt, st.city
ORDER BY st.city, s.sale_dt;

-- 11.2 Compare daily sales with previous sale date using LAG
WITH daily_sales AS (
    SELECT
        s.sale_dt,
        st.city,
        ROUND(SUM(s.qty * s.sale_price), 2) AS revenue
    FROM sales s
    JOIN stores st ON st.store_id = s.store_id
    GROUP BY s.sale_dt, st.city
)
SELECT
    sale_dt,
    city,
    revenue,
    LAG(revenue) OVER (PARTITION BY city ORDER BY sale_dt) AS prev_revenue,
    ROUND(
        revenue - COALESCE(LAG(revenue) OVER (PARTITION BY city ORDER BY sale_dt), 0),
        2
    ) AS revenue_delta
FROM daily_sales
ORDER BY city, sale_dt;

-- 11.3 Product ranking within category
WITH category_product_sales AS (
    SELECT
        p.category,
        p.product_name,
        ROUND(SUM(s.qty * s.sale_price), 2) AS revenue
    FROM sales s
    JOIN products p ON p.product_id = s.product_id
    GROUP BY p.category, p.product_name
)
SELECT
    category,
    product_name,
    revenue,
    DENSE_RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS category_rank
FROM category_product_sales
ORDER BY category, category_rank, revenue DESC;

-- 12. Validation: duplicate sales by business key
SELECT
    sale_dt,
    store_id,
    product_id,
    sale_price,
    promo_id,
    COUNT(*) AS cnt
FROM sales
GROUP BY sale_dt, store_id, product_id, sale_price, promo_id
HAVING COUNT(*) > 1;

-- 13 Validation: sales rows with missing reference data
SELECT s.sale_id
FROM sales s
LEFT JOIN stores st ON st.store_id = s.store_id
LEFT JOIN products p ON p.product_id = s.product_id
WHERE st.store_id IS NULL OR p.product_id IS NULL;

-- 14 Validation: promotions with invalid date ranges
SELECT *
FROM promotions
WHERE end_dt < start_dt;

-- 15 Validation: negative or zero business values
SELECT *
FROM sales
WHERE qty <= 0 OR sale_price < 0;

-- 16 Validation: inventory snapshot duplicates
SELECT
    snapshot_dt,
    store_id,
    product_id,
    COUNT(*) AS cnt
FROM inventory_snapshots
GROUP BY snapshot_dt, store_id, product_id
HAVING COUNT(*) > 1;

-- 17 Validation: stock mismatch with high sales
WITH sales_stock AS (
    SELECT
        s.sale_dt,
        s.store_id,
        s.product_id,
        SUM(s.qty) AS sold_qty,
        MAX(i.stock_qty) AS stock_qty
    FROM sales s
    LEFT JOIN inventory_snapshots i
      ON i.store_id = s.store_id
     AND i.product_id = s.product_id
     AND i.snapshot_dt = s.sale_dt
    GROUP BY s.sale_dt, s.store_id, s.product_id
)
SELECT *
FROM sales_stock
WHERE stock_qty IS NOT NULL
  AND sold_qty > stock_qty;

-- =========================
-- 18. BUSINESS QUERIES
-- =========================

-- 18.1 Cities where promo sales generated the highest revenue
SELECT
    st.city,
    COALESCE(pr.promo_name, 'Без промо') AS promo_name,
    ROUND(SUM(s.qty * s.sale_price), 2) AS revenue
FROM sales s
JOIN stores st ON st.store_id = s.store_id
LEFT JOIN promotions pr ON pr.promo_id = s.promo_id
GROUP BY st.city, COALESCE(pr.promo_name, 'Без промо')
ORDER BY revenue DESC;

-- 18.2 Margin by product
SELECT
    p.sku,
    p.product_name,
    p.category,
    ROUND(SUM(s.qty * s.sale_price), 2) AS revenue,
    ROUND(SUM(s.qty * p.cost_price), 2) AS cost_total,
    ROUND(SUM(s.qty * (s.sale_price - p.cost_price)), 2) AS gross_profit,
    ROUND(
        100.0 * SUM(s.qty * (s.sale_price - p.cost_price)) / NULLIF(SUM(s.qty * s.sale_price), 0),
        2
    ) AS margin_pct
FROM sales s
JOIN products p ON p.product_id = s.product_id
GROUP BY p.sku, p.product_name, p.category
ORDER BY gross_profit DESC;

-- 18.3 Average чек / average revenue per sales row by city
SELECT
    st.city,
    COUNT(*) AS sales_rows,
    ROUND(SUM(s.qty * s.sale_price), 2) AS revenue,
    ROUND(AVG(s.qty * s.sale_price), 2) AS avg_receipt
FROM sales s
JOIN stores st ON st.store_id = s.store_id
GROUP BY st.city
ORDER BY revenue DESC;


-- Revenue for store_id = 1 for the selected period
SELECT *
FROM get_store_revenue(1, DATE '2026-01-01', DATE '2026-03-31');

-- Low-stock products on a given date with threshold <= 10
SELECT *
FROM get_low_stock_products(10, DATE '2026-02-07');


SELECT * FROM vw_daily_store_sales ORDER BY sale_dt, store_id;
SELECT * FROM vw_promo_effectiveness ORDER BY revenue DESC;
SELECT * FROM vw_low_stock_products ORDER BY snapshot_dt, city, stock_qty;


REFRESH MATERIALIZED VIEW mv_monthly_sales;

SELECT *
FROM mv_monthly_sales
ORDER BY month_dt, city, product_name;