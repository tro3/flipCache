p = console.log

describe "flipDoc", ->
    flipDoc = null
    flipCache = null
    http = null

    beforeEach ->
        module('flipDoc')
        module('flipCache')
        inject ($httpBackend, _flipDoc_, _flipCache_) ->
            flipDoc = _flipDoc_
            flipCache = _flipCache_
            http = $httpBackend
        inject ($rootScope) ->
            $rootScope.$on 'activeChange', (event, doc) ->
                doc.$get()

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

    assertBody = (exp) ->
        (data) ->
            body = JSON.parse(data)
            assert.property body, '_tid'
            delete body._tid
            assert.deepEqual body, exp
            true


    describe "$get", ->
        it "returns simple doc query", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [{_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            inst = flipDoc('test', 12346)
            inst.$get().then ->
                assertEqual inst, {_id:12346, _collection:'test', _auth:{_edit:true, _delete:true}, name:'Bob'}
                done()
            http.expectGET(encodeURI '/api/test?q={"_id":12346}').respond(200, data)
            http.flush()

        it "resolves simple doc query as doc", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [{_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            inst = flipDoc('test', 12346)
            inst.$get().then (doc) ->
                assertEqual doc, {_id:12346, _collection:'test', _auth:{_edit:true, _delete:true}, name:'Bob'}
                done()
            http.expectGET(encodeURI '/api/test?q={"_id":12346}').respond(200, data)
            http.flush()

        it "only queries db once for two retrievals", (done) ->
            data =
                _status: 'OK'
                _auth: true
                _items: [{_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            inst = flipDoc('test', 12346)
            inst.$get().then ->
                assertEqual inst, {_id:12346, _collection:'test', _auth:{_edit:true, _delete:true}, name:'Bob'}
                inst2 = flipDoc('test', 12346)
                inst2.$get().then ->
                    assertEqual inst2, {_id:12346, _collection:'test', _auth:{_edit:true, _delete:true}, name:'Bob'}
                done()
            http.expectGET(encodeURI '/api/test?q={"_id":12346}').respond(200, data)
            http.flush()


    describe "$save", ->
        it "sends POST api call for new object and updates it", (done) ->
            data =
                _status: 'OK'
                _item: {_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}
            inst = flipDoc('test', {name:'Bob'})
            inst.$save().then ->
                assertEqual inst, {_id:12346, _collection:'test', _auth:{_edit:true, _delete:true}, name:'Bob'}
                done()
            http.expectPOST("/api/test", {_id:null, _collection:'test', name:'Bob'}).respond(200, data)
            http.flush()

        it "resolves for new object as the object", (done) ->
            data =
                _status: 'OK'
                _item: {_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}
            inst = flipDoc('test', {name:'Bob'})
            inst.$save().then (doc) ->
                assertEqual doc, {_id:12346, _collection:'test', _auth:{_edit:true, _delete:true}, name:'Bob'}
                done()
            http.expectPOST("/api/test", {_id:null, _collection:'test', name:'Bob'}).respond(200, data)
            http.flush()

        it "sends PUT api call for existing object and updates it", (done) ->
            data =
                _status: 'OK'
                _item: {_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}
            inst = flipDoc('test', {_id:12346, name:'Bob'})
            inst.$save().then ->
                assertEqual inst, {_id:12346, _collection:'test', _auth:{_edit:true, _delete:true}, name:'Bob'}
                done()
            http.expectPUT("/api/test/12346", assertBody {_id:12346, _collection:'test', name:'Bob'}).respond(200, data)
            http.flush()

        it "resolves for existing object as the object", (done) ->
            data =
                _status: 'OK'
                _item: {_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}
            inst = flipDoc('test', {_id:12346, name:'Bob'})
            inst.$save().then (doc) ->
                assertEqual doc, {_id:12346, _collection:'test', _auth:{_edit:true, _delete:true}, name:'Bob'}
                done()
            http.expectPUT("/api/test/12346", assertBody {_id:12346, _collection:'test', name:'Bob'}).respond(200, data)
            http.flush()

        it "ignores follow-on primus event for update", (done) ->
            data =
                _status: 'OK'
                _item: {_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}
            inst = flipDoc('test', {_id:12346, name:'Bob'})
            inst.$save()
            .then (doc) ->
                assertEqual doc, {_id:12346, _collection:'test', _auth:{_edit:true, _delete:true}, name:'Bob'}
                Primus.fire 'data', {action:'edit', collection:'test', id:12346, tid: flipCache._tids[0]}
            .then ->
                assert.equal flipCache._tids.length, 0
                inst.$get()
            .then (doc) ->
                assertEqual doc, {_id:12346, _collection:'test', _auth:{_edit:true, _delete:true}, name:'Bob'}                
                done()
            http.expectPUT("/api/test/12346", assertBody {_id:12346, _collection:'test', name:'Bob'}).respond(200, data)
            http.flush()


    describe "$delete", ->
        it "sends DELETE api call for new object and clears it of data", (done) ->
            data =
                _status: 'OK'
            inst = flipDoc('test', {_id:12346, name:'Bob'})
            inst.$delete().then ->
                assertEqual inst, {_id:null, _collection:null, name:null}
                done()
            http.expectDELETE("/api/test/12346").respond(200, {_status:"OK"})
            http.flush()


    describe "setActive", ->        
        it "causes doc to be refreshed when primus event hits", (done) ->
            data =
                _status: 'OK'
                _items: [{_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            inst = flipDoc('test', 12346)
            inst.setActive()
            inst.$get().then ->
                assertEqual inst, {_id:12346, _collection:'test', _auth:{_edit:true, _delete:true}, name:'Bob'}
                Primus.fire 'data', {action:'edit', collection:'test', id:12346}
            .then ->
                done()
            http.expectGET(encodeURI '/api/test?q={"_id":12346}').respond(200, data)
            http.expectGET(encodeURI '/api/test?q={"_id":12346}').respond(200, data)
            http.flush()

        it "does not cause refresh when event hits for different document", (done) ->
            data =
                _status: 'OK'
                _items: [{_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            inst = flipDoc('test', 12346)
            inst.setActive()
            inst.$get().then ->
                assertEqual inst, {_id:12346, _collection:'test', _auth:{_edit:true, _delete:true}, name:'Bob'}
                Primus.fire 'data', {action:'edit', collection:'test', id:123}
            .then ->
                done()
            http.expectGET(encodeURI '/api/test?q={"_id":12346}').respond(200, data)
            http.flush()

        it "clears a previously-active list ", (done) ->
            data1 =
                _status: 'OK'
                _items: [{_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            data2 =
                _status: 'OK'
                _items: [{_id:12347, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            inst1 = flipDoc('test', 12346)
            inst2 = flipDoc('test', 12347) # Note that we did not $get, so docs are not active
            inst1.setActive()
            inst2.setActive()
            Primus.fire 'data', {action:'edit', collection:'test', id:12346}
            .then ->
                done()
            http.flush()


    describe "addActive", ->
        it "causes doc to be refreshed when primus event hits", (done) ->
            data =
                _status: 'OK'
                _items: [{_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            inst = flipDoc('test', 12346)
            inst.addActive()
            inst.$get().then ->
                assertEqual inst, {_id:12346, _collection:'test', _auth:{_edit:true, _delete:true}, name:'Bob'}
                Primus.fire 'data', {action:'edit', collection:'test', id:12346}
            .then ->
                done()
            http.expectGET(encodeURI '/api/test?q={"_id":12346}').respond(200, data)
            http.expectGET(encodeURI '/api/test?q={"_id":12346}').respond(200, data)
            http.flush()

        it "does not cause refresh when event hits for different document", (done) ->
            data =
                _status: 'OK'
                _items: [{_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            inst = flipDoc('test', 12346)
            inst.addActive()
            inst.$get().then ->
                assertEqual inst, {_id:12346, _collection:'test', _auth:{_edit:true, _delete:true}, name:'Bob'}
                Primus.fire 'data', {action:'edit', collection:'test', id:123}
            .then ->
                done()
            http.expectGET(encodeURI '/api/test?q={"_id":12346}').respond(200, data)
            http.flush()

        it "doesn't clear a previously-active list ", (done) ->
            data1 =
                _status: 'OK'
                _items: [{_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            data2 =
                _status: 'OK'
                _items: [{_id:12347, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            inst1 = flipDoc('test', 12346)
            inst2 = flipDoc('test', 12347) # Note that we did not $get, so docs are not active
            inst1.addActive()
            inst2.addActive()
            Primus.fire 'data', {action:'edit', collection:'test', id:12346}
            .then ->
                Primus.fire 'data', {action:'edit', collection:'test', id:12347}
            .then ->
                done()
            http.expectGET(encodeURI '/api/test?q={"_id":12346}').respond(200, data1)
            http.expectGET(encodeURI '/api/test?q={"_id":12347}').respond(200, data2)
            http.flush()


    describe "clearActives", ->
        it "clears the active cache", (done) ->
            data1 =
                _status: 'OK'
                _items: [{_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}]
            inst = flipDoc('test', 12346)
            inst.setActive()
            inst.$get().then ->
                assert.equal flipCache._actives.length, 1
                flipDoc.clearActives()
                assert.equal flipCache._actives.length, 0
                done()
            http.expectGET(encodeURI '/api/test?q={"_id":12346}').respond(200, data1)
            http.flush()
