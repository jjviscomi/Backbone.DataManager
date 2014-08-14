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

  options = options || {}

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
    if !_.isUndefined(Backbone.Collection)
      Backbone.Collection::__class__ = 'Backbone.Collection'
      Backbone.Collection::__cache_key__ = null
      Backbone.Collection::__cache_key_gen__ = (data) ->
        console.log "Backbone:", @, this
        if _.isUndefined(data) or _.isNull(data) or _.isEmpty(data)
          @['__cache_key__'] = SHA1.hash "#{_.result(@, 'url')}"
        else
          @['__cache_key__'] = SHA1.hash "#{_.result(@, 'url')}?#{$.param(data)}"
        return @['__cache_key__']
  if !_.isUndefined(Thorax)
    if !_.isUndefined(Thorax.Model)
      Thorax.Model::__class__ = 'Thorax.Model'
    if !_.isUndefined(Thorax.Collection)
      Thorax.Collection::__class__ = 'Thorax.Collection'
    

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


  # Working with Thorax.Collections or Backbone.Collections
  @.addCollection = (collection, options={}) ->
    if _.isUndefined(collection) or _.isNull(collection) or _.isEmpty(collection) or !_.has(collection, '__class__') and !_.isEqual(collection['__class__'], 'Thorax.Collection') and !_.isEqual(model['__class__'], 'Backbone.Collection')
      return

    options = options || {}

    data = options.data
    name = options.name

    key = _.result(collection, '__cache_key__')

    if _.isUndefined(key) or _.isNull(key) or _.isEmpty(key)
      if _.isUndefined(data) or _.isNull(data) or _.isEmpty(data)
        key = _.result(collection, '__cache_key_gen__')
      else
        key = collection['__cache_key_gen__'](data)

    name = @.addName(key, name)

    _collections[key] = collection

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

  @