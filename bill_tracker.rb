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

def valid_budget?(budget)
  budget.to_i >= 0 && budget =~ /\A+?\d+\z/
end

def write_user_yaml
  File.write(user_path, @user_data.to_yaml)
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
  date = Date.strptime(params[:date], '%Y-%m-%d')
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
