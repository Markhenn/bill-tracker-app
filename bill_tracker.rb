# frozen_string_literal: true

require 'sinatra'
require 'yaml'
# require 'bcrypt'

require_relative 'database_persistance'

configure do
  enable :sessions
  set :sessions_secret, 'secret'
  # set :erb, escape_html: true
end

configure :development do
  require 'sinatra/reloader'
  also_reload 'bill_tracker.rb'
  also_reload 'database_persistance.rb'
end

def config_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('test', __dir__)
  else
    File.expand_path(__dir__)
  end
end

def data_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('test/data', __dir__)
  else
    File.expand_path('data', __dir__)
  end
end

helpers do
  def todays_date
    Date.today.strftime('%Y-%m-%d')
  end

  def full_month_name(month, year)
    "#{Date.strptime(month, '%m').strftime('%B')} #{year}"
  end

  def sort_hash_on_key(hash, &block)
    hash_sorted = hash.sort_by { |hsh, _| hsh }.reverse
    hash_sorted.each(&block)
  end

  def sort_categories(categories, &block)
    categories_sorted = categories.sort do |a, b|
      a <=> b
    end

    categories_sorted.each(&block)
  end

  def sort_bills(bills, &block)
    bills_sorted = bills.sort do |a, b|
      parse_date(b[:payment_date]) <=> parse_date(a[:payment_date])
    end

    bills_sorted.each(&block)
  end

  def show_budget_balance(value_hash)
    budget = "The budget is: #{value_hash[:budget_amount]}"

    sum = "Sum of bills for the budget: #{value_hash[:bills_sum]}"

    [budget, sum, determine_difference_message(value_hash)].join('</br>')
  end

  def show_yearly_summary(values)
    bills = values.delete(:bills_sum)
    budget = values.map {|m| m[1][:budget_amount]}.reduce(:+)
    year_values = {budget_amount: budget, bills_sum: bills}
    show_budget_balance(year_values)
  end
end

# def user_path(username)
#   user_file = "#{username}.yaml"
#   File.join(data_path, user_file)
# end

# def load_user(username)
#   # The [Symbol] makes sure that symbols are loaded, which would be disallowed
#   YAML.safe_load(File.read(user_path(username)), [Symbol])
# end

# def write_user_yaml(username)
#   File.write(user_path(username), @user_data.to_yaml)
# end

# def logged_in?
#   if session[:username]
#     @user_data = load_user(session[:username])
#   else
#     redirect '/login'
#   end
# end

# def add_user_to_file(username, password)
#   users = load_users_file
#   users[username] = BCrypt::Password.create(password)
#   write_users_file(users)
# end

# def load_users_file
#   file_path = File.join(config_path, 'users.yaml')
#   YAML.safe_load(File.read(file_path), [Symbol, BCrypt::Password])
# end

# def write_users_file(users)
#   file_path = File.join(config_path, 'users.yaml')
#   File.write(file_path, users.to_yaml)
# end

# def user_valid?(username, password)
#   user_file = load_users_file

#   user_file.any? do |user, pw|
#     user == username && BCrypt::Password.new(pw) == password
#   end
# end

# def create_user_file(username)
#   @user_data = { name: username, default_budget: '0', spending: {} }
#   write_user_yaml(username)
# end

# def all_bills
#   bills = []
#   @user_data[:spending].each do |_, months|
#     months.each do |_, content|
#       content.each do |key, values|
#         bills += values if key == :bills
#       end
#     end
#   end
#   bills
# end

def valid_amount?(amount)
  amount =~ /\A[+-]?\d+(\.\d{1,2})?\z/
end

def valid_string?(text)
  text =~ /\w{2,}/
end

def invalid_budget?(budget)
  budget !~ /\A+?\d+(\.?\d{1,2})\z/
end

def valid_id(string)
  string =~ /\A\d+\z/
end

# def pw_error_message(password)
#   if password !~ /.{4,}/
#     'The password needs to contain at least 4 chars'
#   elsif  password !~ /\d+/
#     'The password needs to have a least 1 number'
#   elsif password !~ /[A-Z]+/
#     'The password has to have at least 1 upper case letter'
#   end
# end

# def username_error_message(username)
#   if username !~ /\A\w{2,}\z/
#     'Your username must contain at least to letters or numbers'
#   elsif File.exist?(File.join(data_path, "#{username}.yaml"))
#     'This username has already been taken'
#   end
# end

