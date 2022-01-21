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

  def full_budget
    sql = <<~SQL
    SELECT bills.id AS bill_id, bills.memo, bills.amount AS bill_amount, bills.payment_date,
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
    JOIN budget_categories ON budget_categories.id = bills.budget_category_id
    JOIN monthly_categories ON budget_categories.id = monthly_categories.budget_category_id
    JOIN monthly_budgets ON monthly_categories.monthly_budget_id = monthly_budgets.id
    WHERE bills.payment_date between monthly_budgets.date_beginning and
    monthly_budgets.date_beginning + INTERVAL '1 month' - INTERVAL '1 day'
    ORDER BY monthly_budgets.date_beginning ASC;
    SQL

    result = query(sql)

    full_budget = Hash.new { |h,k| h[k] = Hash.new(&h.default_proc) }

    result.each do |tuple|
      year = tuple['year']
      month = tuple['month']
      cat_id = tuple['category_id'].to_i
      categories = full_budget[year][month][:categories]

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

      unless full_budget[year].key?(:bills_sum)
        full_budget[year][:bills_sum] = tuple['yearly_sum'].to_f
      end

      unless full_budget[year][month].key?(:budget_id)
        full_budget[year][month][:budget_id] = tuple['budget_id'].to_i
        full_budget[year][month][:budget_amount] = tuple['budget_amount'].to_f
        full_budget[year][month][:bills_sum] = tuple['monthly_sum'].to_f
      end

      unless categories[cat_id].key?(:category_name)
        categories[cat_id][:category_name] = tuple['category_name']
        categories[cat_id][:budget_amount] = tuple['category_amount'].to_f
        categories[cat_id][:bills_sum] = tuple['monthly_cat_sum'].to_f
      end
    end

    # pp full_budget
    [full_budget]
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

end

