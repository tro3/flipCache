p = console.log

describe "flipCache", ->
    cache = null
    http = null
  
    beforeEach ->
        module('flipCache')
        inject ($httpBackend, flipCache) ->
            http = $httpBackend
            cache = flipCache

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
            http.expectGET("/api/test?q=#{escape('{\"name\"')}:#{escape('\"Bob\"}')}").respond(200, data)
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
            http.expectGET("/api/test?q=#{escape('{\"name\"')}:#{escape('\"Bob\"}')}").respond(200, data)
            http.flush()


    describe "insert", ->        
        it "sends proper API call, caching result", (done) ->
            data = {name:'Bob'}
            respData = 
                _status: 'OK'
                _item: {_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}
            cache.insert('test', data).then (resp) ->
                assert.deepEqual resp, respData._item
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
                _item: {_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}
            cache.update('test', data).then (resp) ->
                assert.deepEqual resp, respData._item
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
                cache.remove('test', {_id:12346}).then (resp) ->
                    assert.isNull resp
                    cache.findOne('test', {_id:12346}).then (resp) ->
                        done()
            http.expectGET("/api/test?q=#{escape('{\"name\"')}:#{escape('\"Bob\"}')}").respond(200, data)
            http.expectDELETE("/api/test/12346").respond(200, {_status:"OK"})
            http.expectGET("/api/test?q=#{escape('{\"_id\"')}:#{escape('12346}')}").respond(200, data)
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
            http.expectGET("/api/test?q=#{escape('{\"name\"')}:#{escape('\"Bob\"}')}").respond(200, data)
            http.expectDELETE("/api/test/12346").respond(200, {_status:"OK"})
            http.expectGET("/api/test?q=#{escape('{\"name\"')}:#{escape('\"Bob\"}')}").respond(200, data)
            http.flush()