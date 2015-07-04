angular.module 'flipList', [
    'flipCache'
    'flipDoc'
]

.factory 'flipList', ($q, flipCache, flipDoc) ->

    tmp = (config) ->
        flipList = []
        flipList.collection = config.collection
        flipList.filter = config.filter || {}
        flipList.options = config.options || {}
        flipList.fields = config.fields || {}

        flipList.$get = (force=false) ->
            $q (resolve, reject) ->
                opts = angular.copy(flipList.options)
                opts.force = force
                flipCache.find(flipList.collection, flipList.filter,
                               opts, flipList.fields)
                .then (docs) ->
                    flipList.splice(0, flipList.length)
                    flipList.push(flipDoc(flipList.collection, x)) for x in docs
                    resolve(flipList)
                .catch (err) -> reject(err)

        flipList.setActive = ->
            flipCache.setActive(flipList)

        flipList.addActive = ->
            flipCache.addActive(flipList)
        
        return flipList
    
    tmp.clearActives = -> flipCache.clearActives()
    return tmp