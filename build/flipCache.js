(function() {
  var indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  angular.module('flipCache', []).factory('flipCache', ["$http", "$q", "$rootScope", function($http, $q, $rootScope) {
    var DbCache, cache, deepcopy, getRandInt, hashFields, hashQuery, isDocQuery, p, qDelete, qGet, qPost, qPut;
    p = console.log;
    cache = null;
    hashQuery = function(query, options) {
      var opts;
      if (query == null) {
        query = {};
      }
      if (options == null) {
        options = {};
      }
      opts = angular.copy(options);
      delete opts.fields;
      return JSON.stringify({
        query: query,
        options: opts
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
      return Object.keys(query).length === 1 && Object.keys(query)[0] === '_id' && typeof query._id === 'number';
    };
    getRandInt = function(max) {
      return Math.floor(Math.random() * max);
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
    qGet = function(collection, query, options) {
      return $q(function(resolve, reject) {
        var params, url;
        url = cache.apiRoot + ("/" + collection);
        params = {};
        if (Object.keys(query).length > 0) {
          params.q = JSON.stringify(query);
        }
        if ('fields' in options && Object.keys(options.fields).length > 0) {
          params.fields = JSON.stringify(options.fields);
        }
        if ('sort' in options && Object.keys(options.sort).length > 0) {
          params.sort = JSON.stringify(options.sort);
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
        url = cache.apiRoot + ("/" + collection);
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
        url = cache.apiRoot + ("/" + collection + "/" + doc._id);
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
        url = cache.apiRoot + ("/" + collection + "/" + doc._id);
        return $http({
          method: 'DELETE',
          url: url
        }).success(function(data, status, headers, config) {
          if (angular.isDefined(data._status) && data._status === 'OK') {
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
    "Cache structure\n\ncreate: invalidates all listQueries of a collection\ndelete: invalidates all listQueries of a collection\nupdate: invalidates individual (but locally recaches)\n\n\nNote for server-side paging and sorting, these params will\nhave to show up in the listCache querySpecs...\n\nlistCache:\n    {collectionName:\n        querySpec1:\n            valid: true\n            docs: [doc1, doc2..]\n        querySpec2:\n        ...\n    }\ndocCache:\n    {collectionName:\n        id1:\n            valid: true\n            fieldSpec1: {doc}\n            fieldSpec2: {doc}\n        id2:\n        ...\n    }\n";
    DbCache = (function() {
      function DbCache() {
        var primus;
        this._listCache = {};
        this._docCache = {};
        this._actives = [];
        this.tids = [];
        this.qBusy = $q(function(resolve, reject) {
          return resolve();
        });
        this.apiRoot = "/api";
        primus = Primus.connect();
        primus.on('data', (function(_this) {
          return function(data) {
            return _this.qBusy.then(function() {
              var coll, ref;
              coll = data.collection;
              if ('tid' in data && (ref = data.tid, indexOf.call(_this.tids, ref) >= 0)) {
                return _this.tids.splice(_this.tids.indexOf(data.tid), 1);
              } else {
                _this.invalidateLists(coll);
                if (data.action === 'edit') {
                  _this.invalidateDoc(coll, data.id);
                }
                $rootScope.$broadcast('cacheEvent', data);
                return $rootScope.$broadcast('socketEvent', data);
              }
            });
          };
        })(this));
      }

      DbCache.prototype._setupCache = function(collection) {
        if (!(collection in this._listCache)) {
          this._listCache[collection] = {};
        }
        if (!(collection in this._docCache)) {
          return this._docCache[collection] = {};
        }
      };

      DbCache.prototype._isCached = function(collection, query, options) {
        var fields, hashF, hashQ;
        fields = options.fields || {};
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

      DbCache.prototype._getList = function(collection, query, options) {
        var fields, hashF, hashQ, x;
        fields = options.fields || {};
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

      DbCache.prototype._getDoc = function(collection, query, options) {
        var fields, hashF;
        fields = options.fields || {};
        hashF = hashFields(fields);
        return deepcopy(this._docCache[collection][query._id][hashF]);
      };

      DbCache.prototype._cacheList = function(collection, query, options, docs) {
        var fields, hashF, hashQ;
        fields = options.fields || {};
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
              return _this._listCache[collection][hashQ].docs.push(_this._cacheDoc(collection, doc, options));
            };
          })(this));
        }
      };

      DbCache.prototype._cacheDoc = function(collection, doc, options) {
        var fields, hashF;
        if (options == null) {
          options = {};
        }
        fields = options.fields || {};
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

      DbCache.prototype.find = function(collection, query, options, force) {
        var tmpQ;
        if (query == null) {
          query = {};
        }
        if (options == null) {
          options = {};
        }
        if (force == null) {
          force = false;
        }
        if (force || !this._isCached(collection, query, options)) {
          tmpQ = qGet(collection, query, options).then((function(_this) {
            return function(resp) {
              return _this._cacheList(collection, query, options, resp._items);
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
            return _this._getList(collection, query, options);
          };
        })(this));
      };

      DbCache.prototype.findOne = function(collection, query, options, force) {
        var tmpQ;
        if (query == null) {
          query = {};
        }
        if (options == null) {
          options = {};
        }
        if (force == null) {
          force = false;
        }
        if (force || !this._isCached(collection, query, options)) {
          tmpQ = qGet(collection, query, options).then((function(_this) {
            return function(resp) {
              return _this._cacheList(collection, query, options, resp._items);
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
            return _this._getList(collection, query, options)[0];
          };
        })(this));
      };

      DbCache.prototype.insert = function(collection, doc) {
        return this.qBusy = $q((function(_this) {
          return function(resolve, reject) {
            _this._setupCache(collection);
            return qPost(collection, doc).then(function(resp) {
              var tid;
              tid = resp._tid;
              _this.tids.push(tid);
              _this._cacheDoc(collection, resp._item);
              _this.invalidateLists(collection);
              $rootScope.$broadcast('cacheEvent', {
                action: 'create',
                collection: collection,
                id: resp._item._id,
                tid: tid
              });
              return resolve(resp._item);
            })["catch"](function(err) {
              return reject(err);
            });
          };
        })(this));
      };

      DbCache.prototype.update = function(collection, doc) {
        return this.qBusy = $q((function(_this) {
          return function(resolve, reject) {
            _this._setupCache(collection);
            return qPut(collection, doc).then(function(resp) {
              var tid;
              tid = resp._tid;
              _this.tids.push(tid);
              _this._cacheDoc(collection, resp._item);
              _this.invalidateLists(collection);
              $rootScope.$broadcast('cacheEvent', {
                action: 'edit',
                collection: collection,
                id: resp._item._id,
                tid: tid
              });
              return resolve(resp._item);
            })["catch"](function(err) {
              return reject(err);
            });
          };
        })(this));
      };

      DbCache.prototype.remove = function(collection, doc) {
        return this.qBusy = $q((function(_this) {
          return function(resolve, reject) {
            _this._setupCache(collection);
            return qDelete(collection, doc).then(function(resp) {
              var tid;
              tid = resp._tid;
              _this.tids.push(tid);
              _this.invalidateDoc(collection, doc._id);
              _this.invalidateLists(collection);
              $rootScope.$broadcast('cacheEvent', {
                action: 'delete',
                collection: collection,
                id: doc._id,
                tid: tid
              });
              return resolve(null);
            })["catch"](function(err) {
              return reject(err);
            });
          };
        })(this));
      };

      DbCache.prototype.setActive = function(val) {
        this.clearActives();
        return this.addActive(val);
      };

      DbCache.prototype.addActive = function(val) {
        var a, i, len, ref;
        ref = this._actives;
        for (i = 0, len = ref.length; i < len; i++) {
          a = ref[i];
          if (a === val) {
            return;
          }
        }
        return this._actives.push(val);
      };

      DbCache.prototype.clearActives = function() {
        return this._actives.splice(0);
      };

      return DbCache;

    })();
    cache = new DbCache;
    return cache;
  }]);

}).call(this);

(function() {
  angular.module('flipDoc', ['flipCache']).factory('flipDoc', ["$q", "flipCache", function($q, flipCache) {
    var FlipDoc, deepcopy, tmp;
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
    FlipDoc = (function() {
      function FlipDoc(first, second) {
        this._id = null;
        if (typeof first === 'object') {
          this._extend(deepcopy(first));
        } else {
          this._collection = first;
          if (typeof second === 'object') {
            this._extend(second);
          } else {
            this._id = second;
          }
        }
      }

      FlipDoc.prototype._extend = function(data) {
        var key, results, val;
        results = [];
        for (key in data) {
          val = data[key];
          if (!angular.isFunction(val)) {
            results.push(this[key] = val);
          } else {
            results.push(void 0);
          }
        }
        return results;
      };

      FlipDoc.prototype._clear = function() {
        var key, results, val;
        results = [];
        for (key in this) {
          val = this[key];
          if (!angular.isFunction(val)) {
            results.push(this[key] = null);
          } else {
            results.push(void 0);
          }
        }
        return results;
      };

      FlipDoc.prototype.$get = function(force) {
        if (force == null) {
          force = false;
        }
        return $q((function(_this) {
          return function(resolve, reject) {
            return flipCache.findOne(_this._collection, {
              _id: _this._id
            }, {}, force).then(function(doc) {
              _this._extend(doc);
              return resolve(_this);
            })["catch"](function(err) {
              return reject(err);
            });
          };
        })(this));
      };

      FlipDoc.prototype.$save = function() {
        return $q((function(_this) {
          return function(resolve, reject) {
            if (_this._id) {
              return flipCache.update(_this._collection, _this).then(function(doc) {
                _this._extend(doc);
                return resolve(_this);
              })["catch"](function(err) {
                return reject(err);
              });
            } else {
              return flipCache.insert(_this._collection, _this).then(function(doc) {
                _this._extend(doc);
                return resolve(_this);
              })["catch"](function(err) {
                return reject(err);
              });
            }
          };
        })(this));
      };

      FlipDoc.prototype.$delete = function() {
        return $q((function(_this) {
          return function(resolve, reject) {
            return flipCache.remove(_this._collection, _this).then(function(doc) {
              _this._clear();
              return resolve();
            })["catch"](function(err) {
              return reject(err);
            });
          };
        })(this));
      };

      FlipDoc.prototype.setActive = function() {
        return flipCache.setActive(this);
      };

      FlipDoc.prototype.addActive = function() {
        return flipCache.addActive(this);
      };

      return FlipDoc;

    })();
    tmp = function(collection, id) {
      return new FlipDoc(collection, id);
    };
    tmp.clearActives = function() {
      return flipCache.clearActives();
    };
    return tmp;
  }]);

}).call(this);

(function() {
  angular.module('flipList', ['flipCache', 'flipDoc']).factory('flipList', ["$q", "flipCache", "flipDoc", function($q, flipCache, flipDoc) {
    var tmp;
    tmp = function(config) {
      var flipList;
      flipList = [];
      flipList.params = {};
      flipList.params.collection = config.collection;
      flipList.params.filter = config.filter || {};
      flipList.params.options = config.options || {};
      flipList.params.options.fields = config.fields || {};
      flipList.params.options.sort = config.sort || {};
      flipList.$get = function(force) {
        if (force == null) {
          force = false;
        }
        return $q(function(resolve, reject) {
          return flipCache.find(flipList.params.collection, flipList.params.filter, flipList.params.options, force).then(function(docs) {
            flipList.splice(0, flipList.length);
            docs.forEach(function(x) {
              return flipList.push(flipDoc(flipList.params.collection, x));
            });
            return resolve(flipList);
          })["catch"](function(err) {
            return reject(err);
          });
        });
      };
      flipList.setActive = function() {
        return flipCache.setActive(flipList);
      };
      flipList.addActive = function() {
        return flipCache.addActive(flipList);
      };
      return flipList;
    };
    return tmp;
  }]);

}).call(this);
