p = console.log

describe "flipCache", () ->
  cache = null

  beforeEach ->
    module('flipCache')
    inject (flipCache) ->
      cache = flipCache

  it "passes dummy test", () ->
    assert.deepEqual cache.cache, {}
