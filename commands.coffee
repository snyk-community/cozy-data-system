Client = require("request-json").JsonClient
path = require 'path'
fs = require 'fs'

switch  process.argv[2]
    when 'test-install'
        slug = process.argv[3]
        permFile = process.argv[4] or '../package.json'
        packagePath = path.join process.cwd(), permFile

        try
            packageData = JSON.parse(fs.readFileSync(packagePath, 'utf8'))
        catch e
            console.log "Could not read package.json"
            console.log e.stack
            process.exit 2

        data =
            docType: "Application"
            state: 'installed'
            slug: slug
            name: slug
            password: 'apptoken'
            permissions: {}
            port: 42

        for doctype, perm of packageData['cozy-permissions']
            data.permissions[doctype.toLowerCase()] = perm

        client = new Client "http://localhost:9101/"
        client.setBasicAuth 'home', 'token'
        client.post "data/", data, (err, res, body) ->
            if err
                console.log "Cannot create app"
                console.log err.stack
                process.exit 3

            console.log "App created"
            process.exit 0

    else
        console.log "Wrong commang"
        process.exit 1