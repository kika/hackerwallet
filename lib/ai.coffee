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
  return null
