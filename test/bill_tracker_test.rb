ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'minitest/reporters'
require 'rack/test'
require 'fileutils'

MiniTest::Reporters.use!

require_relative '../bill_tracker.rb'

class BillTrackerTest < MiniTest::Test
  include Rack::Test::Methods

  def create_dummy_user
    user = {
      name: 'admin',
      default_budget: '500',
      spending: {
        2021 => {
          2 => {
            monthly_budget: '500',
            bills: [
              id: '20210206135254',
              date: '2021-02-05',
              vendor: 'Apple',
              amount: '100'
            ]}}}}
  end

  def setup
    FileUtils.mkdir(data_path)
    user_path = File.join(data_path, 'admin.yaml')
    File.write(user_path, create_dummy_user.to_yaml)

    users_path = File.join(config_path, 'users.yaml')
    File.open(users_path, 'a') do |file|
      file.puts '---'
      file.puts 'admin: $2a$12$fd0HQjk34JvSuvZr77eIMuzCtGtF4VuuDCzPrXt4VOmM2wwlgIhCm'
    end
  end

  def teardown
    FileUtils.rm_r(data_path)
    File.delete(File.join(config_path, 'users.yaml'))
  end

  def app
    Sinatra::Application
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin" } }
  end

  def test_index_for_budget
    get '/', { }, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'monthly budget'
    assert_includes last_response.body, 'Change Budget'
    assert_includes last_response.body, 'admin'
  end

  def test_index_for_add_bill_form
    get '/', { }, admin_session

    assert_includes last_response.body, 'Amount'
    assert_includes last_response.body, 'Date'
    assert_includes last_response.body, 'Vendor'
    assert_includes last_response.body, '/add_bill'
    assert_includes last_response.body, '<button'
  end

  def test_index_for_showing_bills
    get '/', { }, admin_session

    assert_includes last_response.body, 'The monthly budget is:'
    assert_includes last_response.body, '2021'
    assert_includes last_response.body, 'February'
    assert_includes last_response.body, 'Amount: 100'
    assert_includes last_response.body, 'Vendor: Apple'
    assert_includes last_response.body, 'Date: 2021-02-05'
  end

  def test_index_money_left_in_a_month
    get '/', { }, admin_session

    assert_includes last_response.body, 'Sum of bills: 100'
    assert_includes last_response.body, 'You still have 400.0 left to spend'
  end

  def test_index_money_deficit
    bill = {date: '2021-01-01', amount: '600.0', vendor: 'DM' }
    post '/add_bill', bill, admin_session
    get last_response['Location']

    assert_includes last_response.body, 'Sum of bills: 600.0'
    assert_includes last_response.body, 'You have a deficit of -100.0'
  end

  def test_index_budget_consumed
    bill = {date: '2021-01-01', amount: '500', vendor: 'DM' }
    post '/add_bill', bill, admin_session
    get last_response['Location']

    assert_includes last_response.body, 'Sum of bills: 500.0'
    assert_includes last_response.body, 'Your budget has been completely consumed'
  end

  def test_invalid_budget
    post '/change_budget', { new_budget: -1 }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'The new budget needs to be >= 0 but can be a float'
  end

  def test_valid_budget
    post '/change_budget', { new_budget: 500 }, admin_session

    assert_equal 302, last_response.status
    assert_equal 'The budget has been updated', session[:message]

    get last_response['Location']

    assert_includes last_response.body, 'Your monthly budget is: 500'
  end

  def test_add_bill
    bill = {date: '2021-01-01', amount: '3.33', vendor: 'DM' }
    post '/add_bill', bill, admin_session

    assert_equal 'The bill has been added', session[:message]

    get '/'

    assert_includes last_response.body, 'Date: 2021-01-01'
    assert_includes last_response.body, 'Amount: 3.33'
    assert_includes last_response.body, 'Vendor: DM'
  end

  def test_invalid_amount_on_add_bill
    bill = {date: '2021-01-01', amount: 'abc', vendor: 'DM' }
    post '/add_bill', bill, admin_session

    assert_includes last_response.body, 'The amount needs to be a decimal number (ie. 12.34)'
    refute_includes last_response.body, 'Date: 2021-01-01'
    refute_includes last_response.body, 'Vendor: DM'
  end

  def test_invalid_vendor_on_add_bill
    bill = {date: '2021-01-01', amount: '3.33', vendor: 'D' }

    post '/add_bill', bill, admin_session
    assert_includes last_response.body, 'The vendor needs to have at least two chars'
    refute_includes last_response.body, 'Date: 2021-01-01'
    refute_includes last_response.body, 'Amount: 3.33'
  end

  def test_delete_bill
    bill = {date: '2021-01-01', amount: '3.33', vendor: 'weird_vendor' }
    post '/add_bill', bill, admin_session

    get '/'
    assert_includes last_response.body, 'Vendor: weird_vendor'

    bill_id = last_response.body.scan(/\d{14}/).last

    post "/#{bill_id}/delete?year=2021&month=1"
    assert_equal 'The bill has been deleted', session[:message]

    assert_equal last_response.status, 302
    get last_response['Location']
    refute_includes last_response.body, 'Vendor: weird_vendor'
  end

  def test_delete_non_existing_bill
    post "/000/delete?year=2021&month=1", {}, admin_session
    assert_equal 422, last_response.status

    get last_response['Location']
    assert_includes last_response.body, 'The bill does not exist'
  end

  def test_log_in_page
    get "/login"

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Username:'
    assert_includes last_response.body, 'Password:'
    assert_includes last_response.body, 'Log In</button>'
    assert_includes last_response.body, 'Sign Up</a>'
  end

  def test_sign_up_page
    get "/signup"

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Username:'
    assert_includes last_response.body, 'Password:'
    assert_includes last_response.body, 'Sign Up</button>'
    assert_includes last_response.body, 'Log In</a>'
  end

  def test_successful_log_in
    post '/login', username: 'admin', password: 'test'

    assert_equal 'admin', session[:username]
    assert_equal 'Welcome admin', session[:message]
  end

  def test_invalid_login
    post '/login', username: 'admin', password: 'test1'

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Username / Password invalid'
  end

  def test_logout
    post '/logout', {}, admin_session

    assert_equal 'You have been logged out', session[:message]
    assert_nil session[:username]
  end

  def test_signup_successful
    post '/signup', username: 'mark', password: 'Test1'

    assert_equal 'Welcome mark, please set a default budget below.', session[:message]
    assert_equal 302, last_response.status
    assert_equal 'mark', session[:username]
    assert File.exist?(File.join(data_path, 'mark.yaml'))

    users = load_users_file
    assert_includes users.keys, 'mark'
  end

  def test_signup_wrong_username_already_taken_case_insensitive
    post '/signup', username: 'Admin', password: 'Test1'

    assert_equal 422, last_response.status
    refute_equal 'admin', session[:username]
    assert_includes last_response.body, 'This username has already been taken'
  end

  def test_signup_wrong_username_already_taken
    post '/signup', username: 'admin', password: 'Test1'

    assert_equal 422, last_response.status
    refute_equal 'admin', session[:username]
    assert_includes last_response.body, 'This username has already been taken'
  end

  def test_signup_wrong_username_invalid_chars
    post '/signup', username: 'mark.', password: 'Test1'

    assert_equal 422, last_response.status
    refute_equal 'mark.', session[:username]
    assert_includes last_response.body, 'Your username must contain at least to letters or numbers'
  end

  def test_signup_wrong_username_short
    post '/signup', username: 'm', password: 'Test1'

    assert_equal 422, last_response.status
    refute_equal 'm', session[:username]
    assert_includes last_response.body, 'Your username must contain at least to letters or numbers'
  end

  def test_signup_wrong_password_too_short
    post '/signup', username: 'mark', password: 'Te1'

    assert_equal 422, last_response.status
    refute_equal 'mark', session[:username]
    assert_includes last_response.body, 'The password needs to contain at least 4 chars'
  end

  def test_signup_wrong_password_no_uppercase
    post '/signup', username: 'mark', password: 'test1'

    assert_equal 422, last_response.status
    refute_equal 'mark', session[:username]
    assert_includes last_response.body, 'The password has to have at least 1 upper case letter'
  end
  def test_signup_wrong_password_no_number
    post '/signup', username: 'mark', password: 'Test'

    assert_equal 422, last_response.status
    refute_equal 'mark', session[:username]
    assert_includes last_response.body, 'The password needs to have a least 1 number'
  end
end
