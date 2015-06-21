p = console.log

describe "flipList", ->
    flipList = null
    flipCache = null
    http = null

    beforeEach ->
        module('flipList')
        module('flipCache')
        inject ($httpBackend, _flipList_, _flipCache_) ->
            flipList = _flipList_
            flipCache = _flipCache_
            http = $httpBackend

    afterEach ->
        http.verifyNoOutstandingExpectation()
        http.verifyNoOutstandingRequest()
        
        
    assertEqual = (dut, exp) ->
        assert.sameMembers Object.keys(dut), Object.keys(exp)
        for key, val of exp
            if angular.isObject(val)
                assertEqual dut[key], val
            else
                assert.equal dut[key], val

    assertListEqual = (dut, exp) ->
        assert.equal dut.length, exp.length
        exp.forEach (item, ind) -> assertEqual(dut[ind], item)


    describe "$get", ->
        it "returns entire collection", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [{_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            inst = flipList(
                collection: 'test'
            )
            inst.$get().then ->
                assertListEqual inst, [{_id:12346, _collection:'test', _auth:{_edit:true, _delete:true}, name:'Bob'}]
                done()
            http.expectGET("/api/test").respond(200, data)
            http.flush()

        it "resolves as document", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [{_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            inst = flipList(
                collection: 'test'
            )
            inst.$get().then (doc) ->
                assertListEqual doc, [{_id:12346, _collection:'test', _auth:{_edit:true, _delete:true}, name:'Bob'}]
                done()
            http.expectGET("/api/test").respond(200, data)
            http.flush()

        it "returns simple query", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [{_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            inst = flipList(
                collection: 'test'
                filter: {name:'Bob'}
            )
            inst.$get().then ->
                assertListEqual inst, [{_id:12346, _collection:'test', _auth:{_edit:true, _delete:true}, name:'Bob'}]
                done()
            http.expectGET(encodeURI '/api/test?q={"name":"Bob"}').respond(200, data)
            http.flush()
            
        it "returns simple query with projection", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [{_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            inst = flipList(
                collection: 'test'
                filter: {name:'Bob'}
                fields: {name:1}
            )
            inst.$get().then ->
                assertListEqual inst, [{_id:12346, _collection:'test', _auth:{_edit:true, _delete:true}, name:'Bob'}]
                done()
            http.expectGET(encodeURI '/api/test?fields={"name":1}&q={"name":"Bob"}').respond(200, data)
            http.flush()
            

    describe "$setActive", ->
        it "causes list to be refreshed when primus event hits", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [{_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            inst = flipList(
                collection: 'test'
            )
            inst.$setActive()
            inst.$get().then ->
                assertListEqual inst, [{_id:12346, _collection:'test', _auth:{_edit:true, _delete:true}, name:'Bob'}]
                Primus.fire 'data', {action:'create', collection:'test', id:1}
            .then ->
                done()
            http.expectGET("/api/test").respond(200, data)
            http.expectGET("/api/test").respond(200, data)
            http.flush()

        it "does not cause refresh when event hits for different collection", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [{_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            inst = flipList(
                collection: 'test'
            )
            inst.$setActive()
            inst.$get().then ->
                assertListEqual inst, [{_id:12346, _collection:'test', _auth:{_edit:true, _delete:true}, name:'Bob'}]
                Primus.fire 'data', {action:'create', collection:'test2', id:1}
            .then ->
                done()
            http.expectGET("/api/test").respond(200, data)
            http.flush()

        it "clears a previously-active list ", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [{_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            inst = flipList(
                collection: 'test'
            )
            inst2 = flipList(
                collection: 'test'
                filter: {name:'Bob'}
            )
            inst.$get()
            inst2.$get()
            inst.$setActive()
            inst2.$setActive()
            Primus.fire 'data', {action:'create', collection:'test', id:1}
            .then ->
                done()
            http.expectGET("/api/test").respond(200, data)
            http.expectGET(encodeURI '/api/test?q={"name":"Bob"}').respond(200, data)
            http.expectGET(encodeURI '/api/test?q={"name":"Bob"}').respond(200, data)
            http.flush()


    describe "$addActive", ->
        it "causes list to be refreshed when primus event hits", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [{_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            inst = flipList(
                collection: 'test'
            )
            inst.$addActive()
            inst.$get().then ->
                assertListEqual inst, [{_id:12346, _collection:'test', _auth:{_edit:true, _delete:true}, name:'Bob'}]
                Primus.fire 'data', {action:'create', collection:'test', id:1}
            .then ->
                done()
            http.expectGET("/api/test").respond(200, data)
            http.expectGET("/api/test").respond(200, data)
            http.flush()

        it "does not cause refresh when event hits for different collection", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [{_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            inst = flipList(
                collection: 'test'
            )
            inst.$addActive()
            inst.$get().then ->
                assertListEqual inst, [{_id:12346, _collection:'test', _auth:{_edit:true, _delete:true}, name:'Bob'}]
                Primus.fire 'data', {action:'create', collection:'test2', id:1}
            .then ->
                done()
            http.expectGET("/api/test").respond(200, data)
            http.flush()

        it "does not clear a previously-active list ", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [{_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            inst = flipList(
                collection: 'test'
            )
            inst2 = flipList(
                collection: 'test'
                filter: {name:'Bob'}
            )
            inst.$addActive()
            inst2.$addActive()
            inst.$get()
            .then -> inst2.$get()
            .then -> Primus.fire 'data', {action:'create', collection:'test', id:1}
            .then -> done()
            http.expectGET("/api/test").respond(200, data)
            http.expectGET(encodeURI '/api/test?q={"name":"Bob"}').respond(200, data)
            http.expectGET("/api/test").respond(200, data)
            http.expectGET(encodeURI '/api/test?q={"name":"Bob"}').respond(200, data)
            http.flush()

    describe "$clearActives", ->
        it "clears the cache actives", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [{_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            inst = flipList(
                collection: 'test'
            )
            inst.$setActive()
            inst.$get().then ->
                assert.equal flipCache._actives.length, 1
                flipList.$clearActives()
                assert.equal flipCache._actives.length, 0
                done()
            http.expectGET("/api/test").respond(200, data)
            http.flush()
