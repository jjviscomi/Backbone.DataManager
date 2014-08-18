# A DATA MANAGER LAYER FOR CONSISTENT AND RELIABLE DATA MANAGEMENT, INTENDED TO WORK WITH
# THORAX OR BACKBONE.
# WRITTEN BY JOE VISCOMI | @jjviscomi 
@.DataManager = (options) ->
  _ids = 0
  _models = {}
  _collections = {}
  _objects = {}

  # This will hold named refrences to hashes
  _namesToKeys = {}
  _keysToNames = {}

  # This will keep track on cache collections. It is a special type of collection
  # That is intended to be used to reset a working collection if an update has occured on the server.
  _caches = {}

  _clockMethods = {}

  options = options || {}

  # THIS IS THE AMOUNT OF TIME A CACHE IS PERSISTED ON THE SERVER WITHOUT NEW FETCHES BEING MADE TO IT
  CACHE_TIMEOUT = options.timeout || 300

  # Extend Backbone and Thorax
  if !_.isUndefined(Backbone) 
    Backbone.DataManager = @
    if !_.isUndefined(Backbone.Model)
      Backbone.Model::__class__ = 'Backbone.Model'
      Backbone.Model::__cache_key__ = null
      Backbone.Model::__cache_key_gen__ = (data) ->
        if _.isUndefined(data) or _.isNull(data) or _.isEmpty(data)
          @['__cache_key__'] = SHA1.hash "#{_.result(@, 'url')}"
        else
          @['__cache_key__'] = SHA1.hash "#{_.result(@, 'url')}?#{$.param(data)}"
        return @['__cache_key__']
      Backbone.Model::_fetched = false
    if !_.isUndefined(Backbone.Collection)
      Backbone.Collection::__class__ = 'Backbone.Collection'
      Backbone.Collection::__cache_key__ = null
      Backbone.Collection::__cache_key_gen__ = (data) ->
        if _.isUndefined(data) or _.isNull(data) or _.isEmpty(data)
          @['__cache_key__'] = SHA1.hash "#{_.result(@, 'url')}"
        else
          @['__cache_key__'] = SHA1.hash "#{_.result(@, 'url')}?#{$.param(data)}"
        return @['__cache_key__']
      Backbone.Collection::_fetched = false
      Backbone.Collection::sync = (method, collection, options) ->
        success = options.success
        data    = options.data
        # Save the data object
        @._data = data

        options.success = (resp) =>
          # Things we want to do if there was a sucess
          if !_.isUndefined(@['name']) and !_.isEqual(@.name, 'Cache')
            @['__cache_key_gen__'](data)
          @._fetched = true

          if !_.isUndefined(@['__cache_key__']) and !_.isEqual(@.name, 'Cache')
            # This mean the fetch was called explicitly on the collection and we should refresh the rate
            Backbone.DataManager.enableAutoRefresh @['__cache_key__']

          # Things they want to do if there was a success
          success(collection, resp, options) unless success

        return Backbone.sync.apply @, arguments

  if !_.isUndefined(Thorax)
    if !_.isUndefined(Thorax.Model)
      Thorax.Model::__class__ = 'Thorax.Model'
    if !_.isUndefined(Thorax.Collection)
      Thorax.Collection::__class__ = 'Thorax.Collection'
      Thorax.Collection::_fetched = false

  _getID = () ->
    _ids++

  _addKeyName = (key, name) ->
    if !_.isUndefined(key) and !_.isNull(key) and !_.isEmpty(key) and !_.has(_keysToNames, key)
      _keysToNames[key] = [name]
    else if _.has(_keysToNames, key) and _.isArray(_keysToNames[key]) and !_.contains(_keysToNames[key], name)
      _keysToNames[key].push name

  _removeKeyName = (key, name) ->
    if !_.isUndefined(key) and !_.isNull(key) and !_.isEmpty(key) and !_.has(_keysToNames, key)
      return false
    if _.has(_keysToNames, key) and _.isArray(_keysToNames[key]) and !_.contains(_keysToNames[key], name)
      return false

    _keysToNames[key] = _.without _keysToNames[key], name

    if _keysToNames[key].length is 0
      delete _keysToNames[key]

    true

  _getKeyFromName = (name) ->
    if _.contains(_.keys(_namesToKeys), name)
      return _namesToKeys[name]
    null

  _getNamesFromKey = (key) ->
    if _.has(_keysToNames, key)
      return _keysToNames[key]
    []

  _addCollectionToAutoRefreshCacheStore = (collection,options={}) ->
    data = options.data
    name = options.name
    refresh = options.refresh

    key = _.result(collection, '__cache_key__')

    if !_.isUndefined(refresh) or !_.isNull(refresh) and _.isNumber(refresh)
      # Create a generic cache collection
      if _.isUndefined(Thorax.Collection)
        l_cache = new Backbone.Collection null,
          'name': 'Cache'
          'model': collection.model
          '__cache_key__': key
          'url': () ->
            "/#{@.name.toUnderscore().toLowerCase()}/#{encodeURIComponent(@.__cache_key__)}"
      else
        l_cache = new Thorax.Collection null,
          'name': 'Cache'
          'model': collection.model
          '__cache_key__': key
          'url': () ->
            "/#{@.name.toUnderscore().toLowerCase()}/#{encodeURIComponent(@.__cache_key__)}"

      l_cache['name'] = 'Cache'
      l_cache['model'] = collection.model
      l_cache['__cache_key__'] = key
      l_cache['url'] = () ->
        "/#{@.name.toUnderscore().toLowerCase()}/#{encodeURIComponent(@.__cache_key__)}"


      _caches[key] = 
        'cache': l_cache
        'refresh': refresh
        '_nextRefreshIn': refresh
        '_enabled': true
        '_inProgress': false
        '_error': false
        '_refreshCount': 0
        '_lastRequestTime': null
        '_key': key
        '_scheduled': false
        '_refresh' : () =>
          # Don't Schedule it if there is somthing not right
          if !_caches[key]['_scheduled'] and !_caches[key]['_error'] and _caches[key]['_enabled'] and (_.isNull(_caches[key]['_lastRequestTime']) or (!_.isNull(_caches[key]['_lastRequestTime']) and (((new Date().getTime()) - _caches[key]['_lastRequestTime'])/1000) < 300))
            _caches[key]['_scheduled'] = true
            setTimeout () =>
              # If we think the cache has expired STOP FETCHING!
              if _.isNull(_caches[key]['_lastRequestTime']) or (!_.isNull(_caches[key]['_lastRequestTime']) and (((new Date().getTime()) - _caches[key]['_lastRequestTime'])/1000) < 300)
                # We only want to fetch if there hasn't been an error, another fetch is not in progress, an the actual collection has already been fetched
                if !_caches[key]['_error'] and !_caches[key]['_inProgress'] and (!_.isUndefined(collection['_fetched']) and collection['_fetched'])
                  
                  _caches[key]['_lastRequestTime'] = new Date().getTime()
                  _caches[key]['_inProgress'] = true
                  _caches[key]['_nextRefreshIn'] += _caches[key]['_refreshCount'] * _caches[key]['_refreshCount'] * Math.sqrt(_caches[key]['_nextRefreshIn'])
                  _caches[key]['_refreshCount'] += 1


                  l_cache.fetch
                    success: (cache, models) =>
                      collection.set models
                      cache.reset()
                      _caches[key]['_inProgress'] = false
                    error: () =>
                      # Stop Refreshing if there is an error, change active to false
                      _caches[key]['_inProgress'] = false
                      _caches[key]['_error'] = true
                      _caches[key]['_enabled'] = false
              else
                _caches[key]['_enabled'] = false

              _caches[key]['_scheduled'] = false

            , _.result(_caches[key], '_nextRefreshIn')

    return _.has(_caches, key)

  # Method for adding a named refrence to a managed object
  @.addName = (key, name) ->
    if !_.isUndefined(name) and !_.isNull(name) and !_.isEmpty(name) and !_.isUndefined(key) and !_.isNull(key) and !_.isEmpty(key)
      if _.has(_namesToKeys, name)
        # name alread exists, modify it
        name = "#{name}-#{_getID()}"
        _namesToKeys[name] = key
      else
        _namesToKeys[name] = key
      
      _addKeyName(key, name)

    return name
  # Method for removing a named refrence
  @.removeName = (name) ->
    if _.has(_namesToKeys, name)
      key = _namesToKeys[name]
      delete _namesToKeys[name]

    _removeKeyName(key, name)


  # Working with Thorax.Models or Backbone.Model
  @.addModel = (model, options={}) ->
    if _.isUndefined(model) or _.isNull(model) or _.isEmpty(model) or !_.has(model, '__class__') and !_.isEqual(model['__class__'], 'Thorax.Model') and !_.isEqual(model['__class__'], 'Backbone.Model')
      return

    options = options || {}

    data = options.data
    name = options.name

    key = _.result(model, '__cache_key__')

    if _.isUndefined(key) or _.isNull(key) or _.isEmpty(key)
      if _.isUndefined(data) or _.isNull(data) or _.isEmpty(data)
        key = _.result(model, '__cache_key_gen__')
      else
        key = model['__cache_key_gen__'](data)

    name = @.addName(key, name)

    _models[key] = model

    if _.isUndefined(name) or _.isNull(name) or _.isEmpty(name)
      return key

    {'key': key, 'name': name}

  @.getModelByKey = (key, options={}) ->
    if _.isUndefined(key) or _.isNull(key) or _.isEmpty(key) or !_.has(_models, key)
      return null

    _models[key]

  @.getModelByName = (name, options={}) ->
    if _.has(_namesToKeys, name)
      key = _.result _namesToKeys, name

      return @.getModelByKey key, options
    null

  @.removeModelByKey = (key, options={}) ->
    model = @.getModelByKey key

    names = _getNamesFromKey(key)
    _.each names, (name) =>
      @.removeName name

    if !_.isNull(model)
      delete _models[key]

    model

  @.enableAutoRefresh = (keyOrName,options={}) ->
    if @.has(keyOrName)
      collection = @.get keyOrName
      # Make sure it is a collection
      if !_.isUndefined(collection) and !_.isNull(collection) and !_.isUndefined(collection['__class__']) and (_.isEqual(collection['__class__'], 'Thorax.Collection') or _.isEqual(model['__class__'], 'Backbone.Collection'))
        key = collection['__cache_key__']
        # Make sure it has a key an the object is already registered into the cache
        if !_.isUndefined(key) and !_.isNull(key) and !_.isUndefined(_caches[key]) and !_.isNull(_caches[key])
          cache_obj = _caches[key]
          _caches[key]['_enabled'] = true
          if _.has(options, 'refresh') and _.isNumber(options.refresh)
            _caches[key]['refresh'] = options.refresh
          
          _caches[key]['_nextRefreshIn'] = _caches[key]['refresh']
          _caches[key]['_refreshCount'] = 1
          _caches[key]['_inProgress'] = false
          _caches[key]['_error'] = false
          _caches[key]['_lastRequestTime'] = null
          _caches[key]['_scheduled'] = false

          return true
    return false

  @.disableAutoRefresh = (keyOrName,options={}) ->
    if @.has(keyOrName)
      collection = @.get keyOrName
      # Make sure it is a collection
      if !_.isUndefined(collection) and !_.isNull(collection) and !_.isUndefined(collection['__class__']) and (_.isEqual(collection['__class__'], 'Thorax.Collection') or _.isEqual(model['__class__'], 'Backbone.Collection'))
        key = collection['__cache_key__']
        # Make sure it has a key an the object is already registered into the cache
        if !_.isUndefined(key) and !_.isNull(key) and !_.isUndefined(_caches[key]) and !_.isNull(_caches[key])
          cache_obj = _caches[key]
          _caches[key]['_enabled'] = false
          _caches[key]['_inProgress'] = false
          _caches[key]['_error'] = false
          _caches[key]['_scheduled'] = false
          return true
    return true

  @.toggleAutoRefresh = (keyOrName,options={}) ->
    if @.has(keyOrName)
      collection = @.get keyOrName
      # Make sure it is a collection
      if !_.isUndefined(collection) and !_.isNull(collection) and !_.isUndefined(collection['__class__']) and (_.isEqual(collection['__class__'], 'Thorax.Collection') or _.isEqual(model['__class__'], 'Backbone.Collection'))
        key = collection['__cache_key__']
        # Make sure it has a key an the object is already registered into the cache
        if !_.isUndefined(key) and !_.isNull(key) and !_.isUndefined(_caches[key]) and !_.isNull(_caches[key])
          if _caches[key]['_enabled']
            return @.disableAutoRefresh keyOrName
          else
            return @.enableAutoRefresh keyOrName

  # Working with Thorax.Collections or Backbone.Collections
  @.addCollection = (collection, options={}) ->
    if _.isUndefined(collection) or _.isNull(collection) or _.isEmpty(collection) or !_.has(collection, '__class__') and !_.isEqual(collection['__class__'], 'Thorax.Collection') and !_.isEqual(model['__class__'], 'Backbone.Collection')
      return

    options = options || {}

    data = options.data
    name = options.name
    refresh = options.refresh

    key = _.result(collection, '__cache_key__')

    if _.isUndefined(key) or _.isNull(key) or _.isEmpty(key)
      if _.isUndefined(data) or _.isNull(data) or _.isEmpty(data)
        key = _.result(collection, '__cache_key_gen__')
      else
        key = collection['__cache_key_gen__'](data)

    name = @.addName(key, name)

    _collections[key] = collection

    if !_.isUndefined(refresh) or !_.isNull(refresh) and _.isNumber(refresh)
      _addCollectionToAutoRefreshCacheStore(collection, options)

    if _.isUndefined(name) or _.isNull(name) or _.isEmpty(name)
      return key

    {'key': key, 'name': name}

  @.getCollectionByKey = (key, options={}) ->
    if _.isUndefined(key) or _.isNull(key) or _.isEmpty(key) or !_.has(_collections, key)
      return null

    _collections[key]

  @.getCollectionByName = (name, options={}) ->
    if _.has(_namesToKeys, name)
      key = _.result _namesToKeys, name

      return @.getCollectionByKey key, options
    null

  @.removeCollectionByKey = (key, options={}) ->
    collection = @.getCollectionByKey key

    names = _getNamesFromKey(key)
    _.each names, (name) =>
      @.removeName name

    
    @.disableAutoRefresh key
    

    if !_.isNull(collection)
      delete _collections[key]

    collection


  # Working with Generic Objects
  @.addObject = (obj, options={}) ->
    if _.isUndefined(obj) or _.isNull(obj) or _.isEmpty(obj)
      return

    options = options || {}

    name = options.name
    if _.isArray(obj)
      keys = _.flatten(obj)
    else
      keys = _.keys(obj).toString()

    time = new Date().getTime()
    salt1 = Math.floor((Math.random() * 100000) + 1)
    salt2 = Math.floor((Math.random() * 100000) + 1)

    key = SHA1.hash "#{salt1}:#{time}:#{keys}:#{time}:#{salt2}"

    name = @.addName(key, name)

    _objects[key] = obj

    if _.isUndefined(name) or _.isNull(name) or _.isEmpty(name)
      return key

    {'key': key, 'name': name}

  @.getObjectByKey = (key, options={}) ->
    if _.isUndefined(key) or _.isNull(key) or _.isEmpty(key) or !_.has(_objects, key)
      return null

    _objects[key]

  @.getObjectByName = (name, options={}) ->
    if _.has(_namesToKeys, name)
      key = _.result _namesToKeys, name

      return @.getObjectByKey key, options
    null

  @.removeObjectByKey = (key, options={}) ->
    obj = @.getObjectByKey key
    
    names = _getNamesFromKey(key)
    _.each names, (name) =>
      @.removeName name

    if !_.isNull(obj)
      delete _objects[key]

    obj


  # Generic get/set/remove
  # These are the top level methods with the highest level of abstraction
  @.get = (keyOrName) ->
    if @.hasName(keyOrName)
      keyOrName = _getKeyFromName(keyOrName)

    if @.hasKey(keyOrName)
      if _.contains(_.keys(_models), keyOrName)
        return _models[keyOrName]
      else if _.contains(_.keys(_collections), keyOrName)
        return _collections[keyOrName]
      else
        return _objects[keyOrName]

    null

  @.set = (obj,options={}) ->
    if _.isUndefined(obj) or _.isNull(obj)
      return null

    if _.isArray(obj)
      return @.addObject(obj, options)
    else if _.isObject(obj) and _.isEqual(_.result(obj,'__class__'), 'Thorax.Model')
      return @.addModel(obj, options)
    else if _.isObject(obj) and _.isEqual(_.result(obj,'__class__'), 'Thorax.Collection')
      return @.addCollection(obj, options)
    else if _.isObject(obj)
      return @.addObject(obj, options)

    null

  @.remove = (keyOrName) ->
    if @.hasName(keyOrName)
      name = keyOrName
      key = _getKeyFromName(name)
      names = _getNamesFromKey(key)
    else if @.hasKey(keyOrName)
      key = keyOrName
      names = _getNamesFromKey(key)
    else
      return null

    _.each names, (name) =>
      @.removeName name

    if _.contains(_.keys(_models), key)
      return @.removeModelByKey key
    else if _.contains(_.keys(_collections), key)
      return @.removeCollectionByKey key
    else if _.contains(_.keys(_objects), key)
      return @.removeObjectByKey key

    null

  @.flush = () ->
    _ids = 0
    _models = {}
    _collections = {}
    _objects = {}
    _namesToKeys = {}
    _keysToNames = {}
      
    _caches = {}

  @.getKeys = () ->
    _.flatten [_.keys(_models), _.keys(_collections), _.keys(_objects)]

  @.getNames = () ->
    _.keys _namesToKeys

  @.hasKey = (key) ->
    if _.isUndefined(key) or _.isNull(key) or _.isEmpty(key) or (!_.has(_models, key) and !_.has(_collections, key) and !_.has(_objects, key))
      return false

    true

  @.hasName = (name) ->
    if _.isUndefined(name) or _.isNull(name) or _.isEmpty(name) or !_.has(_namesToKeys, name)
      return false

    true

  @.has = (keyOrName) ->
    @.hasName(keyOrName) or @.hasKey(keyOrName)

  # Extend the Application object to have Backbone Event Functionality  
  _.extend @, Backbone.Events

  # This method is run when the Object Application is created.
  _.extend @, 
    initialize : () ->
      null

  # Apply the OPTIONS to the object after we are done setting the defaults.
  _.extend @, options

  # Need to return the new Application from the constructor.
  @.initialize.call(@)

  _.defer () =>
    # Start the DataManager Clock
    setInterval () =>
      _.each _clockMethods, (method_obj, key, list) =>
        method = method_obj.method
        method_arguments = method_obj.args
        method_callback  = method_obj.callback

        if !_.isUndefined(method_callback) and _.isFunction(method_callback)
          if !_.isUndefined(method_arguments) and _.isArray(method_arguments)
            method_callback method.apply(@, method_arguments)
          else
            method_callback method.apply(@)
        else
          if !_.isUndefined(method_arguments) and _.isArray(method_arguments)
            method.apply(@, method_arguments)
          else
            method.apply(@)
      _.each _caches, (cache, key, list) =>
        if !_.isUndefined(cache['_enabled']) and cache['_enabled']
          cache['_refresh'].call(@)

    , 61001
  @