def parse_date(date_string)
  Date.strptime(date_string, '%Y-%m-%d')
end

# def sum_of_bills(bills)
#   bills.reduce(0) { |sum, bill| sum + bill[:bill_amount] }.round(2)
# end

def determine_difference_message(values)
  difference = (values[:budget_amount] - values[:bills_sum]).round(2)

  if difference.positive?
    "You still have #{difference} left to spend"
  elsif difference.negative?
    "You have a deficit of #{difference}"
  else
    'Your budget has been completely consumed'
  end
end

before do
  # There is no user system implemented, this is a work around
  # @user_data = load_user('admin')
  @storage = DatabasePersistance.new(logger)
  userid = '1'
  @user_data = @storage.user_data(userid)
  @user_id =  @user_data.first
  @default_budget = @user_data[2]
end

get '/' do
  month_id = @storage.last_month_id
  redirect "/budgets/#{month_id}/show"
end

get '/bills' do
  @bills = @storage.all_bills
  erb :all_bills
end

get '/categories' do
  @categories_bills = @storage.categories_bills
  erb :categories
end

get '/categories/:id' do
  @id = params[:id]

  error = nil
  error = 'This category does not exist' unless @storage.category(@id)

  unless @id
    session[:message] = error
    redirect 'budgets/categories', 422
  else
    @name, @default_amount = @storage.category(@id)
    erb :category
  end
end

post '/categories/:id/edit' do
  id = params[:id].to_i
  name = params[:name]

  error = nil
  error = 'The category needs to have at least two chars' unless valid_string?(params[:name])
  error = 'The category name exists already' if @storage.category(id).first != name && @storage.category_id(name)
  error = 'The default budget needs to be a decimal number (ie. 12.34)' unless valid_amount?(params[:default_amount])

  if error
    session[:message] = error
    redirect "/categories/#{id}", 422
  else
    values = [id,
              name,
              params[:default_amount].to_f
    ]

    @storage.update_category(values)
    session[:message] = 'The Category has been updated'
    redirect '/categories'
  end
end

get '/budgets/:month_id/show' do
  @budget = @storage.budget_of_a_month(params["month_id"]).first
  @months = @storage.months_list

  erb :budget_of_a_month
end

post '/budgets/show' do
  redirect "/budgets/#{params[:month_id]}/show"
end

get '/budgets/monthly' do
  @budget = @storage.monthly_budgets
  erb :monthly_budgets
end

get '/budgets/monthly_categories' do
  @budget = @storage.monthly_categories
  erb :monthly_categories_budget
end

get '/budgets/full' do
  @budget = @storage.full_budget.first
  erb :full_budget
end

get '/users/change_default_budget' do
  @default_budget = @storage.default_user_budget(@user_id)
  erb :change_default_budget
end

post '/users/change_default_budget' do
  new_budget = params[:new_budget]

  error = nil
  error = 'The new budget needs to be >= 0 but can be a float'

  if error
    @new_budget = new_budget
    status 422
    session[:message] = error
    erb :change_default_budget
  else
    @storage.update_default_budget(@user_id, new_budget)
    session[:message] = 'The budget has been updated'
    redirect '/'
  end
end

get '/budgets/edit' do
  @months = @storage.months_list
  erb :edit_budgets
end

post '/budgets/edit' do
  redirect "budgets/#{params[:months_id]}/edit"
end

get '/budgets/:month_id/edit' do
  id = params[:month_id]
  @monthly_value = @storage.get_monthly_budget(id)
  @category_values = @storage.get_monthly_categories(id)
  @month_amount = @monthly_value[:amount].to_f
  @sum_of_categories = @category_values.reduce(0) do |sum, month|
    sum + month[:cat_amount].to_f
  end
  @difference = (@month_amount - @sum_of_categories).round(2)
  erb :edit_monthly_budget
end

post '/budgets/:month_id/edit' do
  month_id = params[:month_id]
  monthly_budget = params[:monthly_budget]

  error = nil
  error = 'The budget needs to be a decimal number (ie. 12.34)' unless valid_amount?(monthly_budget)

  if error
    status 422
    session[:message] = error
  else
    category_budgets = {}
    params.each do |key, value|
      next unless valid_id(key)
      # This error check is a workaround -> improve with Javascript before sending
      value = 0 if invalid_budget?(value)
      category_budgets[key] = value.to_f
    end

    @storage.update_budgets(month_id, category_budgets, monthly_budget)
  end
  redirect "budgets/#{month_id}/edit"
