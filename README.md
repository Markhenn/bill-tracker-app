# Bill Tracker App
For LS Sinatra practice

An app that keeps track of monthly bills

## Features
1. user can define a monthly budget
2. user cann add values from bills he received
3. user can set up categories he wants to spend money on
4. display remaining spending money for the month
5. display how much money was spend in a month or year
6. user has to log in before he can use the app
7. each user tracks his own values and can only see those

## Implementation
User can add valies from bills he received
  amount
  date
  vendor name
  id - date+time

first three have to be present
amount needs to be a number
date needs to be a valid date (use picker)
vendor name needs to be at least 2 chars

show the latest 3 bills on index

create add bill button -> bill create page
create show all bills button -> bill display page

add bills on index page
  form with needed values
  add bill button

display all bills on index page
  show bills by year, month


  last three added to array


## Tests
<!-- test bill creation page on index page -->
test show bill display on index page
  need to create a bill in test
  test if that bill is shown on index page

test correct bill is added to user yaml
test invalid bill possibilities
  not a number
  not a date
  vendor less than 2 chars




## HTML
<!-- form to add a bill -->
<!--   date -->
<!--   amount -->
<!--   vendor -->
<!--   button -->

<!-- add bills to index -->

<!-- years -->
<!--   months -->
<!--     bills - date amount vendor -->

    extra sort by date


## Ruby
<!-- add a bill to yaml -->
<!--   create an id from date -->
<!--   load yaml into hash -->
<!--   add bill to spending key -->

<!-- show bills on index page -->

sort bills with helper


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

