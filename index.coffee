#!/usr/bin/env coffee
Promise  = require 'bluebird'
goog     = require 'googleapis'
util     = require 'util'
colors   = require 'colors/safe'
fs       = Promise.promisifyAll( require( 'fs' ), suffix: 'A' )
moment   = require 'moment'
authlib  = require './lib/auth'
parse    = require './lib/parse'
u        = require './lib/utils'

config  = require './config'

argv     = require 'yargs'
  .usage(    'Usage: $0 [options]')
  .alias(    'f', 'file')
  .nargs(    'f', 1)
  .describe( 'f', 'Load OFX transactions from file, requires --bank')
  .alias(    'b', 'bank')
  .nargs(    'b', 1)
  .describe( 'b', 'Bank short name for the first column of transaction log' +
                  ' (only for loading from file)')
  .implies(  'f', 'b')
  .implies(  'b', 'f')
  .alias(    's', 'start')
  .nargs(    's', 1)
  .describe( 's', 'Start date (default - first of the current month)')
  .alias(    'e', 'end')
  .nargs(    'e', 1)
  .describe( 'e', 'End date (default - today)')
  .epilogue( 'Dates are in YYYYMMDD format')
  .help()
  .argv

# Promisify Google APIs
sheetApi = Promise.promisifyAll goog.sheets('v4').spreadsheets, suffix: 'A'
valueApi = Promise.promisifyAll goog.sheets('v4').spreadsheets.values, suffix: 'A'

# Create Google API requests to create Sheets
create_missing_sheets = (s) ->
  newsheets = {}
  r = []
  for t in s.transactions
    unless s.sheets[t.shname] || newsheets[t.shname]
      newsheets[t.shname] = yes
  for shname in Object.keys newsheets
    r.push( addSheet: properties: title: shname )
  return r

# Create data for Google API request to append cells to the sheet
create_table_value = (t) ->
  values = []
  values.push( userEnteredValue: stringValue: t.name )
  values.push( userEnteredValue: stringValue: t.id )
  values.push( userEnteredValue: stringValue: t.date )
  values.push( userEnteredValue: stringValue: t.type )
  values.push( userEnteredValue: numberValue: t.amount )
  values.push( userEnteredValue: stringValue: t.trname )
  values.push( userEnteredValue: stringValue: t.memo )
  values.push( userEnteredValue: stringValue: t.category ) if t.category
  return values: values

# Read OFX file (usually called Web Connect or something) and return 
# the array with transactions
read_data = (name, file, dates) ->
  u.info "Reading data from #{file} for #{name} between " +
         "#{dates.start} and #{dates.end}"
  fs.readFileA( file, 'utf8' )
  .then (data) ->
    return parse.ofx_parse( data )
  .then (parsed) ->
    return name: name, transactions: parse.parse( parsed.body )
  .then (bank) ->
    return parse.parse_transactions bank.name, bank.transactions, dates, []

_fetch = (bank, dates, cb) ->
  u.info "Fetching online data from #{bank.name} between " +
         "#{dates.start} and #{dates.end}"
  bank.object.getStatement(
    start: dates.start
    end:   dates.end
    (err, res) ->
      if err
        cb res
      else
        cb( null, {transactions: parse.parse( res.body ), name: bank.name} )
  )
fetch = Promise.promisify _fetch
    
# Fetch OFX data from online bank and return the array with transactions
fetch_data = (banks, dates) ->
  return Promise.map( banks, (bank) -> fetch( bank, dates ) )
  .then (fbanks) ->
    parsed = []
    for bank in fbanks
      # Checking dates again seems to be stupid, but it's not
      parsed = parse.parse_transactions bank.name, bank.transactions, dates, parsed
    return parsed

# Retrieves transactions either from the file or from online sources
# depending on command line options
get_data = () ->
  dates = {}
  dates.start = argv.start || moment().format('YYYYMM01')
  dates.end   = argv.end   || moment().format('YYYYMMDD')
  u.info "Selected date range: #{dates.start} - #{dates.end}"
  if argv.file
    return read_data( argv.bank, argv.file, dates )
  else
    return fetch_data( config.banks, dates )

# Main entry point
# Authenticate to Google and run the file/online data fetch and then
# upload the data to the Google Sheets
authlib.run_authenticated (auth) ->
  Promise.join(
    sheetApi.getA( { auth: auth, spreadsheetId: config.spreadsheetId} ),
    get_data(),
    (res, transactions) ->
      sheets = {}
      for s in res.sheets
        sheets[s.properties.title] = id: s.properties.sheetId
      return sheets: sheets, transactions: transactions, reqs: []
  )
  .then (s) ->
    s.reqs = create_missing_sheets s
    return s
  .then (s) ->
    # create sheets if necessary, fall through if not
    if s.reqs.length
      u.info "Will create #{s.reqs.length} new sheets"
      return sheetApi.batchUpdateA(
        auth: auth
        spreadsheetId: config.spreadsheetId
        resource: requests: s.reqs
      )
      .then (add) ->
        for r in add.replies
          u.info "Sheet #{r.addSheet.properties.title} created"
          s.sheets[r.addSheet.properties.title] = id: r.addSheet.properties.sheetId
        s.reqs = []
        return s
    else
      return s
  .then (s) ->
    # Dedup operation:
    # read transaction IDs of the already existing rows
    # this is the column 'B' of each monthly sheet
    ranges = Object.keys(s.sheets)
             .filter((v) -> /\d{2}-20\d{2}/.test(v))
             .map((v) -> "#{v}!B:B")
    return valueApi.batchGetA(
      auth: auth
      spreadsheetId: config.spreadsheetId
      ranges: ranges
      valueRenderOption: 'UNFORMATTED_VALUE'
      majorDimension: 'COLUMNS'
    )
    .then (res) ->
      # Build lookup tables of already existing transaction IDs
      for v in res.valueRanges
        sheet = eval( v.range.split('!')[0] )
        s.sheets[sheet].keys =
          v.values[0].reduce(
            (acc, i) ->
              acc[i] = true
              return acc
            , {}
          )
      return s
  .then (s) ->
    # insert transactions, removing duplicates using IDs retrieved previously
    for t in s.transactions
      unless s.sheets[t.shname]?.keys[t.id]
        s.sheets[t.shname].rows ?= []
        s.sheets[t.shname].rows.push( create_table_value t )
      else
        u.warn "Transaction #{t.id} for #{t.name} amt: #{t.amount} " +
             "already exists"
    for shname, v of s.sheets
      if v?.rows
        s.reqs.push(
          appendCells:
            sheetId: v.id
            rows: v.rows
            fields: 'userEnteredValue'
        )
    if s.reqs.length
      return sheetApi.batchUpdateA(
        auth: auth
        spreadsheetId: config.spreadsheetId
        resource: requests: s.reqs
      )
      .then (res) ->
        # Unfortunately, batchUpdate of multiple sheets is a fire and forget
        # operation: in case of success `res` contains only spreadsheet ID
        # and empty `replies` array. How convenient
        console.dir res, depth: null
  .catch (err) ->
    u.error "API error: " + util.inspect( err, depth: null )
  .finally () -> u.info "Done!"

