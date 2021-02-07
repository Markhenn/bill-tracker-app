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
    user_path = File.join(data_path, '/admin.yaml')
    File.write(user_path, create_dummy_user.to_yaml)
  end

  def teardown
    FileUtils.rm_r(data_path)
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

  def test_invalid_budget
    post '/change_budget', { new_budget: -1 }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'The new budget needs to be equal 0 or bigger'
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
end
