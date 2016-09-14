util     = require 'util'
Promise  = require 'bluebird'
opath    = require 'object-path'
Banking  = require 'banking'
u        = require './utils'
ai       = require './ai'

path = [ "OFX.CREDITCARDMSGSRSV1.CCSTMTTRNRS.CCSTMTRS.BANKTRANLIST.STMTTRN",
         "OFX.BANKMSGSRSV1.STMTTRNRS.STMTRS.BANKTRANLIST.STMTTRN" ]
msgpath = "OFX.SIGNONMSGSRSV1.SONRS.STATUS"

date_re = /(\d{4})(\d{2})(\d{2})/

parsedate = (d) ->
  m = d.match date_re
  if m
    return date: "#{m[2]}/#{m[3]}/#{m[1]}", sheetname: "#{m[2]}-#{m[1]}"
  return d

date_between = (date, dates) ->
  d = date.slice( 0, 8 )
  return d >= dates.start and d <= dates.end

parse_transaction = (name, transaction, dates) ->
  t = transaction
  return if t
      if date_between( t.DTPOSTED, dates )
        d = parsedate t.DTPOSTED
        name:   name
        type:   t.TRNTYPE
        id:     t.FITID || t.REFNUM
        date:   d.date
        amount: t.TRNAMT
        trname: t.NAME
        trmemo: t.MEMO || ""
        shname: d.sheetname
      else
        u.warn "Transaction for #{name} for #{t.TRNAMT} skipped due to the date range"
        null
    else
      u.error( "Can't parse transaction: #{name} " +
             util.inspect( t, depth: null ) )
      null

# Parse string with OFX data
_ofx_parse = (data, cb) -> Banking.parse( data, (res) -> cb( null, res ) )

module.exports =
# retrieve transactions from the body of the response and always return
# an array
parse: (body) ->
  # try credit card or bank statement, they are mutually exclusive
  # and only one will work
  res = opath.get(body, path[0]) || opath.get(body, path[1])
  return if Array.isArray res then res else [res]
#
# Convert statement OFX transactions into an array of our transaction records
parse_transactions: (name, transactions, dates, acc) ->
  for t in transactions
    p = parse_transaction( name, t, dates )
    if p
      p.category = ai.classify( p )
      acc.push p
  return acc

ofx_parse: Promise.promisify _ofx_parse

# returns OFX message record
#   CODE: 'numeric code'
#   SEVERITY: 'ERROR' or else
#   MESSAGE:  'text message'
get_msg: (body) ->
  msg = opath.get( body, msgpath )
  if msg
    msg.MESSAGE ?= ""
    msg.MESSAGE += " CODE: #{msg.CODE}"
  return msg
