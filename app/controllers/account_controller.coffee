load 'application'

Client = require("request-json").JsonClient

Account = require './lib/account'
CryptoTools = require './lib/crypto_tools'
User = require './lib/user'
randomString = require('./lib/random').randomString

accountManager = new Account()

checkProxyHome = require('./lib/token').checkProxyHome
checkDocType = require('./lib/token').checkDocType
cryptoTools = new CryptoTools()
user = new User()
encryption = require('./lib/encryption')
initPassword = require('./lib/init').initPassword
db = require('./helpers/db_connect_helper').db_connect()
correctWitness = "Encryption is correct"


## Before and after methods

# Check if application which want manage encrypted keys is Proxy
before 'permission_keys', ->
    checkProxyHome req.header('authorization'), (err, isAuthorized) =>
        if not isAuthorized
            err = new Error("Application is not authorized")
            send error: err, 403
        else
            next()
, only: ['initializeKeys','updateKeys', 'deleteKeys', 'resetKeys']

# Check if application is authorized to manage EncryptedKeys sdocType
before 'permission', ->
    auth = req.header('authorization')
    checkDocType auth, "Account",  (err, appName, isAuthorized) =>
        if not appName
            err = new Error("Application is not authenticated")
            send error: err, 401
        else if not isAuthorized
            err = new Error("Application is not authorized")
            send error: err, 403
        else
            compound.app.feed.publish 'usage.application', appName
            next()
, only: ['createAccount', 'findAccount', 'existAccount', 'updateAccount',
        'upsertAccount', 'deleteAccount', 'deleteAllAccounts', 'mergeAccount']

# Recover doc from database  with id equal to params.id
# and check if decryption of witness is correct
before 'get doc with witness', ->
    # Recover doc
    db.get params.id, (err, doc) =>
        if err and err.error is "not_found"
            send 404
        else if err
            console.log "[Get doc] err: #{err}"
            send 500
        else if doc?
            if app.crypto? and app.crypto.masterKey and app.crypto.slaveKey
                slaveKey = cryptoTools.decrypt app.crypto.masterKey,
                    app.crypto.slaveKey
                if doc.witness?
                    try
                        # Check witness decryption
                        witness = cryptoTools.decrypt slaveKey, doc.witness
                        if witness is correctWitness
                            @doc = doc
                            next()
                        else
                            console.log "[Get doc] err: data are corrupted"
                            send 402
                    catch err
                        console.log "[Get doc] err: data are corrupted"
                        send 402
                else
                    # Add witness in document for the next time
                    witness = cryptoTools.encrypt slaveKey, correctWitness
                    db.merge params.id, witness: witness, (err, res) =>
                        if err
                            console.log "[Merge] err: #{err}"
                            send 500
                        else
                            @doc = doc
                            next()
            else
                console.log "err : master key and slave key don't exist"
                send 500
        else
            send 404
, only: ['findAccount', 'updateAccount', 'mergeAccount']

# Recover document from database with id equal to params.id
before 'get doc', ->
    db.get params.id, (err, doc) =>
        if err and err.error is "not_found"
            send 404
        else if err
            console.log "[Get doc] err: #{err}"
            send 500
        else if doc?
            @doc = doc
            next()
        else
            send 404
, only: ['deleteAccount']


## Helpers

## function encryptPassword (body, callback)
## @body {Object} Application:
##    * body.password : password to be encrypted
## @callback {function} Continuation to pass control back to when complete.
## Encrypt password of application and add docType "Account"
encryptPassword = (body, callback)->
    app = compound.app
    if body.password
        if app.crypto? and app.crypto.masterKey and app.crypto.slaveKey
            slaveKey =
                cryptoTools.decrypt app.crypto.masterKey, app.crypto.slaveKey
            newPwd = cryptoTools.encrypt slaveKey, body.password
            body.password = newPwd
            body.docType = "Account"
            witness = cryptoTools.encrypt slaveKey, correctWitness
            body.witness = witness
            callback true
        else
            callback false, new Error("master key and slave key don't exist")
    else
        callback false

## function toString ()
## Helpers to hide password in logger
toString = ->
    "[Account for model: #{@id}]"


## Actions

#POST /accounts/password/
action 'initializeKeys', =>
    user.getUser (err, user) ->
        if err
            console.log "[initializeKeys] err: #{err}"
            send 500
        else
            ## User has already been connected
            if user.salt? and user.slaveKey?
                encryption.logIn body.password, user, (err)->
                    send error: err, 500 if err?
                    initPassword () =>
                        send success: true
            ## First connection
            else
                encryption.init body.password, user, (err)->
                    if err
                        send error: err, 500
                    else
                        send success: true


#PUT /accounts/password/
action 'updateKeys', ->
    if body.password?
        user.getUser (err, user) ->
            if err
                console.log "[updateKeys] err: #{err}"
                send 500
            else
                encryption.update body.password, user, (err) ->
                    if err? and err is 400 
                        send 400
                    else if err
                        send error: err, 500
                    else
                        send success: true
    else
        send 500


#DELETE /accounts/reset/
action 'resetKeys', ->
    user.getUser (err, user) ->
        if err
            console.log "[initializeKeys] err: #{err}"
            send 500
        else
            encryption.reset user, (err) ->
                if err
                    send error:err, 500
                else
                    send success: true, 204


#DELETE /accounts/
action 'deleteKeys', ->
    encryption.logOut (err) ->
        if err
            send error: err, 500
        else
            send sucess: true, 204


