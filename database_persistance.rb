require 'pg'
require 'pp'

class DatabasePersistance

  def initialize(logger)
    @db = PG.connect(dbname: 'bill_tracker')
    @logger = logger
  end

  def user_data(userid)
    sql = 'SELECT id, username, default_monthly_budget FROM users WHERE id = $1'
    result = query(sql, userid)
    result.values.first
  end

  def budget_of_a_month

  end

  def add_bill(values)
    vendor_id = get_vendor_id(values[4])
    monthly_categories_id = get_monthly_category_id(values[3], values[2])

    values = values[0..2] + [monthly_categories_id] + [vendor_id]

    sql = <<~SQL
    INSERT INTO bills
    (memo, amount, payment_date, monthly_categories_id, vendor_id)
    VALUES
    ($1, $2, $3, $4, $5)
    SQL

    query(sql, *values)
  end

  def all_categories
    sql = 'SELECT id, name FROM budget_categories'
    result = query(sql)
    result.values
  end

  def all_vendors
    sql = 'SELECT * FROM vendors'
    result = query(sql)
    result.values
  end

  def all_bills
    sql = <<~SQL
    SELECT
    bills.id AS bill_id,
    bills.memo,
    bills.payment_date,
    bills.amount,
    vendors.id AS vendor_id,
    vendors.name
    FROM
    bills
    JOIN vendors ON bills.vendor_id = vendors.id
    ORDER BY
    bills.payment_date;
    SQL

    result = query(sql)
    [result.values]
  end

  def category_budgets
    sql = <<~SQL
    SELECT
    budget_categories.id AS category_id,
    budget_categories.name AS category_name,
    TRUNC(AVG(monthly_categories.category_amount),2) AS category_budget,
    TRUNC(SUM(bills.amount) / COUNT(DISTINCT(monthly_budget_id)), 2) AS average_bills
    FROM
    budget_categories
    JOIN monthly_categories ON budget_categories.id = monthly_categories.budget_category_id
    JOIN bills ON monthly_categories.id = bills.monthly_categories_id
    GROUP BY
    category_id,
    category_name
    ORDER BY
    category_id
    SQL

    result = query(sql)

    [result.values]
  end

  def monthly_budgets
    sql = <<~SQL
    SELECT
    monthly_budgets.id AS budget_id,
    monthly_budgets.amount AS budget_amount,
    SUM(bills.amount) AS monthly_sum,
    EXTRACT (YEAR FROM monthly_budgets.date_beginning) AS year,
    EXTRACT (MONTH FROM monthly_budgets.date_beginning) AS month
    FROM
    monthly_budgets
    JOIN monthly_categories ON monthly_budgets.id = monthly_categories.monthly_budget_id
    JOIN bills ON monthly_categories.id = bills.monthly_categories_id
    GROUP BY
    year,
    month,
    budget_id,
    budget_amount
    ORDER BY
    year DESC,
    month DESC;
    SQL

    result = query(sql)


    budget = Hash.new { |h,k| h[k] = Hash.new(&h.default_proc) }

    result.each do |tuple|
      year = tuple['year']
      month = tuple['month']

      unless budget[year][month].key?(:budget_id)
        budget[year][month][:budget_id] = tuple['budget_id'].to_i
        budget[year][month][:budget_amount] = tuple['budget_amount'].to_f
        budget[year][month][:bills_sum] = tuple['monthly_sum'].to_f
      end
    end

    budget.each do |year, months|
      budget[year][:bills_sum] = months.values.map {|hsh| hsh[:bills_sum]}.reduce(:+)
    end

    pp budget
    [budget]

  end

  def monthly_categories
    result = query(full_budget_sql)

    budget = Hash.new { |h,k| h[k] = Hash.new(&h.default_proc) }

    result.each do |tuple|
      year = tuple['year']
      month = tuple['month']
      cat_id = tuple['category_id'].to_i
      categories = budget[year][month][:categories]

      unless budget[year].key?(:bills_sum)
        budget[year][:bills_sum] = tuple['yearly_sum'].to_f
      end

      unless budget[year][month].key?(:budget_id)
        budget[year][month][:budget_id] = tuple['budget_id'].to_i
        budget[year][month][:budget_amount] = tuple['budget_amount'].to_f
        budget[year][month][:bills_sum] = tuple['monthly_sum'].to_f
      end

      unless categories[cat_id].key?(:category_name)
        categories[cat_id][:category_name] = tuple['category_name']
        categories[cat_id][:budget_amount] = tuple['category_amount'].to_f
        categories[cat_id][:bills_sum] = tuple['monthly_cat_sum'].to_f
      end
    end

    pp budget
    [budget]
  end

  def full_budget
    result = query(full_budget_sql)

    budget = Hash.new { |h,k| h[k] = Hash.new(&h.default_proc) }

    result.each do |tuple|
      year = tuple['year']
      month = tuple['month']
      cat_id = tuple['category_id'].to_i
      categories = budget[year][month][:categories]

      bill = {
            bill_id: tuple['bill_id'].to_i,
            memo: tuple['memo'],
            bill_amount: tuple['bill_amount'].to_f,
            payment_date: tuple['payment_date'],
            vendor: tuple['vendor']
      }

      if categories[cat_id][:bills].empty?
        categories[cat_id][:bills] = [bill]
      else
        categories[cat_id][:bills] << bill
      end

      unless budget[year].key?(:bills_sum)
        budget[year][:bills_sum] = tuple['yearly_sum'].to_f
      end

      unless budget[year][month].key?(:budget_id)
        budget[year][month][:budget_id] = tuple['budget_id'].to_i
        budget[year][month][:budget_amount] = tuple['budget_amount'].to_f
        budget[year][month][:bills_sum] = tuple['monthly_sum'].to_f
      end

      unless categories[cat_id].key?(:category_name)
        categories[cat_id][:category_name] = tuple['category_name']
        categories[cat_id][:budget_amount] = tuple['category_amount'].to_f
        categories[cat_id][:bills_sum] = tuple['monthly_cat_sum'].to_f
      end
    end

    # pp budget
    [budget]
  end

  private

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def full_budget_sql
    sql = <<~SQL
    SELECT
    bills.id AS bill_id, bills.memo, bills.amount AS bill_amount, bills.payment_date,
    vendors.name AS vendor,
    budget_categories.name AS category_name, budget_categories.id AS category_id,
    monthly_categories.category_amount AS category_amount,
    monthly_budgets.id AS budget_id, monthly_budgets.amount AS budget_amount, monthly_budgets.date_beginning,
    SUM(bills.amount) OVER (PARTITION BY monthly_budgets.id) AS monthly_sum,
    SUM(bills.amount) OVER (PARTITION BY monthly_categories.id) AS monthly_cat_sum,
    SUM(bills.amount) OVER (PARTITION BY EXTRACT (YEAR FROM monthly_budgets.date_beginning)) AS yearly_sum,
    EXTRACT (YEAR FROM monthly_budgets.date_beginning) AS year,
    EXTRACT (MONTH FROM monthly_budgets.date_beginning) AS month
    FROM bills
    JOIN vendors ON bills.vendor_id = vendors.id
    JOIN monthly_categories ON monthly_categories.id = bills.monthly_categories_id
    JOIN budget_categories ON budget_categories.id = monthly_categories.budget_category_id
    JOIN monthly_budgets ON monthly_categories.monthly_budget_id = monthly_budgets.id
    ORDER BY monthly_budgets.date_beginning DESC;
    SQL
  end

  def vendor_id(name)
    sql = "SELECT id FROM vendors WHERE name = $1"
    result = query(sql, name)

    return nil if result.ntuples.zero?
    result.values.first.first.to_i
  end

  def get_vendor_id(name)
    loop do
      id = vendor_id(name)
      break id if id
      add_vendor_to_db(name)
    end
  end

  def budget_id(date_beginning)
    sql = "SELECT id FROM monthly_budgets WHERE date_beginning = $1"
    result = query(sql, date_beginning)

    return nil if result.ntuples.zero?
    result.values.first.first.to_i
  end

  def category_id(name)
    sql = "SELECT id FROM budget_categories WHERE name = $1"
    result = query(sql, name)

    return nil if result.ntuples.zero?
    result.values.first.first.to_i
  end

  def monthly_category_id(category_id, budget_id)
    sql = "SELECT id FROM monthly_categories WHERE budget_category_id = $1 AND monthly_budget_id = $2"
    result = query(sql, category_id, budget_id)

    return nil if result.ntuples.zero?
    result.values.first.first.to_i
  end

  def get_budget_id(date)
    date_beginning = date.split('-')
    date_beginning[2] = '01'
    date_beginning = date_beginning.join('-')

    loop do
      id = budget_id(date_beginning)
      break id if id
      add_budget_to_db(date_beginning)
    end
  end

  def get_category_id(category_name)
    loop do
      id = category_id(category_name)
      break id if id
      add_category_to_db(category_name)
    end
  end

  def get_monthly_category_id(category_name, date)
    c_id = get_category_id(category_name)
    b_id = get_budget_id(date)

    loop do
      id = monthly_category_id(c_id, b_id)
      break id if id
      add_monthly_category_to_db(c_id, b_id)
    end
  end

  def add_budget_to_db(date_beginning)
    # User ID is hardcoded and has to be changed later in impementation
    user_id = 1
    sql = "SELECT default_monthly_budget FROM users WHERE id = $1"
    default_amount = query(sql, user_id).values.first.first.to_f

    sql = "INSERT INTO monthly_budgets(date_beginning, amount) VALUES ($1, $2)"
    query(sql, date_beginning, default_amount)
  end

  def add_category_to_db(name)
    sql = "INSERT INTO budget_categories(name, default_amount) VALUES ($1, 0)"
    query(sql, name)
  end

  def add_monthly_category_to_db(category_id, budget_id)
    sql = "SELECT default_amount FROM budget_categories WHERE id = $1"
    amount = query(sql, category_id).values.first.first

    sql = "INSERT INTO monthly_categories(budget_category_id, monthly_budget_id, category_amount) VALUES ($1, $2, $3)"
    query(sql, category_id, budget_id, amount)
  end

  def add_vendor_to_db(name)
    sql = "INSERT INTO vendors(name) VALUES ($1)"
    query(sql, name)
  end
end

