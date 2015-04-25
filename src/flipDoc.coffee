angular.module 'flipDoc', [
    'flipCache'
]

.factory 'flipDoc', ($q, flipCache) ->

    class FlipDoc
        constructor: (first, second) ->
            # Usage: FlipDoc(collection, id)
            #        FlipDoc(collection, {data})
            #        FlipDoc(FlipDoc)

            @_id = null
            if typeof(first) == 'object'
                @_extend(first)
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

        $get:  () ->
            $q (resolve, reject) =>
                flipCache.findOne(@_collection, {_id:@_id})
                .then (doc) => @_extend(doc); resolve(this)
                .catch (err) -> reject(err)

        $save:  () ->
            $q (resolve, reject) =>
                if @_id
                    flipCache.update(@_collection, @)
                    .then (doc) => @_extend(doc); resolve(this)
                    .catch (err) -> reject(err)
                else
                    flipCache.insert(@_collection, @)
                    .then (doc) => @_extend(doc); resolve(this)
                    .catch (err) -> reject(err)

        $delete:  () ->
            $q (resolve, reject) =>
                flipCache.remove(@_collection, @)
                .then (doc) => @_clear(); resolve(this)
                .catch (err) -> reject(err)

    (collection, id) -> new FlipDoc(collection, id)