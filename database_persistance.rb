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
    ORDER BY monthly_budgets.date_beginning ASC;
    SQL
  end
end

