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
6. user has to log in before he can use the app
7. each user tracks his own values and can only see those

use rubocop to test files

## Implementation
create a login page
create a sign up page

put check in before to login

create sign out button on index

login page
  contains email and password fiedsl
  button log in
  button for sign up as well



## Tests
Test loggin in

post to /login, username: 'admin', pw: xxx
  session message -> Welcome admin
  redirect to /

Test not succesful login
  post to login 
    in body session message -> Username / password invalid
    status 404



# HTML
nothing

## Ruby
set up users.yaml file and for test

post login
  read array of hashes from users.yaml
  check if username exists in database
  check if pw hashed matches the saved one for username

  yes
    welcome admin
    set session[:username] to admin
    redirect /

  no
    message username password invalid
    erb /login


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

