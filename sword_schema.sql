-- ============================================================
-- Sword Health / Bloom – Fictitious Data Schema
-- Database: neondb (PostgreSQL on Neon)
-- Constraints:
--   - 1000 users
--   - ~13000 sessions (max 16 per user, realistic dropout)
--   - 850 program outcomes (users who completed the program)
--   - 67% of menstruation pain users report pain relief by session 9
--   - 81% of users report PGIC >= 5 in their last session
--   - Average satisfaction score = 9.0
--   - Each user has exactly one condition
--   - At most one record per user in fact_program_outcomes
-- ============================================================


-- ── Dim_Date ──────────────────────────────────────────────
CREATE TABLE dim_date (
    date_id         DATE PRIMARY KEY,
    year            INT,
    quarter         INT,
    month           INT,
    month_name      VARCHAR(20),
    week            INT,
    day_of_week     VARCHAR(20),
    is_weekend      BOOLEAN
);

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
FROM generate_series('2023-01-01'::DATE, '2025-12-31'::DATE, '1 day') d;


-- ── Dim_Life_Stage ────────────────────────────────────────
CREATE TABLE dim_life_stage (
    life_stage_id   SERIAL PRIMARY KEY,
    life_stage_name VARCHAR(50),
    description     TEXT
);

INSERT INTO dim_life_stage (life_stage_name, description) VALUES
    ('Young Adulthood', 'Women aged 18-35 not currently pregnant or postpartum, managing pelvic health in early adulthood.'),
    ('Pregnancy',       'Women currently pregnant, addressing pelvic floor changes and symptoms during gestation.'),
    ('Postpartum',      'Women in the recovery period following childbirth, focused on pelvic floor rehabilitation.'),
    ('Perimenopause',   'Women in the transitional phase before menopause, experiencing hormonal fluctuations and related symptoms.'),
    ('Menopause',       'Women who have reached menopause, managing symptoms such as vaginal dryness, hot flashes, and mood changes.'),
    ('Postmenopause',   'Women in the years following menopause, maintaining pelvic health and managing long-term symptoms.');


-- ── Dim_Conditions ────────────────────────────────────────
CREATE TABLE dim_conditions (
    condition_id       SERIAL PRIMARY KEY,
    condition_name     VARCHAR(100),
    condition_category VARCHAR(50)
);

INSERT INTO dim_conditions (condition_name, condition_category) VALUES
    ('Intimacy Pain',       'Sexual Health'),
    ('Menstruation Pain',   'Menstrual Health'),
    ('Constipation',        'Bowel Health');


-- ── Dim_Users ─────────────────────────────────────────────
CREATE TABLE dim_users (
    user_id          SERIAL PRIMARY KEY,
    age              INT,
    city             VARCHAR(100),
    state            VARCHAR(50),
    married          BOOLEAN,
    has_children     BOOLEAN,
    hometown_living  BOOLEAN,
    life_stage_id    INT REFERENCES dim_life_stage(life_stage_id),
    condition_id     INT REFERENCES dim_conditions(condition_id)
);

INSERT INTO dim_users (age, city, state, married, has_children, hometown_living, life_stage_id, condition_id)
SELECT
    -- Age: distributed across life stages
    CASE
        WHEN ls = 1 THEN 18 + floor(random() * 18)::INT        -- 18-35 young adulthood
        WHEN ls = 2 THEN 22 + floor(random() * 14)::INT        -- 22-35 pregnancy
        WHEN ls = 3 THEN 23 + floor(random() * 14)::INT        -- 23-36 postpartum
        WHEN ls = 4 THEN 40 + floor(random() * 10)::INT        -- 40-49 perimenopause
        WHEN ls = 5 THEN 50 + floor(random() * 10)::INT        -- 50-59 menopause
        ELSE              60 + floor(random() * 15)::INT        -- 60-74 postmenopause
    END,
    city,
    state,
    random() > 0.45,
    random() > 0.40,
    random() > 0.55,
    ls,
    -- Condition: distributed roughly equally
    1 + (floor(random() * 3))::INT
FROM (
    SELECT
        1 + (floor(random() * 6))::INT AS ls,
        city,
        state
    FROM (VALUES
        ('New York','NY'),('Los Angeles','CA'),('Chicago','IL'),('Houston','TX'),
        ('Phoenix','AZ'),('Philadelphia','PA'),('San Antonio','TX'),('San Diego','CA'),
        ('Dallas','TX'),('San Jose','CA'),('Austin','TX'),('Jacksonville','FL'),
        ('Fort Worth','TX'),('Columbus','OH'),('Charlotte','NC'),('Indianapolis','IN'),
        ('San Francisco','CA'),('Seattle','WA'),('Denver','CO'),('Nashville','TN'),
        ('Oklahoma City','OK'),('El Paso','TX'),('Washington','DC'),('Las Vegas','NV'),
        ('Louisville','KY'),('Memphis','TN'),('Portland','OR'),('Baltimore','MD'),
        ('Milwaukee','WI'),('Albuquerque','NM'),('Tucson','AZ'),('Fresno','CA'),
        ('Sacramento','CA'),('Mesa','AZ'),('Kansas City','MO'),('Atlanta','GA'),
        ('Omaha','NE'),('Colorado Springs','CO'),('Raleigh','NC'),('Miami','FL')
    ) AS cities(city, state)
    -- repeat to get ~1000 rows
    CROSS JOIN generate_series(1, 25) AS g
    ORDER BY random()
    LIMIT 1000
) sub;