end

get '/bills/add' do
  @vendors = @storage.all_vendors
  @categories = @storage.all_categories

  erb :add_bill
end

post '/bills' do
  error = nil
  error = 'The memo needs to have at least two chars' unless valid_string?(params[:memo])
  error = 'The category needs to have at least two chars' unless valid_string?(params[:category])
  error = 'The amount needs to be a decimal number (ie. 12.34)' unless valid_amount?(params[:amount])
  error = 'The vendor needs to have at least two chars' unless valid_string?(params[:vendor])

  @vendors = @storage.all_vendors
  @categories = @storage.all_categories
  @date = params[:date]
  @category = params[:category]
  @vendor = params[:vendor]
  @amount = params[:amount]
  @memo = params[:memo]

  if error
    session[:message] = error
    status 422
  else
    values = [params[:memo],
              params[:amount],
              params[:date],
              params[:category],
              params[:vendor]]

    @storage.add_bill(values)
    session[:message] = 'The bill has been added'
  end

    erb :add_bill
end

get '/bills/:bill_id' do
  @vendors = @storage.all_vendors
  @categories = @storage.all_categories
  @id = params[:bill_id].to_i

  bill = @storage.bill(@id)

  unless bill
    session[:message] = 'This bill does not exist'
    redirect '/bills', 422
  else
    @memo, @amount, @date, @category, @vendor = bill
    erb :edit_bill
  end
end

post '/bills/:id/edit' do
  error = nil
  error = 'The memo needs to have at least two chars' unless valid_string?(params[:memo])
  error = 'The category needs to have at least two chars' unless valid_string?(params[:category])
  error = 'The amount needs to be a decimal number (ie. 12.34)' unless valid_amount?(params[:amount])
  error = 'The vendor needs to have at least two chars' unless valid_string?(params[:vendor])

  id = params[:id]

  if error
    session[:message] = error
    status 422
  else
    values = [id,
              params[:memo],
              params[:amount],
              params[:date],
              params[:category],
              params[:vendor]]

    @storage.update_bill(values)
    session[:message] = 'The bill has been updated'

  end
  redirect "/bills/#{id}"
end

post '/bills/:id/delete' do
  id = params[:id]

  unless @storage.bill(id)
    session[:message] = 'The bill does not exist'
    redirect '/', 422
  else
    @storage.delete_bill(id)
    session[:message] = 'The bill has been deleted'
    redirect '/'
  end
end

get '/vendors' do
  @vendors = @storage.vendors
  erb :vendors
end

get '/vendors/:id' do
  @id, @name = @storage.vendor(params[:id])
  erb :vendor
end

post '/vendors/:id/edit' do
  @id = params[:id]
  @name = params[:name]

  error = nil
  error = 'The vendor needs to have at least two chars' unless valid_string?(@name)
  error = 'The vendor name already exits' if @storage.vendor(@id) != @name && @storage.vendor_id(@name)

  if error
    session[:message] = error
    status 422
    erb :vendor
  else
    @storage.update_vendor([@id, @name])
    session[:message] = 'The vendor has been updated'
    redirect '/vendors'
  end
end

# get '/login' do
#   erb :login
# end

# post '/login' do
#   username = params[:username].downcase
#   if user_valid?(username, params[:password])
#     session[:username] = username
#     session[:message] = "Welcome #{username}"
#     redirect '/'
#   else
#     session[:message] = 'Username / Password invalid'
#     status 422
#     erb :login
#   end
# end

# post '/logout' do
#   session.delete(:username)
#   session[:message] = 'You have been logged out'

#   redirect '/login'
# end

# get '/signup' do
#   erb :signup
# end

# post '/signup' do
#   @user = params[:username].downcase
#   pw = params[:password]

#   error_pw = pw_error_message(pw)
#   error_username = username_error_message(@user)

#   if error_pw || error_username
#     session[:message] = error_username || error_pw
#     status 422
#     erb :signup
#   else
#     add_user_to_file(@user, pw)
#     create_user_file(@user)
#     session[:username] = @user
#     session[:message] = "Welcome #{@user}, please set a default budget below."
#     redirect '/'
#   end
# end

not_found do
  session[:message] = 'Path not found :('
  redirect '/'
end
