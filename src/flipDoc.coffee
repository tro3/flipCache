angular.module 'flipDoc', [
    'flipCache'
]

.factory 'flipDoc', ($q, flipCache) ->

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


    class FlipDoc
        constructor: (first, second) ->
            # Usage: FlipDoc(collection, id)
            #        FlipDoc(collection, {data})
            #        FlipDoc(FlipDoc)

            @_id = null
            if typeof(first) == 'object'
                @_extend(deepcopy(first))
            else # typeof(first) == 'string'
                @_collection = first
                if typeof(second) == 'object'
                    @_extend(second)
                else
                    @_id = second

        _extend: (data) ->
            for key, val of data
                this[key] = val if not angular.isFunction(val)

        _clear: () ->
            for key, val of this
                this[key] = null if not angular.isFunction(val)

        $get:  (force=false) ->
            $q (resolve, reject) =>
                flipCache.findOne(@_collection, {_id:@_id}, {}, force)
                .then (doc) => @_extend(doc); resolve(@)
                .catch (err) -> reject(err)

        $save:  () ->
            $q (resolve, reject) =>
                if @_id
                    flipCache.update(@_collection, @)
                    .then (doc) => @_extend(doc); resolve(@)
                    .catch (err) -> reject(err)
                else
                    flipCache.insert(@_collection, @)
                    .then (doc) => @_extend(doc); resolve(@)
                    .catch (err) -> reject(err)

        $delete:  () ->
            $q (resolve, reject) =>
                flipCache.remove(@_collection, @)
                .then (doc) => @_clear(); resolve()
                .catch (err) -> reject(err)

        setActive: ->
            flipCache.setActive(@)

        addActive: ->
            flipCache.addActive(@)
            

    tmp = (collection, id) -> new FlipDoc(collection, id)
    tmp.clearActives = -> flipCache.clearActives()
    return tmp