-- ── Fact_Sessions ─────────────────────────────────────────
CREATE TABLE fact_sessions (
    session_id      SERIAL PRIMARY KEY,
    user_id         INT REFERENCES dim_users(user_id),
    date_id         DATE REFERENCES dim_date(date_id),
    session_number  INT,
    condition_id    INT REFERENCES dim_conditions(condition_id),
    pain_relief     BOOLEAN,
    pgic_score      INT  -- 1-7
);

-- Generate sessions with realistic dropout and controlled metrics
-- Logic:
--   Users complete between 4 and 16 sessions (dropout modelled)
--   850 users complete >= 12 sessions (will get program outcomes)
--   Pain relief for menstruation pain users: 67% by session 9
--   PGIC >= 5 in last session: 81% of users
INSERT INTO fact_sessions (user_id, date_id, session_number, condition_id, pain_relief, pgic_score)
WITH user_params AS (
    SELECT
        u.user_id,
        u.condition_id,
        -- 850 users complete the full program (16 sessions), rest drop out between 4-15
        CASE
            WHEN row_number() OVER (ORDER BY random()) <= 850 THEN 16
            ELSE 4 + floor(random() * 12)::INT
        END AS max_sessions,
        -- For menstruation pain (condition_id=2): 67% get pain relief by session 9
        -- For others: distributed more broadly
        CASE
            WHEN u.condition_id = 2 AND random() < 0.67 THEN 5 + floor(random() * 5)::INT  -- relief between session 5-9
            WHEN u.condition_id = 2 THEN 10 + floor(random() * 7)::INT                      -- relief between session 10-16 or never
            WHEN u.condition_id = 1 AND random() < 0.60 THEN 4 + floor(random() * 8)::INT  -- intimacy pain: 60% by session 12
            WHEN u.condition_id = 3 AND random() < 0.55 THEN 6 + floor(random() * 8)::INT  -- constipation: 55% by session 14
            ELSE NULL                                                                         -- no relief
        END AS relief_session,
        -- PGIC in last session: 81% score >= 5
        CASE
            WHEN random() < 0.81 THEN 5 + floor(random() * 3)::INT  -- 5, 6, or 7
            ELSE 1 + floor(random() * 4)::INT                        -- 1, 2, 3, or 4
        END AS final_pgic
    FROM dim_users u
),
session_rows AS (
    SELECT
        up.user_id,
        up.condition_id,
        s.session_number,
        up.max_sessions,
        up.relief_session,
        up.final_pgic,
        -- Date: spread sessions roughly 2 days apart starting from a random date in 2023-2024
        ('2023-01-01'::DATE + floor(random() * 600)::INT + (s.session_number * 2))::DATE AS session_date
    FROM user_params up
    CROSS JOIN generate_series(1, 16) AS s(session_number)
    WHERE s.session_number <= up.max_sessions
)
SELECT
    user_id,
    session_date,
    session_number,
    condition_id,
    -- pain_relief: true from relief_session onwards (only one "yes" allowed — first occurrence)
    CASE
        WHEN relief_session IS NOT NULL AND session_number = relief_session THEN TRUE
        ELSE FALSE
    END AS pain_relief,
    -- pgic: final session gets final_pgic, others get a random score trending upward
    CASE
        WHEN session_number = max_sessions THEN final_pgic
        ELSE GREATEST(1, LEAST(7,
            CASE
                WHEN session_number <= 4  THEN 1 + floor(random() * 3)::INT
                WHEN session_number <= 8  THEN 2 + floor(random() * 3)::INT
                WHEN session_number <= 12 THEN 3 + floor(random() * 3)::INT
                ELSE                           4 + floor(random() * 3)::INT
            END
        ))
    END AS pgic_score
FROM session_rows;


-- ── Fact_Program_Outcomes ─────────────────────────────────
-- Only users who completed the program (max_sessions = 16)
-- One record per user maximum
-- Average satisfaction score = 9.0
CREATE TABLE fact_program_outcomes (
    outcome_id              SERIAL PRIMARY KEY,
    user_id                 INT UNIQUE REFERENCES dim_users(user_id),
    total_sessions_completed INT,
    satisfaction_score      NUMERIC(3,1),
    program_end_date        DATE
);

INSERT INTO fact_program_outcomes (user_id, total_sessions_completed, satisfaction_score, program_end_date)
WITH completers AS (
    SELECT
        user_id,
        MAX(session_number) AS total_sessions,
        MAX(date_id)        AS end_date
    FROM fact_sessions
    GROUP BY user_id
    HAVING MAX(session_number) = 16
    LIMIT 850
)
SELECT
    user_id,
    total_sessions,
    -- Satisfaction: average must be ~9.0
    -- Distribute: 60% score 9, 25% score 10, 10% score 8, 5% score 7 or below
    CASE
        WHEN random() < 0.25 THEN 10.0
        WHEN random() < 0.75 THEN 9.0
        WHEN random() < 0.90 THEN 8.0
        ELSE ROUND((6 + random() * 2)::NUMERIC, 1)
    END,
    end_date
FROM completers;
