CREATE TABLE users (
	id serial PRIMARY KEY,
	username text NOT NULL,
	default_monthly_budget decimal(11,2) NOT NULL DEFAULT 0
);

CREATE TABLE monthly_budgets (
	id serial PRIMARY KEY,
	amount decimal(11,2) NOT NULL DEFAULT 0,
	date_beginning date NOT NULL UNIQUE
);

CREATE TABLE budget_categories (
	id serial PRIMARY KEY,
	name text NOT NULL UNIQUE,
	default_amount decimal(11,2) NOT NULL DEFAULT 0
);

CREATE TABLE monthly_categories (
	id serial PRIMARY KEY,
	category_amount decimal(11,2) NOT NULL DEFAULT 0,
	monthly_budget_id int NOT NULL REFERENCES monthly_budgets(id) ON DELETE CASCADE,
	budget_category_id int NOT NULL REFERENCES budget_categories(id) ON DELETE CASCADE
);

CREATE TABLE vendors (
	id serial PRIMARY KEY,
	name text NOT NULL
);

CREATE TABLE bills (
	id serial PRIMARY KEY,
	memo text NOT NULL,
	amount decimal(9,2),
	payment_date date NOT NULL,
	budget_category_id int NOT NULL REFERENCES budget_categories(id) ON DELETE CASCADE,
	vendor_id int NOT NULL REFERENCES vendors(id) ON DELETE CASCADE
);

INSERT INTO users (username) VALUES ('admin');

INSERT INTO budget_categories (name)
VALUES
('General'),
('Savings');
