
patterns = [
    p: /CAFF?E/i
    c: 'Dining'
  ,
    p: /restaurant/i
    c: 'Dining'
  ,
    p: /caltrain/i
    c: 'Commute'
  ,
    p: /pivotal labs/i
    c: 'Services'
  ,
    p: /safeway/i
    c: 'Food'
  ,
    p: /costco/i
    c: 'Food'
  ,
    p: /sigona/i
    c: 'Food'
  ,
    p: /comcast/i
    c: 'Internet'
  ,
    p: /whole foods/i
    c: 'Food'
  ,
    p: /klwines/i
    c: 'Wine'
  ,
    p: /Check/i
    a: 55
    c: 'Services'
  ,
    p: /pgande/i
    c: 'Utilities'
  ,
    p: /Finance charge/i
    c: 'Fees'
  ,
    p: /Doordash/i
    c: 'Doordash'
  ,
    p: /robert's market/i
    c: 'Food'
]

module.exports =
# transaction record:
# name:   bank name as defined in the config file or on the command line
# type:   DEBIT or CREDIT
# id:     supposedly unique ID from financial institution
# date:   date in 'YYYYMMDD' format
# amount: transaction amount as positive or negative real number
# trname: transaction name
# trmemo: memo (could be name or phone number or virtually anything)
# shname: name of the sheet (MM-YYYY)
# 
# returns string to put in the column 'G'
classify: (transaction) ->
  for p in patterns
    if p.p.test transaction.trname
      if p.a
        if p.a == transaction.amount
          return p.c
      else
        return p.c
  return null
