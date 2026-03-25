-- Portfolio SQL project for a System Analyst vacancy
-- Scenario: sales, stock and promo-effectiveness analysis for a retail chain
-- DB: PostgreSQL

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
    discount_pct   NUMERIC(5,2) NOT NULL CHECK (discount_pct >= 0 AND discount_pct <= 100)
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
    stock_qty      INT NOT NULL CHECK (stock_qty >= 0)
);

INSERT INTO stores (store_name, city, region, format) VALUES
('ТРЦ Центр', 'Москва', 'Центр', 'mall'),
('Галерея', 'Санкт-Петербург', 'Северо-Запад', 'mall'),
('Семейный', 'Казань', 'Поволжье', 'street');

INSERT INTO products (sku, product_name, category, brand, cost_price) VALUES
('SKU-1001', 'Футболка basic', 'Футболки', 'UrbanLine', 550.00),
('SKU-1002', 'Джинсы slim', 'Джинсы', 'UrbanLine', 1400.00),
('SKU-1003', 'Худи oversize', 'Худи', 'StreetMood', 1700.00),
('SKU-1004', 'Куртка демисезонная', 'Верхняя одежда', 'StreetMood', 3200.00);

INSERT INTO promotions (promo_name, start_dt, end_dt, discount_pct) VALUES
('Winter Sale', '2026-01-10', '2026-01-31', 15.00),
('Weekend Promo', '2026-02-06', '2026-02-08', 10.00);

INSERT INTO sales (sale_dt, store_id, product_id, qty, sale_price, promo_id) VALUES
('2026-01-12', 1, 1, 12, 899.00, 1),
('2026-01-12', 1, 2, 5, 2499.00, 1),
('2026-01-13', 2, 1, 8, 899.00, 1),
('2026-01-13', 2, 3, 4, 2990.00, 1),
('2026-01-14', 3, 4, 2, 5490.00, 1),
('2026-02-07', 1, 3, 6, 3190.00, 2),
('2026-02-07', 2, 2, 3, 2690.00, 2),
('2026-02-08', 3, 1, 10, 990.00, 2);

INSERT INTO inventory_snapshots (snapshot_dt, store_id, product_id, stock_qty) VALUES
('2026-01-12', 1, 1, 15),
('2026-01-12', 1, 2, 9),
('2026-01-13', 2, 1, 10),
('2026-01-13', 2, 3, 5),
('2026-01-14', 3, 4, 3),
('2026-02-07', 1, 3, 7),
('2026-02-07', 2, 2, 4),
('2026-02-08', 3, 1, 11);

-- 1. Revenue and gross profit by store and category
SELECT
    s.store_id,
    st.city,
    p.category,
    SUM(s.qty) AS total_qty,
    SUM(s.qty * s.sale_price) AS revenue,
    SUM(s.qty * (s.sale_price - p.cost_price)) AS gross_profit
FROM sales s
JOIN stores st ON st.store_id = s.store_id
JOIN products p ON p.product_id = s.product_id
WHERE s.sale_dt BETWEEN DATE '2026-01-01' AND DATE '2026-01-31'
GROUP BY s.store_id, st.city, p.category
ORDER BY revenue DESC;

-- 2. Products with low stock and high sales
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

-- 3. Promo effectiveness
SELECT
    COALESCE(pr.promo_name, 'Без промо') AS promo_name,
    COUNT(*) AS sales_rows,
    SUM(s.qty) AS units_sold,
    ROUND(SUM(s.qty * s.sale_price), 2) AS revenue
FROM sales s
LEFT JOIN promotions pr ON pr.promo_id = s.promo_id
GROUP BY COALESCE(pr.promo_name, 'Без промо')
ORDER BY revenue DESC;

-- 4. Validation: duplicate sales by business key
SELECT
    sale_dt, store_id, product_id, sale_price, promo_id, COUNT(*) AS cnt
FROM sales
GROUP BY sale_dt, store_id, product_id, sale_price, promo_id
HAVING COUNT(*) > 1;

-- 5. Validation: sales rows with missing reference data
SELECT s.sale_id
FROM sales s
LEFT JOIN stores st ON st.store_id = s.store_id
LEFT JOIN products p ON p.product_id = s.product_id
WHERE st.store_id IS NULL OR p.product_id IS NULL;