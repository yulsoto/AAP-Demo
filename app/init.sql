-- Seed de datos para el lab. Datos ficticios de salud (solo demo).
CREATE TABLE IF NOT EXISTS patients (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    record TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL
);

INSERT INTO patients (name, record) VALUES
    ('Maria Lopez',   'A+ / control diabetes'),
    ('Juan Perez',    'O- / hipertension'),
    ('Ana Martinez',  'B+ / embarazo 2do trimestre'),
    ('Luis Ramirez',  'AB+ / post-quirurgico')
ON CONFLICT DO NOTHING;

INSERT INTO users (username, password) VALUES
    ('jennifer', 'demo1234'),
    ('miguel',   'demo1234'),
    ('elias',    'demo1234')
ON CONFLICT DO NOTHING;
