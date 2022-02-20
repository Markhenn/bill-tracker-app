INSERT INTO users (username, default_monthly_budget) VALUES ('admin', 2100);

INSERT INTO monthly_budgets (amount, date_beginning)
VALUES
(2000, '2021-11-01'),
(1900, '2021-12-01');

INSERT INTO budget_categories (name, default_amount)
VALUES
('Generel', 1000),
('Savings', 0),
('Rent', 800),
('Fun', 300);

INSERT INTO monthly_categories (category_amount, monthly_budget_id, budget_category_id)
VALUES
(1000, 1, 1),
(100, 1, 2),
(800, 1, 3),
(100, 1, 4),
(800, 2, 1),
(0, 2, 2),
(800, 2, 3),
(300, 2, 4);

INSERT INTO vendors (name)
VALUES
('KaDeWe'),
('EDEKA'),
('Esso'),
('Giro'),
('Cyberport'),
('Landlord');

INSERT INTO bills (memo, amount, payment_date, monthly_categories_id, vendor_id)
VALUES
('Groceries', 87.98, '2021-11-05', 1, 2),
('Groceries', 45.87, '2021-11-11', 1, 2),
('Groceries', 103.54, '2021-11-15', 1, 2),
('Groceries', 21.23, '2021-12-07', 5, 2),
('Groceries', 87.44, '2021-12-20', 5, 2),
('Groceries', 67, '2021-12-27', 5, 2),
('Rent', 800, '2021-11-01', 3, 6),
('Rent', 800, '2021-12-01', 7, 6),
('Toys', 99.99, '2021-12-15', 8, 1),
('Coffee', 4.50, '2021-11-17', 1, 4),
('Coffee', 4.50, '2021-11-25', 1, 4),
('Coffee', 4.50, '2021-12-12', 5, 4),
('Gas', 87.94, '2021-11-24', 5, 3),
('iPhone', 600, '2021-12-11', 8, 5),
('Lego', 49.99, '2021-12-14', 4, 2);
