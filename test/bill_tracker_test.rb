ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'minitest/reporters'
require 'rack/test'

MiniTest::Reporters.use!

require_relative '../bill_tracker.rb'

class BillTrackerTest < MiniTest::Test
  include Rack::Test::Methods

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
end
