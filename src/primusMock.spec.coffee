class PrimusMock
    constructor: () ->
        @events = {}
        
    on: (event, fn) ->
        @events[event] = [] if !(event of @events)
        @events[event].push fn
        
    fire: (event, data) ->
        q = null
        inject ($q) -> q = $q
        qs = []
        @events[event].forEach (fn) ->
            qs.push q (resolve, reject) ->
                try
                    fn(data)
                    resolve()
                catch err
                    console.log "Primus event handler error:", err
                    reject(err)
        q.all(qs)
        

root = exports ? this
root.Primus =
    connect: -> @mock = new PrimusMock
    fire: (event, data) -> @mock.fire(event, data)
        