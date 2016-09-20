util     = require 'util'
crypto   = require 'crypto'
Promise  = require 'bluebird'
opath    = require 'object-path'
jquery   = require 'cheerio'
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

amazondate = (d) ->
  d = new Date(Date.parse(d))
  return d.getFullYear() +
         ("00" + (d.getMonth() + 1)).slice(-2) +
         ("00" + d.getDate()).slice(-2)

# creates an idempotent signature of an object
chksum = (val) ->
  hash = crypto.createHash('sha1')
  for k,v of val
    hash.update( "" + v )
  return hash.digest('hex')

# Converts Amazon Store Card transaction dumped from HTML to OFX
amazon2ofx = (at) ->
  DTPOSTED: amazondate(at.TRANS_DATE)
  TRNTYPE:  'DEBIT'
  REFNUM:   at.REF_NUM || chksum( at )
  TRNAMT:   - (at.TRANS_AMOUNT - 0.0)
  NAME:     at.TRANS_DESC

# Parse string with OFX data
_ofx_parse = (data, cb) -> Banking.parse( data, (res) -> cb( null, res ) )

module.exports =
# retrieve transactions from the body of the response and always return
# an array
parse: (body) ->
  # first test if this is an array already, then it's probably from HTML
  return body if Array.isArray body
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

# Parses HTML saved from Amazon Store Card account
html_parse: (data) ->
  $ = jquery.load( data )
  json = $('#completedBillingActivityJSONArray').val()
  arr = JSON.parse( json )
  if arr
    return Promise.resolve(
      header: ""
      body:   arr.map(amazon2ofx)
      xml:    json # well, not really, but for compatibility with ofx_parse
    )
  else
    return Promise.reject( "No data in HTML file" )

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
