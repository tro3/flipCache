angular.module 'flipCache', [
]

.factory 'flipCache', ($http, $q) ->

    p = console.log

    hashQuery = (query={}, options={}) ->
        JSON.stringify(
            query: query
            options: options
        )

    hashFields = (fields={}) ->
        JSON.stringify(fields)

    isDocQuery = (query={}) ->
        return Object.keys(query).length == 1 && Object.keys(query)[0] == '_id'

    deepcopy = (obj) ->
        if typeof obj != 'object'
            return obj
        if obj == null
            return obj
        if obj instanceof Array
            return (deepcopy(x) for x in obj)
        result = {}
        for key, val of obj
            if val instanceof Date
                result[key] = deepcopy(val)
                result[key].__proto__ = val.proto
            else
                result[key] = deepcopy(val)
        result


    qGet = (collection, query, fields) ->
        $q (resolve, reject) ->
            url = "/api/#{collection}"
            params = {}
            if Object.keys(query).length > 0
                params.q = JSON.stringify(query)
            if Object.keys(fields).length > 0
                params.fields = JSON.stringify(fields)
            $http(
                method: 'GET',
                url: url
                params: params
            ).success( (data, status, headers, config) ->
                if angular.isDefined(data._status) \
                  and data._status == 'OK'        \
                  and angular.isDefined(data._items)
                    resolve(data)
                else
                    reject(data)
            ).error( (data, status, headers, config) ->
                reject(
                    _status: "ERR",
                    _msg: "Server returned code " + status
                )
            )

    qPost = (collection, doc) ->
        $q (resolve, reject) ->
            url = "/api/#{collection}"
            $http(
                method: 'POST',
                url: url
                data: doc
            ).success( (data, status, headers, config) ->
                if angular.isDefined(data._status) \
                  and data._status == 'OK'        \
                  and angular.isDefined(data._item)
                    resolve(data)
                else
                    reject(data)
            ).error( (data, status, headers, config) ->
                reject(
                    _status: "ERR",
                    _msg: "Server returned code " + status
                )
            )

    qPut = (collection, doc) ->
        $q (resolve, reject) ->
            url = "/api/#{collection}/#{doc._id}"
            $http(
                method: 'PUT',
                url: url
                data: doc
            ).success( (data, status, headers, config) ->
                if angular.isDefined(data._status) \
                  and data._status == 'OK'        \
                  and angular.isDefined(data._item)
                    resolve(data)
                else
                    reject(data)
            ).error( (data, status, headers, config) ->
                reject(
                    _status: "ERR",
                    _msg: "Server returned code " + status
                )
            )

    qDelete = (collection, doc) ->
        $q (resolve, reject) ->
            url = "/api/#{collection}/#{doc._id}"
            $http(
                method: 'DELETE',
                url: url
            ).success( (data, status, headers, config) ->
                if angular.isDefined(data._status) \
                  and data._status == 'OK'
                    resolve()
                else
                    reject(data)
            ).error( (data, status, headers, config) ->
                reject(
                    _status: "ERR",
                    _msg: "Server returned code " + status
                )
            )



    """
    Cache structure

    create: invalidates all listQueries of a collection
    delete: invalidates all listQueries of a collection
    update: invalidates individual (but locally recaches)


    Note for server-side paging and sorting, these params will
    have to show up in the listCache querySpecs...

    listCache:
        {collectionName:
            querySpec1:
                valid: true
                docs: [doc1, doc2..]
            querySpec2:
            ...
        }
    docCache:
        {collectionName:
            id1:
                valid: true
                fieldSpec1: {doc}
                fieldSpec2: {doc}
            id2:
            ...
        }

    """

    class DbCache
        constructor: ->
            @_listCache = {}
            @_docCache = {}

        _setupCache: (collection) ->
            @_listCache[collection]  = {} if !(collection of @_listCache)
            @_docCache[collection]  = {} if !(collection of @_docCache)

        _isCached: (collection, query, options, fields) ->
            @_setupCache(collection)
            if isDocQuery(query)
                hashF = hashFields(fields)
                return (
                    query._id of @_docCache[collection] &&
                    @_docCache[collection][query._id].valid &&
                    hashF of @_docCache[collection][query._id]
                )
            else
                hashQ = hashQuery(query, options)
                hashF = hashFields(fields)
                return (
                    hashQ of @_listCache[collection] &&
                    @_listCache[collection][hashQ].valid &&
                    @_listCache[collection][hashQ].docs.every (x) ->
                        x.valid && hashF of x
                )

        _getList: (collection, query, options, fields) ->
            @_setupCache(collection)
            if isDocQuery(query)
                hashF = hashFields(fields)
                return [@_getDoc(collection, query, fields)]
            else
                hashQ = hashQuery(query, options)
                hashF = hashFields(fields)
                return deepcopy(
                    (x[hashF] for x in @_listCache[collection][hashQ].docs))

        _getDoc: (collection, query, fields) ->
            hashF = hashFields(fields)
            return deepcopy(@_docCache[collection][query._id][hashF])

        _cacheList: (collection, query, options, fields, docs) ->
            @_setupCache(collection)
            if isDocQuery(query)
                @_cacheDoc(collection, docs[0], fields)
            else
                hashQ = hashQuery(query, options)
                hashF = hashFields(fields)
                if !(hashQ of @_listCache[collection])
                    @_listCache[collection][hashQ] = {}
                @_listCache[collection][hashQ].valid = true
                @_listCache[collection][hashQ].docs = []
                docs.forEach (doc) =>
                    @_listCache[collection][hashQ].docs.push(
                        @_cacheDoc(collection, doc, fields)
                    )

        _cacheDoc: (collection, doc, fields) ->
            hashF = hashFields(fields)
            if !(doc._id of @_docCache[collection])
                @_docCache[collection][doc._id] = {}
            @_docCache[collection][doc._id].valid = true
            @_docCache[collection][doc._id][hashF] = doc
            return @_docCache[collection][doc._id]

        
        invalidateSingle: (collection, doc) ->
            @_setupCache(collection)
            if (doc._id of @_docCache[collection])
                @_docCache[collection][doc._id].valid = false



        find: (collection, query={}, options={}, fields={}) ->
            if !@_isCached(collection, query, options, fields)
                tmpQ = qGet(collection, query, fields)
                .then (resp) =>
                    @_cacheList(collection, query, options, fields, resp._items)
                .catch (err) ->
                    throw err
            else
                tmpQ = $q((res)->res())
            return tmpQ.then =>
                @_getList(collection, query, options, fields)


        findOne: (collection, query={}, options={}, fields={}) ->
            if !@_isCached(collection, query, options, fields)
                tmpQ = qGet(collection, query, fields)
                .then (resp) =>
                    @_cacheList(collection, query, options, fields, resp._items)
                .catch (err) ->
                    throw err
            else
                tmpQ = $q((res)->res())
            return tmpQ.then =>
                @_getList(collection, query, options, fields)[0]


        insert: (collection, doc) ->
            @_setupCache(collection)
            qPost(collection, doc)
            .then (resp) =>
                @_cacheDoc(collection, resp._item)
                return resp._item
            .catch (err) ->
                throw err


        update: (collection, doc) ->
            @_setupCache(collection)
            qPut(collection, doc)
            .then (resp) =>
                @_cacheDoc(collection, resp._item)
                return resp._item
            .catch (err) ->
                throw err


        remove: (collection, doc) ->
            @_setupCache(collection)
            qDelete(collection, doc)
            .then (resp) =>
                @invalidateSingle(collection, doc)
                null
            .catch (err) ->
                throw err


    new DbCache