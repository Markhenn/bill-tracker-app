# Bill Tracker App
For LS Sinatra practice

An app that keeps track of monthly bills

## Features
<!-- 1. user can define a monthly budget -->
<!-- 2. user cann add values from bills he received -->
<!-- 2.1. user can delete bills -->
2.2 user can change monthly budget
3. user can set up categories he wants to spend money on
4. display remaining spending money for the month
5. display how much money was spend in a month or year
6. user has to log in before he can use the app
7. each user tracks his own values and can only see those

use rubocop to test files

## Implementation



## Tests


## HTML


## Ruby





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

