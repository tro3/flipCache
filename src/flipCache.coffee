angular.module 'flipCache', [
]

.factory 'flipCache', ($http, $q, $rootScope) ->

    p = console.log
    cache = null

    hashQuery = (query={}, options={}) ->
        opts = angular.copy options
        delete opts.fields
        JSON.stringify(
            query: query
            options: opts
        )

    hashFields = (fields={}) ->
        JSON.stringify(fields)

    isDocQuery = (query={}) ->
        return Object.keys(query).length == 1 \
            && Object.keys(query)[0] == '_id' \
            && typeof(query._id) == 'number'


    getRandInt = (max) ->
        Math.floor(Math.random()*max)


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


    qGet = (collection, query, options) ->
        $q (resolve, reject) ->
            url = cache.apiRoot + "/#{collection}"
            params = {}
            if Object.keys(query).length > 0
                params.q = JSON.stringify(query)
            if 'fields' of options and Object.keys(options.fields).length > 0
                params.fields = JSON.stringify(options.fields)
            if 'sort' of options and Object.keys(options.sort).length > 0
                params.sort = JSON.stringify(options.sort)
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
            url = cache.apiRoot + "/#{collection}"
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
            url = cache.apiRoot + "/#{collection}/#{doc._id}"
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
            url = cache.apiRoot + "/#{collection}/#{doc._id}"
            $http(
                method: 'DELETE',
                url: url
            ).success( (data, status, headers, config) ->
                if angular.isDefined(data._status) \
                  and data._status == 'OK'
                    resolve(data)
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
            @_actives = []
            @tids = []
            @qBusy = $q (resolve, reject) -> resolve()
            @apiRoot = "/api"

            primus = Primus.connect()
            primus.on 'data', (data) =>
                @qBusy.then =>
                    coll = data.collection
                    if 'tid' of data and data.tid in @tids
                        @tids.splice(@tids.indexOf(data.tid),1)
                    else
                        @invalidateLists(coll)
                        @invalidateDoc(coll, data.id) if data.action == 'edit'
                        $rootScope.$broadcast 'cacheEvent', data
                        $rootScope.$broadcast 'socketEvent', data



        _setupCache: (collection) ->
            @_listCache[collection]  = {} if !(collection of @_listCache)
            @_docCache[collection]  = {} if !(collection of @_docCache)

        _isCached: (collection, query, options) ->
            fields = options.fields || {}
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

        _getList: (collection, query, options) ->
            fields = options.fields || {}
            @_setupCache(collection)
            if isDocQuery(query)
                hashF = hashFields(fields)
                return [@_getDoc(collection, query, fields)]
            else
                hashQ = hashQuery(query, options)
                hashF = hashFields(fields)
                return deepcopy(
                    (x[hashF] for x in @_listCache[collection][hashQ].docs))

        _getDoc: (collection, query, options) ->
            fields = options.fields || {}
            hashF = hashFields(fields)
            return deepcopy(@_docCache[collection][query._id][hashF])

        _cacheList: (collection, query, options, docs) ->
            fields = options.fields || {}
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
                        @_cacheDoc(collection, doc, options)
                    )

        _cacheDoc: (collection, doc, options={}) ->
            fields = options.fields || {}
            hashF = hashFields(fields)
            if !(doc._id of @_docCache[collection])
                @_docCache[collection][doc._id] = {}
            @_docCache[collection][doc._id].valid = true
            @_docCache[collection][doc._id][hashF] = doc
            return @_docCache[collection][doc._id]


        invalidateDoc: (collection, id) ->
            @_setupCache(collection)
            if (id of @_docCache[collection])
                @_docCache[collection][id].valid = false


        invalidateLists: (collection) ->
            @_setupCache(collection)
            for key, val of @_listCache[collection]
                val.valid = false


        find: (collection, query={}, options={}, force=false) ->
            if force or !@_isCached(collection, query, options)
                tmpQ = qGet(collection, query, options)
                .then (resp) =>
                    @_cacheList(collection, query, options, resp._items)
                .catch (err) ->
                    throw err
            else
                tmpQ = $q((res)->res())
            return tmpQ.then =>
                @_getList(collection, query, options)


        findOne: (collection, query={}, options={}, force=false) ->
            if force or !@_isCached(collection, query, options)
                tmpQ = qGet(collection, query, options)
                .then (resp) =>
                    @_cacheList(collection, query, options, resp._items)
                .catch (err) ->
                    throw err
            else
                tmpQ = $q((res)->res())
            return tmpQ.then =>
                @_getList(collection, query, options)[0]


        insert: (collection, doc) ->
            @qBusy = $q (resolve, reject) =>
                @_setupCache(collection)
                qPost(collection, doc)
                .then (resp) =>
                    tid = resp._tid
                    @tids.push tid
                    @_cacheDoc(collection, resp._item)
                    @invalidateLists(collection)
                    $rootScope.$broadcast 'cacheEvent',
                        action: 'create'
                        collection: collection
                        id: resp._item._id
                        tid: tid
                    resolve resp._item
                .catch (err) ->
                    reject err


        update: (collection, doc) ->
            @qBusy = $q (resolve, reject) =>
                @_setupCache(collection)
                qPut(collection, doc)
                .then (resp) =>
                    tid = resp._tid
                    @tids.push tid
                    @_cacheDoc(collection, resp._item)
                    @invalidateLists(collection)
                    $rootScope.$broadcast 'cacheEvent',
                        action: 'edit'
                        collection: collection
                        id: resp._item._id
                        tid: tid
                    resolve resp._item
                .catch (err) ->
                    reject err


        remove: (collection, doc) ->
            @qBusy = $q (resolve, reject) =>
                @_setupCache(collection)
                qDelete(collection, doc)
                .then (resp) =>
                    tid = resp._tid
                    @tids.push tid
                    @invalidateDoc(collection, doc._id)
                    @invalidateLists(collection)
                    $rootScope.$broadcast 'cacheEvent',
                        action: 'delete'
                        collection: collection
                        id: doc._id
                        tid: tid
                    resolve null
                .catch (err) ->
                    reject err


        setActive: (val) ->
            @clearActives()
            @addActive(val)
        
        addActive: (val) ->
            for a in @_actives
                return if a == val
            @_actives.push val

        clearActives: () ->
            @_actives.splice(0)


    cache = new DbCache
    cache