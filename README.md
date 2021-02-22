# Bill Tracker App
For LS Sinatra practice

An app that keeps track of monthly bills

## Features
<!-- 1. user can define a monthly budget -->
<!-- 2. user cann add values from bills he received -->
<!-- 2.1. user can delete bills -->
xx 2.2 user can change monthly budget
xx 3. user can set up categories he wants to spend money on
<!-- 4. display remaining spending money for the month -->
<!-- 5. display how much money was spend in a month or year -->
<!-- 6. user has to log in before he can use the app -->
7. each user tracks his own values and can only see those

use rubocop to test files

## Implementation
sign up page
  if a user doesnt have an accoun he can sign up through a button on the login
    page
  he needs to have a valid username
    an email address
  a password
    at least 4 chars, an uppercase and a number

  after sign up he is logged in
  a default template is created
    name -> username
    default budget: 0

  a welcome message is displayed
    it should tell him to define a default budget


## Tests
<!-- test successful sign up -->
<!--   post sign up -> username: mark@test.de, password: Test1 -->

<!--   message welcome mark@test.de, please set a default budget below -->
<!--   status 302 -->
<!--   asswert session username -> mark@test.de -->

<!-- test unsuccessful sign up username -->
<!--   post sign up -> username: mark -->

<!--   body -->    
<!--   message, please use an email as a username --> 
<!--   assert session username is nil -->
<!--   status 422 -->

<!-- test unsuccesssful sign up password -->
<!--   post sign up -> mark@test.de, password test -->

<!--   in body -->
<!--   message the password needs to contain 4 chars and at least 1 uppercase and 1 -->
<!--   number -->
<!--   assert session username is nil -->
<!--   status 422 -->


<!-- create test that username does not already exist -->


# HTML

## Ruby
<!-- validate input -->
<!--   username -->
<!--   password -->

<!-- if error --> 
<!--   show sign up page again -->
<!--   422 -->
<!--   with @username -->
<!--   with error message -->


<!-- load the users.yaml --> 
<!-- create new password from username -->
<!-- add username + password to hash -->

<!-- write hash to users yaml -->

<!-- create a new userfile in data with username.yaml from template -->
<!--   set default budget zero -->
<!--   set name to username -->

<!-- set message to welcome username + intro message -->
<!-- set session username to username -->
<!-- redirect to index -->

### how is the budget tracked?
in a yaml file for each user
a hash {
  name:
  default_budget: 0
  spending: { 
    2021: {
      month {
        monthly_budget: 0
        bills: [
          { id: 'datetime'
            date:
            amount: 333
            vendor: 'apple'
          }]}}}}

