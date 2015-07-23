angular.module 'flipList', [
    'flipCache'
    'flipDoc'
]

.factory 'flipList', ($q, flipCache, flipDoc) ->

    tmp = (config) ->
        flipList = []
        flipList.params = {}
        flipList.params.collection = config.collection
        flipList.params.filter = config.filter || {}
        flipList.params.options = config.options || {}
        flipList.params.options.fields = config.fields || {}
        flipList.params.options.sort = config.sort || {}

        flipList.$get = (force=false) ->
            $q (resolve, reject) ->
                flipCache.find(
                    flipList.params.collection,
                    flipList.params.filter,
                    flipList.params.options,
                    force
                )
                .then (docs) ->
                    flipList.splice(0, flipList.length)
                    docs.forEach (x) ->
                        flipList.push flipDoc flipList.params.collection, x
                    resolve(flipList)
                .catch (err) -> reject(err)

        flipList.setActive = ->
            flipCache.setActive(flipList)

        flipList.addActive = ->
            flipCache.addActive(flipList)
        
        return flipList
    
    tmp