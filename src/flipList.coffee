angular.module 'flipList', [
    'flipCache'
    'flipDoc'
]

.factory 'flipList', ($q, flipCache, flipDoc) ->

    (config) ->
        flipList = []
        flipList.collection = config.collection
        flipList.filter = config.filter || {}
        flipList.options = config.options || {}
        flipList.fields = config.fields || {}

        flipList.$get = () ->
            $q (resolve, reject) ->
                flipCache.find(flipList.collection, flipList.filter,
                               flipList.options, flipList.fields)
                .then (docs) ->
                    flipList.splice(0, flipList.length)
                    flipList.push(flipDoc(flipList.collection, x)) for x in docs
                    resolve(this)
                .catch (err) -> reject(err)

        flipList.$setActive = ->
            flipCache.setActive(flipList)

        flipList.$addActive = ->
            flipCache.addActive(flipList)
        
        return flipList