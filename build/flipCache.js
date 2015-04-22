(function() {
  angular.module('flipCache', []).factory('flipCache', ["$http", "$q", function($http, $q) {
    var DbCache, deepcopy, hashFields, hashQuery, isDocQuery, p, qDelete, qGet, qPost, qPut;
    p = console.log;
    hashQuery = function(query, options) {
      if (query == null) {
        query = {};
      }
      if (options == null) {
        options = {};
      }
      return JSON.stringify({
        query: query,
        options: options
      });
    };
    hashFields = function(fields) {
      if (fields == null) {
        fields = {};
      }
      return JSON.stringify(fields);
    };
    isDocQuery = function(query) {
      if (query == null) {
        query = {};
      }
      return Object.keys(query).length === 1 && Object.keys(query)[0] === '_id';
    };
    deepcopy = function(obj) {
      var key, result, val, x;
      if (typeof obj !== 'object') {
        return obj;
      }
      if (obj === null) {
        return obj;
      }
      if (obj instanceof Array) {
        return (function() {
          var i, len, results;
          results = [];
          for (i = 0, len = obj.length; i < len; i++) {
            x = obj[i];
            results.push(deepcopy(x));
          }
          return results;
        })();
      }
      result = {};
      for (key in obj) {
        val = obj[key];
        if (val instanceof Date) {
          result[key] = deepcopy(val);
          result[key].__proto__ = val.proto;
        } else {
          result[key] = deepcopy(val);
        }
      }
      return result;
    };
    qGet = function(collection, query, fields) {
      return $q(function(resolve, reject) {
        var params, url;
        url = "/api/" + collection;
        params = {};
        if (Object.keys(query).length > 0) {
          params.q = JSON.stringify(query);
        }
        if (Object.keys(fields).length > 0) {
          params.fields = JSON.stringify(fields);
        }
        return $http({
          method: 'GET',
          url: url,
          params: params
        }).success(function(data, status, headers, config) {
          if (angular.isDefined(data._status) && data._status === 'OK' && angular.isDefined(data._items)) {
            return resolve(data);
          } else {
            return reject(data);
          }
        }).error(function(data, status, headers, config) {
          return reject({
            _status: "ERR",
            _msg: "Server returned code " + status
          });
        });
      });
    };
    qPost = function(collection, doc) {
      return $q(function(resolve, reject) {
        var url;
        url = "/api/" + collection;
        return $http({
          method: 'POST',
          url: url,
          data: doc
        }).success(function(data, status, headers, config) {
          if (angular.isDefined(data._status) && data._status === 'OK' && angular.isDefined(data._item)) {
            return resolve(data);
          } else {
            return reject(data);
          }
        }).error(function(data, status, headers, config) {
          return reject({
            _status: "ERR",
            _msg: "Server returned code " + status
          });
        });
      });
    };
    qPut = function(collection, doc) {
      return $q(function(resolve, reject) {
        var url;
        url = "/api/" + collection + "/" + doc._id;
        return $http({
          method: 'PUT',
          url: url,
          data: doc
        }).success(function(data, status, headers, config) {
          if (angular.isDefined(data._status) && data._status === 'OK' && angular.isDefined(data._item)) {
            return resolve(data);
          } else {
            return reject(data);
          }
        }).error(function(data, status, headers, config) {
          return reject({
            _status: "ERR",
            _msg: "Server returned code " + status
          });
        });
      });
    };
    qDelete = function(collection, doc) {
      return $q(function(resolve, reject) {
        var url;
        url = "/api/" + collection + "/" + doc._id;
        return $http({
          method: 'DELETE',
          url: url
        }).success(function(data, status, headers, config) {
          if (angular.isDefined(data._status) && data._status === 'OK') {
            return resolve();
          } else {
            return reject(data);
          }
        }).error(function(data, status, headers, config) {
          return reject({
            _status: "ERR",
            _msg: "Server returned code " + status
          });
        });
      });
    };
    "Cache structure\n\ncreate: invalidates all listQueries of a collection\ndelete: invalidates all listQueries of a collection\nupdate: invalidates individual (but locally recaches)\n\n\nNote for server-side paging and sorting, these params will\nhave to show up in the listCache querySpecs...\n\nlistCache:\n    {collectionName:\n        querySpec1:\n            valid: true\n            docs: [doc1, doc2..]\n        querySpec2:\n        ...\n    }\ndocCache:\n    {collectionName:\n        id1:\n            valid: true\n            fieldSpec1: {doc}\n            fieldSpec2: {doc}\n        id2:\n        ...\n    }\n";
    DbCache = (function() {
      function DbCache() {
        this._listCache = {};
        this._docCache = {};
      }

      DbCache.prototype._setupCache = function(collection) {
        if (!(collection in this._listCache)) {
          this._listCache[collection] = {};
        }
        if (!(collection in this._docCache)) {
          return this._docCache[collection] = {};
        }
      };

      DbCache.prototype._isCached = function(collection, query, options, fields) {
        var hashF, hashQ;
        this._setupCache(collection);
        if (isDocQuery(query)) {
          hashF = hashFields(fields);
          return query._id in this._docCache[collection] && this._docCache[collection][query._id].valid && hashF in this._docCache[collection][query._id];
        } else {
          hashQ = hashQuery(query, options);
          hashF = hashFields(fields);
          return hashQ in this._listCache[collection] && this._listCache[collection][hashQ].valid && this._listCache[collection][hashQ].docs.every(function(x) {
            return x.valid && hashF in x;
          });
        }
      };

      DbCache.prototype._getList = function(collection, query, options, fields) {
        var hashF, hashQ, x;
        this._setupCache(collection);
        if (isDocQuery(query)) {
          hashF = hashFields(fields);
          return [this._getDoc(collection, query, fields)];
        } else {
          hashQ = hashQuery(query, options);
          hashF = hashFields(fields);
          return deepcopy((function() {
            var i, len, ref, results;
            ref = this._listCache[collection][hashQ].docs;
            results = [];
            for (i = 0, len = ref.length; i < len; i++) {
              x = ref[i];
              results.push(x[hashF]);
            }
            return results;
          }).call(this));
        }
      };

      DbCache.prototype._getDoc = function(collection, query, fields) {
        var hashF;
        hashF = hashFields(fields);
        return deepcopy(this._docCache[collection][query._id][hashF]);
      };

      DbCache.prototype._cacheList = function(collection, query, options, fields, docs) {
        var hashF, hashQ;
        this._setupCache(collection);
        if (isDocQuery(query)) {
          return this._cacheDoc(collection, docs[0], fields);
        } else {
          hashQ = hashQuery(query, options);
          hashF = hashFields(fields);
          if (!(hashQ in this._listCache[collection])) {
            this._listCache[collection][hashQ] = {};
          }
          this._listCache[collection][hashQ].valid = true;
          this._listCache[collection][hashQ].docs = [];
          return docs.forEach((function(_this) {
            return function(doc) {
              return _this._listCache[collection][hashQ].docs.push(_this._cacheDoc(collection, doc, fields));
            };
          })(this));
        }
      };

      DbCache.prototype._cacheDoc = function(collection, doc, fields) {
        var hashF;
        hashF = hashFields(fields);
        if (!(doc._id in this._docCache[collection])) {
          this._docCache[collection][doc._id] = {};
        }
        this._docCache[collection][doc._id].valid = true;
        this._docCache[collection][doc._id][hashF] = doc;
        return this._docCache[collection][doc._id];
      };

      DbCache.prototype.invalidateDoc = function(collection, id) {
        this._setupCache(collection);
        if (id in this._docCache[collection]) {
          return this._docCache[collection][id].valid = false;
        }
      };

      DbCache.prototype.invalidateLists = function(collection) {
        var key, ref, results, val;
        this._setupCache(collection);
        ref = this._listCache[collection];
        results = [];
        for (key in ref) {
          val = ref[key];
          results.push(val.valid = false);
        }
        return results;
      };

      DbCache.prototype.find = function(collection, query, options, fields) {
        var tmpQ;
        if (query == null) {
          query = {};
        }
        if (options == null) {
          options = {};
        }
        if (fields == null) {
          fields = {};
        }
        if (!this._isCached(collection, query, options, fields)) {
          tmpQ = qGet(collection, query, fields).then((function(_this) {
            return function(resp) {
              return _this._cacheList(collection, query, options, fields, resp._items);
            };
          })(this))["catch"](function(err) {
            throw err;
          });
        } else {
          tmpQ = $q(function(res) {
            return res();
          });
        }
        return tmpQ.then((function(_this) {
          return function() {
            return _this._getList(collection, query, options, fields);
          };
        })(this));
      };

      DbCache.prototype.findOne = function(collection, query, options, fields) {
        var tmpQ;
        if (query == null) {
          query = {};
        }
        if (options == null) {
          options = {};
        }
        if (fields == null) {
          fields = {};
        }
        if (!this._isCached(collection, query, options, fields)) {
          tmpQ = qGet(collection, query, fields).then((function(_this) {
            return function(resp) {
              return _this._cacheList(collection, query, options, fields, resp._items);
            };
          })(this))["catch"](function(err) {
            throw err;
          });
        } else {
          tmpQ = $q(function(res) {
            return res();
          });
        }
        return tmpQ.then((function(_this) {
          return function() {
            return _this._getList(collection, query, options, fields)[0];
          };
        })(this));
      };

      DbCache.prototype.insert = function(collection, doc) {
        this._setupCache(collection);
        return qPost(collection, doc).then((function(_this) {
          return function(resp) {
            _this._cacheDoc(collection, resp._item);
            return resp._item;
          };
        })(this))["catch"](function(err) {
          throw err;
        });
      };

      DbCache.prototype.update = function(collection, doc) {
        this._setupCache(collection);
        return qPut(collection, doc).then((function(_this) {
          return function(resp) {
            _this._cacheDoc(collection, resp._item);
            return resp._item;
          };
        })(this))["catch"](function(err) {
          throw err;
        });
      };

      DbCache.prototype.remove = function(collection, doc) {
        this._setupCache(collection);
        return qDelete(collection, doc).then((function(_this) {
          return function(resp) {
            _this.invalidateDoc(collection, doc._id);
            return null;
          };
        })(this))["catch"](function(err) {
          throw err;
        });
      };

      return DbCache;

    })();
    return new DbCache;
  }]);

}).call(this);
