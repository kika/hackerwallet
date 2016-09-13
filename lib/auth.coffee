Promise  = require 'bluebird'
fs       = require 'fs'
readline = require 'readline'
goog     = require 'googleapis'
googAuth = require 'google-auth-library'
u        = require './utils'

scopes     = ['https://www.googleapis.com/auth/spreadsheets']
token_dir  = './'
token_path = token_dir + 'hackerwallet-token.json'

# This file is mostly sample provided by Google

# Authenticate to google and then run the supplied callback
module.exports.run_authenticated = (cb) ->
  # Load client secrets from a local file.
  fs.readFile 'client_secret.json', (err, content) ->
    if (err)
      u.error( 'Error loading client secret file: ' + err )
      return
    # Authorize a client with the loaded credentials, then call the
    # Google Sheets API.
    authorize JSON.parse(content), cb


authorize = (creds, cb) ->
  clientSecret = creds.installed.client_secret
  clientId     = creds.installed.client_id
  redirectUrl  = creds.installed.redirect_uris[0]
  auth         = new googAuth()
  oauth2Client = new auth.OAuth2(clientId, clientSecret, redirectUrl)

  # Check if we have previously stored a token.
  fs.readFile token_path, (err, token) ->
    if (err)
      getNewToken(oauth2Client, cb)
    else
      oauth2Client.credentials = JSON.parse(token)
      cb(oauth2Client)

 # Get and store new token after prompting for user authorization, and then
 # execute the given callback with the authorized OAuth2 client.
 #
 # @param {google.auth.OAuth2} oauth2Client The OAuth2 client to get token for.
 # @param {getEventsCallback} callback The callback to call with the authorized
 #     client.
getNewToken = (oauth2Client, callback) ->
  authUrl = oauth2Client.generateAuthUrl
    access_type: 'offline'
    scope: scopes
  u.info 'Authorize this app by visiting this url: ' + authUrl
  rl = readline.createInterface
    input: process.stdin
    output: process.stdout
  rl.question 'Enter the code from that page here: ', (code) ->
    rl.close()
    oauth2Client.getToken code, (err, token) ->
      if (err)
        u.error( 'Error while trying to retrieve access token: ' + err )
        return
      oauth2Client.credentials = token
      storeToken token
      callback oauth2Client

 # Store token to disk be used in later program executions.
 #
 # @param {Object} token The token to store to disk.
storeToken = (token) ->
  try
    fs.mkdirSync token_dir
  catch err
    if (err.code != 'EEXIST')
      throw err
  fs.writeFile token_path, JSON.stringify(token)
  u.info 'Token stored to ' + token_path

