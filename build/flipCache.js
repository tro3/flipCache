(function() {
  angular.module('flipCache', []).factory('flipCache', ["$http", function($http) {
    var Cache;
    Cache = (function() {
      function Cache() {
        this.cache = {};
      }

      Cache.prototype.find = function(collection, query, fields) {
        return null;
      };

      return Cache;

    })();
    return new Cache;
  }]);

}).call(this);
