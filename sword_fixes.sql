-- ============================================================
-- Sword Health / Bloom – Schema Fixes
-- 1. Add 2026 dates to dim_date
-- 2. Create dim_locations with US city coordinates
-- 3. Link dim_users to dim_locations
-- ============================================================


-- ── 1. Extend dim_date to cover 2026 ─────────────────────
INSERT INTO dim_date
SELECT
    d::DATE,
    EXTRACT(YEAR FROM d),
    EXTRACT(QUARTER FROM d),
    EXTRACT(MONTH FROM d),
    TO_CHAR(d, 'Month'),
    EXTRACT(WEEK FROM d),
    TO_CHAR(d, 'Day'),
    EXTRACT(DOW FROM d) IN (0, 6)
FROM generate_series('2026-01-01'::DATE, '2026-12-31'::DATE, '1 day') d;


-- ── 2. Create dim_locations ───────────────────────────────
CREATE TABLE dim_locations (
    location_id  SERIAL PRIMARY KEY,
    city         VARCHAR(100),
    state        VARCHAR(50),
    country      VARCHAR(50) DEFAULT 'United States',
    latitude     NUMERIC(9,6),
    longitude    NUMERIC(9,6)
);

INSERT INTO dim_locations (city, state, latitude, longitude) VALUES
    ('New York',         'NY',  40.712776, -74.005974),
    ('Los Angeles',      'CA',  34.052235, -118.243683),
    ('Chicago',          'IL',  41.878113, -87.629799),
    ('Houston',          'TX',  29.760427, -95.369804),
    ('Phoenix',          'AZ',  33.448376, -112.074036),
    ('Philadelphia',     'PA',  39.952583, -75.165222),
    ('San Antonio',      'TX',  29.424349, -98.491142),
    ('San Diego',        'CA',  32.715328, -117.157257),
    ('Dallas',           'TX',  32.776664, -96.796988),
    ('San Jose',         'CA',  37.338208, -121.886329),
    ('Austin',           'TX',  30.267153, -97.743057),
    ('Jacksonville',     'FL',  30.332184, -81.655647),
    ('Fort Worth',       'TX',  32.755488, -97.330765),
    ('Columbus',         'OH',  39.961176, -82.998794),
    ('Charlotte',        'NC',  35.227087, -80.843127),
    ('Indianapolis',     'IN',  39.768403, -86.158068),
    ('San Francisco',    'CA',  37.774929, -122.419418),
    ('Seattle',          'WA',  47.606209, -122.332071),
    ('Denver',           'CO',  39.739235, -104.984862),
    ('Nashville',        'TN',  36.174465, -86.767960),
    ('Oklahoma City',    'OK',  35.467560, -97.516428),
    ('El Paso',          'TX',  31.761878, -106.485022),
    ('Washington',       'DC',  38.907192, -77.036873),
    ('Las Vegas',        'NV',  36.174969, -115.137341),
    ('Louisville',       'KY',  38.252665, -85.758456),
    ('Memphis',          'TN',  35.149534, -90.048981),
    ('Portland',         'OR',  45.523064, -122.676483),
    ('Baltimore',        'MD',  39.290385, -76.612189),
    ('Milwaukee',        'WI',  43.038902, -87.906474),
    ('Albuquerque',      'NM',  35.085334, -106.605553),
    ('Tucson',           'AZ',  32.253460, -110.911789),
    ('Fresno',           'CA',  36.737797, -119.787125),
    ('Sacramento',       'CA',  38.581572, -121.494400),
    ('Mesa',             'AZ',  33.415184, -111.831472),
    ('Kansas City',      'MO',  39.099724, -94.578331),
    ('Atlanta',          'GA',  33.748997, -84.387985),
    ('Omaha',            'NE',  41.256537, -95.934502),
    ('Colorado Springs', 'CO',  38.833882, -104.821363),
    ('Raleigh',          'NC',  35.779591, -78.638176),
    ('Miami',            'FL',  25.774265, -80.193659);


-- ── 3. Link dim_users to dim_locations ────────────────────
ALTER TABLE dim_users
    ADD COLUMN location_id INT REFERENCES dim_locations(location_id);

UPDATE dim_users u
SET location_id = l.location_id
FROM dim_locations l
WHERE u.city = l.city;
