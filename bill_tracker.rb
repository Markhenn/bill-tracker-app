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
    pp year_values
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

def all_bills
  bills = []
  @user_data[:spending].each do |_, months|
    months.each do |_, content|
      content.each do |key, values|
        bills += values if key == :bills
      end
    end
  end
  bills
end

def valid_amount?(amount)
  amount =~ /\A[+-]?\d+(\.\d{1,2})?\z/
end

def valid_vendor?(vendor)
  vendor =~ /\w{2,}/
end

def invalid_budget?(budget)
  budget !~ /\A+?\d+(\.?\d{1,2})\z/
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

def sum_of_bills(bills)
  bills.reduce(0) { |sum, bill| sum + bill[:bill_amount] }.round(2)
end

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

def get_date_data(html_date)
  date = parse_date(html_date)
  spending = @user_data[:spending]
  spending[date.year] = {} if spending[date.year].nil?

  year = spending[date.year]

  default_budget = @user_data[:default_budget]
  year[date.month] = { monthly_budget: default_budget, bills: [] } if year[date.month].nil?
  date
end

before do
  # @user_data = load_user('admin')
  @storage = DatabasePersistance.new(logger)
  userid = '1'
  @user_data = @storage.user_data(userid)
  @budget = @user_data[2]
end

get '/' do
  # logged_in?
  # @budget = @user_data[:default_budget]
  # @spending = @user_data[:spending]

  redirect '/full_budget'
  # erb :index
end

get '/full_budget' do
  # logged_in?
  # @budget = @user_data[:default_budget]
  # @spending = @user_data[:spending]

  @full_budget = @storage.full_budget
  erb :full_budget
end

get '/users/change_default_budget' do
  # logged_in?
  erb :change_default_budget
end

post '/users/change_default_budget' do
  # logged_in?
  new_budget = params[:new_budget]

  if invalid_budget?(new_budget)
    @new_budget = new_budget
    status 422
    session[:message] = 'The new budget needs to be >= 0 but can be a float'
    erb :change_budget
  else
    @user_data[:default_budget] = new_budget
    write_user_yaml(session[:username])
    session[:message] = 'The budget has been updated'
    redirect '/'
  end
end

get '/budgets/:monthly_budget_id' do
end

put '/budgets/:monthly_budget_id' do
end

get '/bills/add' do
  erb :add_bill
end

post '/bills/add' do
  # logged_in?

  error = nil
  error = 'The amount needs to be a decimal number (ie. 12.34)' unless valid_amount?(params[:amount])
  error = 'The vendor needs to have at least two chars' unless valid_vendor?(params[:vendor])

  if error
    @spending = @user_data[:spending]
    @date = params[:date]
    @vendor = params[:vendor]
    @amount = params[:amount]
    session[:message] = error
    status 422
    erb :index
  else
    date = get_date_data(params[:date])

    @user_data[:spending][date.year][date.month][:bills] << {
      id: DateTime.now.strftime('%Y%m%d%H%M%S'),
      date: params[:date],
      vendor: params[:vendor],
      amount: params[:amount]
    }

    write_user_yaml(session[:username])

    session[:message] = 'The bill has been added'
    redirect '/'
  end
end

get '/bills/:bill_id' do

end

put '/bills/:bill_id' do

end

delete '/bills/:bill_id' do
  # logged_in?
  id = params[:id]
  bills = all_bills

  bill_index = bills.index { |bill| bill[:id] == id }

  if !bill_index
    session[:message] = 'The bill does not exist'
    redirect '/', 422
  else
    @user_data[:spending][year][month][:bills].delete_if { |bill| bill[:id] == id }
    write_user_yaml(session[:username])
    session[:message] = 'The bill has been deleted'
    redirect '/'
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
