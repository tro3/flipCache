p = console.log

describe "flipCache", ->
    cache = null
    http = null
    sEvents = null
    cEvents = null

    beforeEach ->
        module('flipCache')
        inject ($httpBackend, flipCache) ->
            http = $httpBackend
            cache = flipCache

        sEvents = []
        cEvents = []
        inject ($rootScope) ->
            $rootScope.$on 'socketEvent', (event, data) ->
                sEvents.push data
            $rootScope.$on 'cacheEvent', (event, data) ->
                cEvents.push data



    afterEach ->
        http.verifyNoOutstandingExpectation()
        http.verifyNoOutstandingRequest()

            
    describe "find", ->
        it "returns simple list query, caching result", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [{_id:'12345', _auth:{_edit:true, _delete:true}, name:'Bob'}]
            cache.find('test').then (data1) ->
                assert.deepEqual data1, data._items
                cache.find('test').then (data2) ->
                    assert.deepEqual data2, data._items
                    done()
            http.expectGET('/api/test').respond(200, data)
            http.flush()

        it "returns simple list query, caching individual results as id's", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [
                    {_id:12345, _auth:{_edit:true, _delete:true}, name:'Bob'}
                    {_id:12346, _auth:{_edit:true, _delete:true}, name:'Fred'}
                ]
            cache.find('test').then (data1) ->
                assert.deepEqual data1, data._items
                cache.find('test', {_id:12346}).then (data2) ->
                    assert.deepEqual data2, [data._items[1]]
                    done()
            http.expectGET('/api/test').respond(200, data)
            http.flush()

        it "handles keyword _id queries", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [
                    {_id:12345, _auth:{_edit:true, _delete:true}, name:'Bob'}
                    {_id:12346, _auth:{_edit:true, _delete:true}, name:'Fred'}
                ]
            cache.find('test', {_id:{$in:[12345,12346]}}).then (data1) ->
                assert.deepEqual data1, data._items
                cache.find('test', {_id:12346}).then (data2) ->
                    assert.deepEqual data2, [data._items[1]]
                    done()
            http.expectGET(encodeURI '/api/test?q={"_id":{"$in":[12345,12346]}}').respond(200, data)
            http.flush()


    describe "findOne", ->
        it "returns simple item query, caching result", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [{_id:'12345', _auth:{_edit:true, _delete:true}, name:'Bob'}]
            cache.findOne('test', {name:'Bob'}).then (data1) ->
                assert.deepEqual data1, data._items[0]
                cache.findOne('test', {name:'Bob'}).then (data2) ->
                    assert.deepEqual data2, data._items[0]
                    done()
            http.expectGET(encodeURI '/api/test?q={"name":"Bob"}').respond(200, data)
            http.flush()

        it "returns simple item query, caching individual result as id", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [
                    {_id:12346, _auth:{_edit:true, _delete:true}, name:'Fred'}
                ]
            cache.findOne('test', {name:'Bob'}).then (data1) ->
                assert.deepEqual data1, data._items[0]
                cache.findOne('test', {_id:12346}).then (data2) ->
                    assert.deepEqual data2, data._items[0]
                    done()
            http.expectGET(encodeURI '/api/test?q={"name":"Bob"}').respond(200, data)
            http.flush()


    describe "insert", ->
        it "sends proper API call, caching result", (done) ->
            data = {name:'Bob'}
            respData =
                _status: 'OK'
                _tid: 2
                _item: {_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}
            a = cache.insert('test', data)
            b = Primus.fire 'data', {action:'create', collection:'test', id:12346, tid:2}            
            b.then -> a.then (resp) ->
                assert.equal sEvents.length, 0
                assert.equal cEvents.length, 1
                assert.deepEqual cEvents[0],
                    action:'create'
                    collection:'test'
                    id:12346
                    tid:2
                cache.findOne('test', {_id:12346}).then (data2) ->
                    assert.deepEqual data2, respData._item
                    done()
            http.expectPOST("/api/test", data).respond(200, respData)
            http.flush()


    describe "update", ->
        it "sends proper API call, caching result", (done) ->
            data = {_id:12346, name:'Bob'}
            respData =
                _status: 'OK'
                _tid: 23
                _item: {_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}
            a = cache.update('test', data)
            b = Primus.fire 'data', {action:'edit', collection:'test', id:12346, tid:23}          
            b.then -> a.then (resp) ->
                assert.deepEqual resp, respData._item
                assert.equal sEvents.length, 0
                assert.equal cEvents.length, 1
                assert.deepEqual cEvents[0],
                    action:'edit'
                    collection:'test'
                    id:12346
                    tid:23
                cache.findOne('test', {_id:12346}).then (data2) ->
                    assert.deepEqual data2, respData._item
                    done()
            http.expectPUT("/api/test/12346", data).respond(200, respData)
            http.flush()



    describe "delete", ->
        it "sends proper API call and invalidates cache of item", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [{_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            cache.findOne('test', {name:'Bob'}).then (resp) ->
                a = cache.remove('test', {_id:12346})
                b = Primus.fire 'data', {action:'delete', collection:'test', id:12346, tid:234}          
                b.then -> a.then (resp) ->
                    p resp
                    assert.isNull resp
                    assert.equal sEvents.length, 0
                    assert.equal cEvents.length, 1
                    assert.deepEqual cEvents[0],
                        action:'delete'
                        collection:'test'
                        id:12346
                        tid:234
                    cache.findOne('test', {_id:12346}).then (resp) ->
                        done()
            http.expectGET(encodeURI '/api/test?q={"name":"Bob"}').respond(200, data)
            http.expectDELETE("/api/test/12346").respond(200, {_status:"OK", _tid:234})
            http.expectGET(encodeURI '/api/test?q={"_id":12346}').respond(200, data)
            http.flush()

        it "sends proper API call and invalidates cache of original spec", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [{_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            cache.findOne('test', {name:'Bob'}).then (resp) ->
                cache.remove('test', {_id:12346}).then (resp) ->
                    assert.isNull resp
                    cache.findOne('test', {name:'Bob'}).then (resp) ->
                        done()
            http.expectGET(encodeURI '/api/test?q={"name":"Bob"}').respond(200, data)
            http.expectDELETE("/api/test/12346").respond(200, {_status:"OK"})
            http.expectGET(encodeURI '/api/test?q={"name":"Bob"}').respond(200, data)
            http.flush()


    describe "invalidateDoc", ->
        it "invalidates docCache of given document", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [{_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            cache.findOne('test', {_id:12346})
            .then (doc) ->
                assert.equal doc._id, 12346
                cache.findOne('test', {_id:12346})
            .then (doc) ->
                assert.equal doc._id, 12346
                cache.invalidateDoc('test', 12346)
                cache.findOne('test', {_id:12346})
            .then (doc) ->
                assert.equal doc._id, 12346
                done()
            http.expectGET(encodeURI '/api/test?q={"_id":12346}').respond(200, data)
            http.expectGET(encodeURI '/api/test?q={"_id":12346}').respond(200, data)
            http.flush()
        
        it "invalidates listCache containing given document", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [
                    {_id:12345, _auth:{_edit:true, _delete:true}, name:'Bob'}
                    {_id:12346, _auth:{_edit:true, _delete:true}, name:'Fred'}
                ]
            cache.find('test')
            .then (docs) ->
                assert.equal docs[1]._id, 12346
                cache.findOne('test', {_id:12346})
            .then (doc) ->
                assert.equal doc._id, 12346
                cache.invalidateDoc('test', 12346)
                cache.find('test')
            .then (docs) ->
                assert.equal docs[1]._id, 12346
                done()
            http.expectGET("/api/test").respond(200, data)
            http.expectGET("/api/test").respond(200, data)
            http.flush()

        it "doesn't invalidate listCache not containing given document", (done) ->
            data1 =
                _status: 'OK'
                _auth: true
                _items: [
                    {_id:12345, _auth:{_edit:true, _delete:true}, name:'Bob'}
                    {_id:12346, _auth:{_edit:true, _delete:true}, name:'Fred'}
                    {_id:12347, _auth:{_edit:true, _delete:true}, name:'Bob'}
                ]
            data2 =
                _status: 'OK'
                _auth: true
                _items: [
                    {_id:12345, _auth:{_edit:true, _delete:true}, name:'Bob'}
                    {_id:12347, _auth:{_edit:true, _delete:true}, name:'Bob'}
                ]
            cache.find('test')
            .then (docs) ->
                assert.equal docs[1]._id, 12346
                cache.find('test', {name:'Bob'})
            .then (docs) ->
                assert.equal docs[1]._id, 12347
                cache.invalidateDoc('test', 12346)
                cache.find('test', {name:'Bob'})
            .then (docs) ->
                assert.equal docs[1]._id, 12347
                done()
            http.expectGET("/api/test").respond(200, data1)
            http.expectGET(encodeURI '/api/test?q={"name":"Bob"}').respond(200, data2)
            http.flush()


    describe "invalidateLists", ->
        it "invalidates find listCache of given collection", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [
                    {_id:12345, _auth:{_edit:true, _delete:true}, name:'Bob'}
                    {_id:12346, _auth:{_edit:true, _delete:true}, name:'Fred'}
                ]
            cache.find('test')
            .then (docs) ->
                assert.equal docs[1]._id, 12346
                cache.find('test')
            .then (docs) ->
                assert.equal docs[1]._id, 12346
                cache.invalidateLists('test')
                cache.find('test')
            .then (docs) ->
                assert.equal docs[1]._id, 12346
                done()
            http.expectGET("/api/test").respond(200, data)
            http.expectGET("/api/test").respond(200, data)
            http.flush()
        
        it "invalidates findOne listCache of given collection", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [
                    {_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}
                ]
            cache.findOne('test', {name:'Bob'})
            .then (doc) ->
                assert.equal doc._id, 12346
                cache.findOne('test', {name:'Bob'})
            .then (doc) ->
                assert.equal doc._id, 12346
                cache.invalidateLists('test')
                cache.findOne('test', {name:'Bob'})
            .then (doc) ->
                assert.equal doc._id, 12346
                done()
            http.expectGET(encodeURI '/api/test?q={"name":"Bob"}').respond(200, data)
            http.expectGET(encodeURI '/api/test?q={"name":"Bob"}').respond(200, data)
            http.flush()

        it "doesn't invalidate findOne docCache of individual documents", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [
                    {_id:12345, _auth:{_edit:true, _delete:true}, name:'Bob'}
                    {_id:12346, _auth:{_edit:true, _delete:true}, name:'Fred'}
                ]
            cache.find('test')
            .then (docs) ->
                assert.equal docs[1]._id, 12346
                cache.find('test')
            .then (docs) ->
                assert.equal docs[1]._id, 12346
                cache.invalidateLists('test')
                cache.findOne('test', {_id:12346})
            .then (doc) ->
                assert.equal doc._id, 12346
                done()
            http.expectGET("/api/test").respond(200, data)
            http.flush()

            
    describe "primus doc data event", ->
        it "invalidates docCache of given document", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [{_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            cache.findOne('test', {_id:12346})
            .then (doc) ->
                assert.equal doc._id, 12346
                cache.findOne('test', {_id:12346})
            .then (doc) ->
                assert.equal doc._id, 12346
                Primus.fire 'data', {action:'edit', collection:'test', id:12346, tid:4}
            .then ->
                cache.findOne('test', {_id:12346})
            .then (doc) ->
                assert.equal doc._id, 12346
                done()
            http.expectGET(encodeURI '/api/test?q={"_id":12346}').respond(200, data)
            http.expectGET(encodeURI '/api/test?q={"_id":12346}').respond(200, data)
            http.flush()
        
        it "invalidates listCache containing given document", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [
                    {_id:12345, _auth:{_edit:true, _delete:true}, name:'Bob'}
                    {_id:12346, _auth:{_edit:true, _delete:true}, name:'Fred'}
                ]
            cache.find('test')
            .then (docs) ->
                assert.equal docs[1]._id, 12346
                cache.findOne('test', {_id:12346})
            .then (doc) ->
                assert.equal doc._id, 12346
                Primus.fire 'data', {action:'edit', collection:'test', id:12346, tid:10}
            .then ->
                cache.find('test')
            .then (docs) ->
                assert.equal docs[1]._id, 12346
                done()
            http.expectGET("/api/test").respond(200, data)
            http.expectGET("/api/test").respond(200, data)
            http.flush()

        it "doesn't invalidate listCache not containing given document", (done) ->
            data1 =
                _status: 'OK'
                _auth: true
                _items: [
                    {_id:12345, _auth:{_edit:true, _delete:true}, name:'Bob'}
                    {_id:12346, _auth:{_edit:true, _delete:true}, name:'Fred'}
                    {_id:12347, _auth:{_edit:true, _delete:true}, name:'Bob'}
                ]
            data2 =
                _status: 'OK'
                _auth: true
                _items: [
                    {_id:12345, _auth:{_edit:true, _delete:true}, name:'Bob'}
                    {_id:12347, _auth:{_edit:true, _delete:true}, name:'Bob'}
                ]
            cache.find('test')
            .then (docs) ->
                assert.equal docs[1]._id, 12346
                cache.find('test', {name:'Bob'})
            .then (docs) ->
                assert.equal docs[1]._id, 12347
                Primus.fire 'data', {action:'edit', collection:'test', id:12346}
                cache.find('test', {name:'Bob'})
            .then (docs) ->
                assert.equal docs[1]._id, 12347
                done()
            http.expectGET("/api/test").respond(200, data1)
            http.expectGET(encodeURI '/api/test?q={"name":"Bob"}').respond(200, data2)
            http.flush()

            
    describe "primus list event", ->
        it "invalidates find listCache of given collection", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [
                    {_id:12345, _auth:{_edit:true, _delete:true}, name:'Bob'}
                    {_id:12346, _auth:{_edit:true, _delete:true}, name:'Fred'}
                ]
            cache.find('test')
            .then (docs) ->
                assert.equal docs[1]._id, 12346
                cache.find('test')
            .then (docs) ->
                assert.equal docs[1]._id, 12346
                Primus.fire 'data', {action:'create', collection:'test', id:1}
            .then ->
                cache.find('test')
            .then (docs) ->
                assert.equal docs[1]._id, 12346
                done()
            http.expectGET("/api/test").respond(200, data)
            http.expectGET("/api/test").respond(200, data)
            http.flush()
        
        it "invalidates findOne listCache of given collection", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [
                    {_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}
                ]
            cache.findOne('test', {name:'Bob'})
            .then (doc) ->
                assert.equal doc._id, 12346
                cache.findOne('test', {name:'Bob'})
            .then (doc) ->
                assert.equal doc._id, 12346
                Primus.fire 'data', {action:'delete', collection:'test', id:1}
            .then ->
                cache.findOne('test', {name:'Bob'})
            .then (doc) ->
                assert.equal doc._id, 12346
                done()
            http.expectGET(encodeURI '/api/test?q={"name":"Bob"}').respond(200, data)
            http.expectGET(encodeURI '/api/test?q={"name":"Bob"}').respond(200, data)
            http.flush()

        it "doesn't invalidate findOne docCache of individual documents", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [
                    {_id:12345, _auth:{_edit:true, _delete:true}, name:'Bob'}
                    {_id:12346, _auth:{_edit:true, _delete:true}, name:'Fred'}
                ]
            cache.find('test')
            .then (docs) ->
                assert.equal docs[1]._id, 12346
                cache.find('test')
            .then (docs) ->
                assert.equal docs[1]._id, 12346
                Primus.fire 'data', {action:'create', collection:'test', id:1}
                cache.findOne('test', {_id:12346})
            .then (doc) ->
                assert.equal doc._id, 12346
                done()
            http.expectGET("/api/test").respond(200, data)
            http.flush()
