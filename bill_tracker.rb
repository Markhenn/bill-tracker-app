require 'sinatra'
require 'sinatra/reloader' if development?
require 'yaml'

def data_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/data', __FILE__)
  else
    File.expand_path('../data', __FILE__)
  end
end

helpers do
  def todays_date
    Date.today.strftime('%Y-%m-%d')
  end

  def full_month_name(month, year)
    "#{Date.strptime(month.to_s, '%m').strftime('%B')} #{year}"
  end

  def sort_hash_on_key(hash, &block)
    hash_sorted = hash.sort_by { |hash, _| hash }.reverse
    hash_sorted.each { |hash| yield(hash) }
  end

  def sort_bills(bills, &block)
    bills_sorted = bills.sort do |a, b|
      parse_date(b[:date]) <=> parse_date(a[:date])
    end

    bills_sorted.each { |bill| yield(bill) }
  end

  def show_monthly_summary(value_hash)
    m_budget = "The monthly budget is: #{value_hash[:monthly_budget]}"

    sum = "Sum of bills: #{sum_of_bills(value_hash[:bills])}"

    [m_budget, sum, determine_difference_message(value_hash)].join("</br>")
  end
end

def user_path
  user_file = "#{session[:username]}.yaml"
  File.join(data_path, user_file)
end

def load_user
  YAML.load(File.read(user_path))
end

def write_user_yaml
  File.write(user_path, @user_data.to_yaml)
end

def verify_login
  # check if there is a session[:username] not nil
  # if nil then user has  to log in
  # the :username ist the name: in the yaml file
  session[:username] = 'admin'
end

def all_bills
  bills = []
  @user_data[:spending].each do |_, months|
    months.each do |_, values|
      values.each do |key, values|
        if key == :bills
          bills += values
        end
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

def valid_budget?(budget)
  budget =~ /\A+?\d+(\.?\d{1,2})\z/
end

def parse_date(date_string)
  Date.strptime(date_string, '%Y-%m-%d')
end

def sum_of_bills(bills)
  bills.reduce(0) { |sum, bill| sum += bill[:amount].to_f }.round(2)
end

def determine_difference_message(values)
  sum = sum_of_bills(values[:bills])
  difference = (values[:monthly_budget].to_f - sum).round(2)

  if difference > 0
    "You still have #{difference} left to spend"
  elsif difference < 0
    "You have a deficit of #{difference}"
  else
    'Your budget has been completely consumed'
  end
end

configure do
  enable :sessions
  set :sessions_secret, 'secret'
end

before do
  verify_login
  @user_data = load_user
end

get '/' do 
  @budget = @user_data[:default_budget]
  @spending = @user_data[:spending]
  erb :index
end

get '/change_budget' do
  @budget = @user_data[:default_budget]
  erb :change_budget
end

post '/change_budget' do
  new_budget = params[:new_budget]

  unless valid_budget?(new_budget)
    @new_budget = new_budget
    status 422
    session[:message] = 'The new budget needs to be >= 0 but can be a float'
    erb :change_budget
  else
    @user_data[:default_budget] = new_budget
    write_user_yaml
    session[:message] = 'The budget has been updated'
    redirect '/'
  end
end

post '/add_bill' do
  date = parse_date(params[:date])

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
    id = DateTime.now.strftime('%Y%m%d%H%M%S')
    spending = @user_data[:spending]
    spending[date.year] = {} if spending[date.year].nil?

    year = spending[date.year]
    default_budget = @user_data[:default_budget]
    year[date.month] = {monthly_budget: default_budget, bills: []} if year[date.month].nil?

    @user_data[:spending][date.year][date.month][:bills] << {
      id: id,
      date: params[:date],
      vendor: params[:vendor],
      amount: params[:amount]
    }

    write_user_yaml

    session[:message] = 'The bill has been added'
    redirect '/'
  end
end

post '/:id/delete' do
  year = params[:year].to_i
  month = params[:month].to_i
  id = params[:id]
  bills = all_bills

  bill_index = bills.index { |bill| bill[:id] == id }

  unless bill_index
    session[:message] = "The bill does not exist"
    redirect '/', 404
  else
    @user_data[:spending][year][month][:bills].delete_if { |bill| bill[:id] == id }
    write_user_yaml
    session[:message] = "The bill has been deleted"
    redirect '/'
  end
end
