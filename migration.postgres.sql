CREATE TABLE IF NOT EXISTS member (
    account TEXT NOT NULL PRIMARY KEY,
    password TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS todo (
    id SERIAL PRIMARY KEY,
    account TEXT NOT NULL,
    due_date TIMESTAMP NOT NULL,
    content TEXT NOT NULL,
    complete BOOLEAN
);