require 'sinatra'
require 'sinatra/reloader' if development?
require 'yaml'

def data_path
  if ENV['RACK_TEST'] == 'test'
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
end

def user_path
  user_file = "#{session[:username]}.yaml"
  File.join(data_path, user_file)
end

def load_user
  YAML.load(File.read(user_path))
end

def verify_login
  # check if there is a session[:username] not nil
  # if nil then user has  to log in
  # the :username ist the name: in the yaml file
  session[:username] = 'admin'
end

def valid_amount?(amount)
  amount =~ /\A[+-]?\d+\.?\d{0,2}\z/
end

def valid_vendor?(vendor)
  vendor =~ /\w{2,}/
end

def valid_budget?(budget)
  budget =~ /\A+?\d+\.?\d{0,2}\z/
end

def write_user_yaml
  File.write(user_path, @user_data.to_yaml)
end

def parse_date(date_string)
  Date.strptime(date_string, '%Y-%m-%d')
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
  # p @user_data
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
    session[:message] = 'The new budget needs to be equal 0 or bigger'
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
