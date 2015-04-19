angular.module 'flipCache', [
]

.factory 'flipCache', ($http) ->
  class Cache
    constructor: ->
      @cache = {}
      
    find: (collection, query, fields) ->
      null
 
  new Cache