p = console.log

describe "flipDoc", ->
    flipDoc = null
    http = null

    beforeEach ->
        module('flipDoc')
        inject ($httpBackend, _flipDoc_) ->
            flipDoc = _flipDoc_
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
            http.expectGET("/api/test?q=#{escape('{\"_id\"')}:#{escape('12346}')}").respond(200, data)
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
            http.expectGET("/api/test?q=#{escape('{\"_id\"')}:#{escape('12346}')}").respond(200, data)
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

        it "sends PUT api call for existing object and updates it", (done) ->
            data =
                _status: 'OK'
                _item: {_id:12346, _auth:{_edit:true, _delete:true}, name:'Bob'}
            inst = flipDoc('test', {_id:12346, name:'Bob'})
            inst.$save().then ->
                assertEqual inst, {_id:12346, _collection:'test', _auth:{_edit:true, _delete:true}, name:'Bob'}
                done()
            http.expectPUT("/api/test/12346", {_id:12346, _collection:'test', name:'Bob'}).respond(200, data)
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
