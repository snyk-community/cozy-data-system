should = require('chai').Should()
async = require('async')
Client = require('../common/test/client').Client
app = require('../server')

client = new Client("http://localhost:8888/")

# connection to DB for "hand work"
cradle = require 'cradle'
connection = new cradle.Connection
    cache: true,
    raw: false
db = connection.database('cozy')

# helpers

cleanRequest = ->
    delete @body
    delete @response

parseBody = (response, body) ->
    if typeof body is "object" then body else JSON.parse body

randomString = (length=32) ->
    string = ""
    string += Math.random().toString(36).substr(2) while string.length < length
    string.substr 0, length

# Clear DB, create a new one, then init data for tests.
before (done) ->
    db.destroy ->
        console.log 'DB destroyed'
        db.create ->
            console.log 'DB recreated'
            db.save '321', {"value":"val"}, ->
                done()

# Start application before starting tests.
before (done) ->
    app.listen(8888)
    done()

# Stop application after finishing tests.
after (done) ->
    app.close()
    done()



describe "Existence", ->
    describe "Check Existence of a Document that does not exist in database", ->
        before cleanRequest

        it "When I send a request to check existence of Document with id 123", \
                (done) ->
            client.get "data/exist/123/", (error, response, body) =>
                response.statusCode.should.equal(200)
                @body = parseBody response, body
                done()

        it "Then {exist: false} should be returned", ->
            should.exist @body.exist
            @body.exist.should.not.be.ok

    describe "Check Existence of a Document that does exist in database", ->
        before cleanRequest

        it "When I send a request to check existence of Document with id 321", \
                (done) ->
            client.get "data/exist/321/", (error, response, body) =>
                response.statusCode.should.equal(200)
                @body = parseBody response, body
                done()

        it "Then {exist: true} should be returned", ->
            should.exist @body.exist
            @body.exist.should.be.ok



describe "Find", ->
    describe "Find a Document that does not exist in database", ->
        before cleanRequest

        it "When I send a request to get Document with id 123", (done) ->
            client.get "data/123/", (error, response, body) =>
                @response = response
                done()

        it "Then error 404 should be returned", ->
            @response.statusCode.should.equal(404)

    describe "Find a Document that does exist in database", ->
        before cleanRequest

        it "When I send a request to get Document with id 321", (done) ->
            client.get 'data/321/', (error, response, body) =>
                response.statusCode.should.equal(200)
                @body = parseBody response, body
                done()

        it "Then { _id: '321', value: 'val'} should be returned", ->
            @body.should.deep.equal {"_id": '321', "value":"val"}

describe "Create", ->
    describe "Try to Create a Document existing in Database", ->
        before cleanRequest

        it "When I send a request to create a document with id 321", (done) ->
            client.post 'data/321/', {"value":"created value"}, \
                        (error, response, body) =>
                @response = response
                done()

        it "Then error 409 should be returned", ->
            @response.statusCode.should.equal(409)

    describe "Create a new Document with a given id", ->
        before cleanRequest
        after ->
            delete @randomValue

        it "When I send a request to create a document with id 987", (done) ->
            @randomValue = randomString()
            client.post 'data/987/', {"value":@randomValue}, \
                        (error, response, body) =>
                response.statusCode.should.equal 201
                @body = parseBody response, body
                done()

        it "Then { _id: '987' } should be returned", ->
            @body.should.have.property '_id', '987'

        it "Then the Document with id 987 should exist in Database", (done) ->
            client.get "data/exist/987/", (error, response, body) =>
                @body = parseBody response, body
                @body.exist.should.be.true
                done()

        it "Then the Document in DB should equal the sent Document", (done) ->
            client.get "data/987/", (error, response, body) =>
                @body = parseBody response, body
                @body.should.have.property 'value', @randomValue
                done()

    describe "Create a new Document without an id", ->
        before cleanRequest
        after ->
            delete @randomValue
            delete @_id

        it "When I send a request to create a document without an id", (done) ->
            @randomValue = randomString()
            client.post 'data/', {"value":@randomValue}, \
                        (error, response, body) =>
                response.statusCode.should.equal(201)
                @body = parseBody response, body
                done()

        it "Then the id of the new Document should be returned", ->
            @body.should.have.property '_id'
            @_id = @body._id

        it "Then the Document should exist in Database", (done) ->
            client.get "data/exist/" + @_id + "/", (error, response, body) =>
                @body = parseBody response, body
                @body.exist.should.be.true
                done()

        it "Then the Document in DB should equal the sent Document", (done) ->
            client.get "data/" + @_id + "/", (error, response, body) =>
                @body = parseBody response, body
                @body.should.have.property 'value', @randomValue
                done()

describe "Update", ->
    describe "Try to Update a Document that doesn't exist", ->
        before cleanRequest

        it "When I send a request to update a Document with id 123", (done) ->
            client.put 'data/123/', {"value":"created_value"}, \
                        (error, response, body) =>
                @response = response
                done()

        it "Then error 404 should be returned", ->
            @response.statusCode.should.equal 404

    describe "Update a modified Document in DB (concurrent access)", ->
        before cleanRequest

    describe "Update a Document (no concurrent access)", ->
        before cleanRequest
        after ->
            delete @randomValue

        it "When I send a request to update Document with id 987", (done) ->
            @randomValue = randomString()
            client.put 'data/987/', {"new_value":@randomValue}, \
                        (error, response, body) =>
                @response = response
                done()

        it "Then HTTP status 200 should be returned", ->
            @response.statusCode.should.equal 200

        it "Then the Document should exist in DataBase", (done) ->
            client.get "data/exist/987/", (error, response, body) =>
                @body = parseBody response, body
                @body.exist.should.be.true
                done()

        it "Then the old Document must have been replaced", (done) ->
            client.get "data/987/", (error, response, body) =>
                @body = parseBody response, body
                @body.should.not.have.property 'value'
                @body.should.have.property 'new_value', @randomValue
                done()
