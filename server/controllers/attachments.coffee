fs = require "fs"
multiparty = require 'multiparty'
log =  require('printit')
    date: true
    prefix: 'attachment'

db = require('../helpers/db_connect_helper').db_connect()
deleteFiles = require('../helpers/utils').deleteFiles
downloader = require '../lib/downloader'


## Actions

# POST /data/:id/attachments/
# Add an attachment via uploading a file through a multipart form.
module.exports.add = (req, res, next) ->

    # Parse given form to extract image blobs.
    form = new multiparty.Form()
    form.parse req

    # Dirty hack to end request if no file were sent when form is fully parsed.
    nofile = true

    fields = {}

    # We read part one by one to avoid writing the full file to the disk
    # and send it directly as a stream.
    form.on 'part', (part) ->

        # It's a field
        unless part.filename?
            fields[part.name] = ''
            part.on 'data', (buffer) ->
                fields[part.name] = buffer.toString()
            part.resume()

        # It's a file, we pipe it directly to Couch to avoid too much memory
        # consumption.
        # The 'file' event from the multiparty form stores automatically
        # the file to the disk and we don't want that.
        else
            nofile = false
            if fields.name?
                name = fields.name
            else
                name = part.filename

            fileData =
                name: name
                "content-type": part.headers['content-type']

            log.info "attachment #{name} ready for storage"

            stream = db.saveAttachment req.doc, fileData, (err) ->
                if err
                    console.log "[Attachment] err: " + JSON.stringify err
                    form.emit 'error', new Error err.error
                else
                    # We end the request because we expect to have only one
                    # file.
                    log.info "Attachment #{name} saved to Couch."
                    res.send 201, success: true
                    next()

            part.pipe stream


    form.on 'progress', (bytesReceived, bytesExpected) ->
        # TODO handle progress

    form.on 'error', (err) ->
        next err

    form.on 'close', ->
        if nofile
            err = new Error 'no file sent'
            err.status = 400
            next err


# GET /data/:id/attachments/:name
# Download given attachment (represented by name) linked to given document
# (represented by id).
module.exports.get = (req, res, next) ->
    name = req.params.name
    id = req.doc.id

    # Perform downloading via the low level downloader to avoir too high
    # memory consumption.
    downloader.download id, name, (err, stream) ->
        if err? and err.error is "not_found"
            err = new Error "not found"
            err.status = 404
            next err
        else if err
            next new Error err.error
        else
            if req.headers['range']?
                stream.setHeader 'range', req.headers['range']

            # Set response header from attachment infos
            length = req.doc._attachments[name].length
            type = req.doc._attachments[name]['content-type']
            res.setHeader 'Content-Length', length
            res.setHeader 'Content-Type', type

            stream.pipe res



# DELETE /data/:id/attachments/:name
# Remove given attachment (represented by name) from given document
# (represented by id).
module.exports.remove = (req, res, next) ->
    name = req.params.name

    db.removeAttachment req.doc, name, (err) ->
        next()
        if err? and err.error = "not_found"
            err = new Error "not found"
            err.status = 404
            next err
        else if err?
            console.log "[Attachment] err: " + JSON.stringify err
            next err # cradle sends a Error object here
        else
            res.send 204, success: true
