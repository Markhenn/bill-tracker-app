# Bill Tracker App
For LS Sinatra practice

An app that keeps track of monthly bills

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

## Change App to use a database

### Data Model

Entities
- User
- Bills
- Budgets


User 1 -> N Monthly Values N -> 1 Budget categories 1 -> N Bill


User
id
name
default monthly budget
password

Budget Categories
id
name


monthly Budget
id
value
date beginning
user id
budget category id




Bill
id
amount
payment date
vendor id
budget category id


Vendor
id
name


### How it works
User defines budget categories
User defines money split between categories
User defines overall budget for a month and a default

User tracks bills

System calculates the sum of bills for each category
compares to each budget
tells how much is left for the month
tells how much is left for the day remaining of the month

for past months it tells how much has been saved or been over the budget


there will always be a saved and a generell budget
saved will be used for savings or to add and detract at the end of the month
generell is just so that there is a default



