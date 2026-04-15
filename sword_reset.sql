-- ============================================================
-- Sword Health / Bloom – Data Reset
-- 10000 users, 7500 completers (16 sessions), 2500 dropouts (4-15)
-- ============================================================


-- ── 1. Clear existing data ────────────────────────────────
TRUNCATE fact_program_outcomes, fact_sessions, dim_users RESTART IDENTITY CASCADE;



-- ── 2. Re-insert dim_users (10000 rows) ──────────────────
INSERT INTO dim_users (age, city, state, married, has_children, hometown_living, life_stage_id, condition_id)
SELECT
    CASE
        WHEN ls = 1 THEN 18 + floor(random() * 18)::INT
        WHEN ls = 2 THEN 22 + floor(random() * 14)::INT
        WHEN ls = 3 THEN 23 + floor(random() * 14)::INT
        WHEN ls = 4 THEN 40 + floor(random() * 10)::INT
        WHEN ls = 5 THEN 50 + floor(random() * 10)::INT
        ELSE              60 + floor(random() * 15)::INT
    END,
    city,
    state,
    random() > 0.45,
    random() > 0.40,
    random() > 0.55,
    ls,
    1 + (floor(random() * 3))::INT
FROM (
    SELECT
        1 + (floor(random() * 6))::INT AS ls,
        city,
        state
    FROM (VALUES
        ('New York','NY',15),('Los Angeles','CA',12),('Chicago','IL',9),('Houston','TX',8),
        ('Phoenix','AZ',7),('Philadelphia','PA',6),('San Antonio','TX',5),('San Diego','CA',5),
        ('Dallas','TX',7),('San Jose','CA',5),('Austin','TX',6),('Jacksonville','FL',4),
        ('Fort Worth','TX',4),('Columbus','OH',4),('Charlotte','NC',4),('Indianapolis','IN',4),
        ('San Francisco','CA',6),('Seattle','WA',5),('Denver','CO',5),('Nashville','TN',4),
        ('Oklahoma City','OK',3),('El Paso','TX',3),('Washington','DC',5),('Las Vegas','NV',5),
        ('Louisville','KY',3),('Memphis','TN',3),('Portland','OR',4),('Baltimore','MD',3),
        ('Milwaukee','WI',3),('Albuquerque','NM',2),('Tucson','AZ',2),('Fresno','CA',2),
        ('Sacramento','CA',3),('Mesa','AZ',2),('Kansas City','MO',3),('Atlanta','GA',5),
        ('Omaha','NE',2),('Colorado Springs','CO',2),('Raleigh','NC',3),('Miami','FL',5)
    ) AS cities(city, state, w)
    CROSS JOIN generate_series(1, cities.w * 55) AS g
    ORDER BY random()
    LIMIT 10000
) sub;


-- ── 3. Re-insert fact_sessions ────────────────────────────
INSERT INTO fact_sessions (user_id, date_id, session_number, pain_relief, pgic_score)
WITH user_params AS (
    SELECT
        u.user_id,
        u.condition_id,
        CASE
            WHEN row_number() OVER (ORDER BY random()) <= 7500 THEN 16
            ELSE 4 + floor(random() * 12)::INT
        END AS max_sessions,
        CASE
            WHEN u.condition_id = 2 AND random() < 0.67 THEN 5 + floor(random() * 5)::INT
            WHEN u.condition_id = 2 THEN 10 + floor(random() * 7)::INT
            WHEN u.condition_id = 1 AND random() < 0.60 THEN 4 + floor(random() * 8)::INT
            WHEN u.condition_id = 3 AND random() < 0.55 THEN 6 + floor(random() * 8)::INT
            ELSE NULL
        END AS relief_session,
        CASE
            WHEN random() < 0.81 THEN 5 + floor(random() * 3)::INT
            ELSE 1 + floor(random() * 4)::INT
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
        ('2023-01-01'::DATE + floor(random() * 600)::INT + (s.session_number * 2))::DATE AS session_date
    FROM user_params up
    CROSS JOIN generate_series(1, 16) AS s(session_number)
    WHERE s.session_number <= up.max_sessions
)
SELECT
    user_id,
    session_date,
    session_number,
    CASE
        WHEN relief_session IS NOT NULL AND session_number = relief_session THEN TRUE
        ELSE FALSE
    END AS pain_relief,
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


-- ── 4. Re-insert fact_program_outcomes ───────────────────
INSERT INTO fact_program_outcomes (user_id, total_sessions_completed, satisfaction_score, program_end_date)
WITH completers AS (
    SELECT
        user_id,
        MAX(session_number) AS total_sessions,
        MAX(date_id)        AS end_date
    FROM fact_sessions
    GROUP BY user_id
    HAVING MAX(session_number) = 16
    LIMIT 7500
)
SELECT
    user_id,
    total_sessions,
    CASE
        WHEN random() < 0.25 THEN 10.0
        WHEN random() < 0.75 THEN 9.0
        WHEN random() < 0.90 THEN 8.0
        ELSE ROUND((6 + random() * 2)::NUMERIC, 1)
    END,
    end_date
FROM completers;


-- ── 5. Re-link dim_users to dim_locations ─────────────────
UPDATE dim_users u
SET location_id = l.location_id
FROM dim_locations l
WHERE u.city = l.city;
