((undefined_) ->
  "use strict"
  
  #### 
  #### CommonJS Shim
  ####
  _ = undefined
  Backbone = undefined
  exports = undefined
  if typeof window is "undefined"
    _ = require("underscore")
    Backbone = require("backbone")
    exports = module.exports = Backbone
  else
    _ = window._
    Backbone = window.Backbone
    exports = window

  #### 
  #### Extension to Underscore
  ####

  # Extensions to Underscore that allows us to see if something is a Backbone.Model
  _.isBackboneModel = (obj) ->
    if !_.isUndefined(obj) and _.isObject(obj) and _.has(obj, '_className') and !_.isNull(obj['_className'].match(/Backbone.Model/g))
      true
    else 
      false

  # Extensions to Underscore that allows us to see if something is a Backbone.Collection
  _.isBackboneCollection = (obj) ->
    if !_.isUndefined(obj) and _.isObject(obj) and _.has(obj, '_className') and !_.isNull(obj['_className'].match(/Backbone.Collection/g))
      true
    else 
      false

  #### 
  #### Inject a ModelManager into Backbone
  ####
  
  Backbone.Manager = new () ->
    
    #### 
    #### Private Member Variables
    ####

    # This is a system wide catalog
    _store = {
      'models' : {}
      'collections' : {}
    }

    _pending = {
      'models' : {}
      'collections' : {}
    }

    # This is a quicklookup hash
    _inventory = {}

    # This is primarly used for metrics
    _registry = {}

    @.Models = {}

    @.Collections = {}

    @.Routers = {}

    @.Views = {}

    # Convention for holding the class name
    _className = "Backbone.Manager"


    #### 
    #### Private Member Methods
    ####

    # 
    # Method:      _register
    # Interface:   Private
    # Prototype:   Backbone.Collection _registerCollection(Backbone.Collection)
    # Return Type: Backbone.Collection
    # Description: Registers a collection with the ModelManager.
    # Author:      Joseph J. Viscomi | jjviscomi@gmail.com
    #
    _registerCollection = (collection) =>
      if !_.has(_inventory, collection['collectionName'])
        _inventory[collection['collectionName']] = []

      if !_.has(_store.collections, collection['collectionlName'])
        _store.collections[collection['collectionName']] = {}
        _pending.collections[collection['collectionName']] = {}

      _inventory[collection['collectionName']].push collection.cid
      _pending.collections[collection['collectionName']][collection.cid] = collection
      _registry[collection.cid] = collection

      # This way of regestering a collection is probably not a good idea
      collection.once "reset", (collection) =>
        _store.collections[collection['collectionName']][_.result(collection, 'url')] = collection
        collection.trigger "register:collection", collection, _.clone _store.collections[collection['collectionName']][_.result(collection, 'url')]

        if !_.isUndefined(collection) and _.has(collection, 'collectionName') and _.has(_pending.collections, collection['collectionName'])
          delete _pending.collections[collection['collectionName']][collection.cid]
          if _.isEmpty(_pending.collections[collection['collectionName']])
            delete _pending.collections[collection['collectionName']]

      collection

    # 
    # Method:      _register
    # Interface:   Private
    # Prototype:   Backbone.Model _registerModel(Backbone.Model)
    # Return Type: Backbone.Model
    # Description: Properly registers the given model with the ModelManager.
    # Author:      Joseph J. Viscomi | jjviscomi@gmail.com
    #
    _registerModel = (model) =>
      if !_.has(_inventory, model['modelName'])
        _inventory[model['modelName']] = []

      if !_.has(_store.models, model['modelName'])
        _store.models[model['modelName']] = []

      _inventory[model['modelName']].push model.id
      _store.models[model['modelName']].push model
      _registry[model.cid] = model

      # Trigger the model event of registration
      model.trigger "register:model", model, _.clone _store.models[model['modelName']]

      # This needs to happen after the current call stack completes.
      _.defer((model) ->
        # This will help with housekeeping! Collect all of the models with the same id.
        models = _.filter _store.models[model['modelName']], (item) -> 
          _.isEqual item.id, model.id

        # Fire off a duplicate model notice, very helpful in detecting memory leaks!
        if models.length > 1
          # Sort the models by when they were created.
          models = _.sortBy(models, '_created')
          # Trigger the event on the first created model.
          models[0].trigger "duplicate:model", model, models
      , model)

      model

    # 
    # Method:      _pendingRegister
    # Interface:   Private
    # Prototype:   Backbone.Model _pendingRegister(Backbone.Model)
    # Return Type: Backbone.Model
    # Description: When a model is created it is registed with this method before it is populated or synced with the server.
    # Author:      Joseph J. Viscomi | jjviscomi@gmail.com
    #
    _pendingRegister = (model) =>
      if !_.has(_pending.models, model['modelName'])
        _pending.models[model['modelName']] = []

      # Registers an event on the model that watches for it to be not new
      model.on "change", _prefetch, model
      _pending.models[model['modelName']].push model

      if _.has(model, 'timeToDestroy') and _.isNumber(model['timeToDestroy']) and model['timeToDestroy'] > 0
        _.delay((model)=>
          if model.isNew() and _.has(model, 'attributes') and _.isEmpty(model['attributes']) and _.has(model, '_created')
            model.trigger "destruct:model", model
            @.clean model
        , model['timeToDestroy'] * 1000, model
        )
      model

    # 
    # 
    # Method:      _prefetch
    # Interface:   Private
    # Prototype:   Backbone.Model _prefetch(Backbone.Model)
    # Return Type: Backbone.Model
    # Description: This is executed when a model changes, to detect when it is no longer new and register it with the store.
    # Author:      Joseph J. Viscomi | jjviscomi@gmail.com
    #
    _prefetch = (model) =>
      # Remove the model from the pending container
      if !model.isNew()
        _.each(_pending.models[model['modelName']], (element, index, list) ->
          if _.isEqual(model, element)
            list.splice index, 1
        )

        _registerModel model
        
        # Since this model is no longer new remove the _prefetch change event
        model.off "change", _prefetch

      model

    # 
    # Method:      _findCollection
    # Interface:   Private
    # Prototype:   Backbone.Collection _findCollection(Backbone.Collection)
    # Return Type: Backbone.Collection
    # Description: Fetch a collection / Return the duplicate
    # Author:      Joseph J. Viscomi | jjviscomi@gmail.com
    #
    _findCollection = (collection) =>
      collectionName = "default"
      if !_.has(collection, 'collectionName')
        collectionName = collection['collectionName']

      if _.has(_inventory, collectionName) and (_inventory[collectionName].length > 0)

        existingCollection = _.find(_store.collections[collectionName], (element) ->
          _.isEqual _.result(element, 'url'), _.result(collection, 'url')
        )
      if _.isUndefined existingCollection
        collection
      else
        collection.trigger "duplicate:collection", collection, existingCollection
        Backbone.Manager.clean collection
        existingCollection


    #### 
    #### Protected Member Methods
    ####

    # 
    # Method:      clean
    # Interface:   Protected / Public
    # Prototype:   (void) clean(Backbone.Collection || Backbone.Model)
    # Return Type: (void)
    # Description: Housekeeping method to clean up duplicate models or collection in the ModelManager.
    # Author:      Joseph J. Viscomi | jjviscomi@gmail.com
    #
    @.clean = (modelOrCollection) ->
      if !_.isUndefined(modelOrCollection) and _.has(modelOrCollection, 'attributes')
        # Working with a model
        # Remove the model from the pending container
        _.each(_pending.models[modelOrCollection['modelName']], (element, index, list) ->
          if _.isEqual(modelOrCollection, element)
            list.splice index, 1
        )

        if _.isEmpty(_pending.models[modelOrCollection['modelName']])
          delete _pending.models[modelOrCollection['modelName']]

        # Remove the model from the store container
        _.each(_store.models[modelOrCollection['modelName']], (element, index, list) ->
          if _.isEqual(modelOrCollection, element)
            list.splice index, 1
        )
        # Correct the inventory
        _inventory[modelOrCollection['modelName']] = _.uniq(_inventory[modelOrCollection['modelName']])
        
        # Correct the registry
        delete _registry[modelOrCollection.cid]

      else if _.isBackboneCollection modelOrCollection
        # Working with a collection
        # Need to postphone the delete until after the call stack.
        _.defer () ->
          delete _pending.collections[modelOrCollection['collectionName']][modelOrCollection.cid]

    # 
    # Method:      find
    # Interface:   Protected / Public
    # Prototype:   Backbone.Model find(String modelName, Integer sid)
    # Return Type: Backbone.Model || null
    # Description: Returns a model for the given model name and ServerID if sid is undefined it will look for a reusable model. If a model is not found it returns null.
    # Author:      Joseph J. Viscomi | jjviscomi@gmail.com
    #
    @.find = (modelName, sid) ->
      # Corectly format the case of the model name.
      if !_.isUndefined(modelName)
        modelName = modelName.toCamel().capitalize()

        model = _.find(_store.models[modelName], (model) ->
          _.isEqual model.id, sid
        )

      # Grab a empty pending model if no id was specified.
      if _.isUndefined model and _.isUndefined sid
        model = _.find(_pending.models[modelName], (element) ->
          _.isEmpty element.attributes
        )

      if _.isUndefined(model)
        # Return null is no model was found.
        null
      else
        model

    # 
    # Method:      registered
    # Interface:   Protected / Public
    # Prototype:   Boolean registered(Backbone.Model)
    # Return Type: Boolean
    # Description: Checks to see if a given model type is already in inventory with the ModelManager.
    # Author:      Joseph J. Viscomi | jjviscomi@gmail.com
    #
    @.registered = (model) ->
      if _.isBackboneModel model
        id = _.find(_inventory[model['modelName']], (id) ->
          _.isEqual model.id, id
        )

      if _.isUndefined id
        duplicate = _.find(_pending.models[model['modelName']], (element) ->
          _.isEqual model.attributes element.attributes
        )

      _.isUndefined(id) or _.isUndefined(duplicate)

    # 
    # Method:      add
    # Interface:   Protected / Public
    # Prototype:   Backbone.Model || Backbone.Collection add(Backbone.Model || Backbone.Collection)
    # Return Type: Backbone.Model || Backbone.Collection
    # Description: Adds a model or collection to the ModelManager.
    # Author:      Joseph J. Viscomi | jjviscomi@gmail.com
    #
    @.add = (modelOrCollection) ->
      if _.isBackboneModel modelOrCollection
        # We are working with a model
        if modelOrCollection.isNew()
          #if @.registered(modelOrCollection)
          _pendingRegister modelOrCollection 
        else 
          modelOrCollection = _registerModel modelOrCollection
      else if _.isBackboneCollection modelOrCollection
        # We are working with a collection
        modelOrCollection = _findCollection modelOrCollection

        _registerCollection modelOrCollection

      modelOrCollection

    #
    # Method:      collect
    # Interface:   Protected / Public
    # Prototype:   Array collect(String modelName)
    # Return Type: Array of Backbone.Models
    # Description: Returns an array of Backbone.Models with the given modelName.
    # Author:      Joseph J. Viscomi | jjviscomi@gmail.com
    #
    @.collect =  (modelName) ->
      if !_.isUndefined(modelName)
        modelName = modelName.toCamel().capitalize()

      if !_.isUndefined(modelName) and _.has(_inventory, modelName) and _.has(_store.models, modelName)
        _.clone _store.models[modelName]
      else
        []


    #
    # Method:      registerClass
    # Interface:   Protected / Public
    # Prototype:   (void) registerClass(Class, Object)
    # Return Type: (void)
    # Description: Registers the Class to a storage container so it can be reused.
    # Author:      Joseph J. Viscomi | jjviscomi@gmail.com
    #
    @.registerClass = (klass, hash) ->
      $super = klass.extend
      klass.extend = () ->
        child = $super.apply(@, arguments)
        if (child.prototype.name) 
          hash[child.prototype.name] = child
        
        child

    #
    # Method:      inspect
    # Interface:   Protected / Public
    # Prototype:   (void) inspect(void)
    # Return Type: (void)
    # Description: Used for debuggin, allows you to inspect the internal state of the ModelManager
    # Author:      Joseph J. Viscomi | jjviscomi@gmail.com
    #
    @.inspect = () ->
      if _.isUndefined(window)
        'Not running in a web browser'
      else
        if _.has(window, 'console')
          obj = {
           'store'    : 
              'models'      : _.clone _store['models']
              'collections' : _.clone _store['collections']

            'pending'  :
              'models'      : _.clone _pending['models']
              'collections' : _.clone _pending['collections']

            'inventory': _.clone _inventory
            
            'registry' : _.clone _registry
          }
          console.log obj

    # The constructor return this (the ModelManager)
    @



  #### 
  #### Extend the Backbone.Model
  ####

  #
  # This addes some basic functinoality to the Backbone.Models for interacting with the Model.Manager and maintaining parent
  # child relationships with RESTful style routes, and other events to help manage these relationships. 
  #

  #### 
  #### NEW MODEL PROPERTIES
  ####

  # name: This should be the server side and client side name of the model. This does expect some level of convention here.
  # parents: This is an array that contains refrences to all the "parents" of this model, most of the time you do not want to access this array directly.
  # children: This is an array that contains the refrences to all the "children" of this model, most of the time you do not want to access this array directly.
  # recycle: This property defaults to true, it indicates to reuse models if one already exists. The newest info will be merged with existing models. This will help keep all client views in sync with the same data.
  # timeToDestroy: This is the number of seconds to wait before auto destroying an unused client side model, setting it to 0 disables auto destroy. Its default is 5.

  #### 
  #### NEW MODEL EVENTS
  ####

  # register:model is triggered when the model is registered with the ModelManager
  # duplicate:model is triggered when another model with the same id has been located in the ModelManager
  # destruct:model is triggered when a model is auto destroyed
  # sync:parent is triggered when the parent of this model is synced with the server
  # sync:child is triggered when a child of this model is synced with the server
  # add:parent is triggered when a parent is added to this model
  # remove:parent is triggered when a parent is removed from this child
  # add:child is triggered when a child is added to this model
  # remove:child is triggered when a child is removed from this parent

  #### 
  #### NEW MODEL METHODS
  ####

  # addParent
  # removeParent
  # addChild
  # removeChild

  #### 
  #### OVER WRITEN MODEL METHODS
  ####

  # toJSON
  # url
  # initalize
  #
  _.extend Backbone.Model::, Backbone.Events, 
    initialize: () ->

      # Register all new methods added to Backbone.Model
      _.bindAll @, "all", "toJSON", "url", "addParent", "addChild", "removeParent", "removeChild"

      # Used for debugging the backbone events
      # @.on "all", @.all, @

      # Set a Model name, make sure this is formated correctly
      @.name || (@.name = "default")
      @.name =  @.name.toCamel().capitalize()
      @.modelName = @.name
      

      # This extends the default Backbone.Model with information
      @._className || (@._className = "Backbone.Model.#{@.modelName}")

      @._created = new Date().getTime()

      # Containers for relationships
      @.parents || (@.parents = [])
      @.children || (@.children = [])

      @.recycle || (@.recycle = true)

      @.timeToDestroy || (@.timeToDestroy = 5)

      # Merge the duplicate models if recycle is true
      @.on "duplicate:model", (model, [models]) =>
        # Overwrite the older (this) model with the newest.
        if _.has(@, 'recycle') and _.isBoolean(@['recycle']) and @['recycle']
          # Before Doing the merge we need to clean up our ModelManager, that means cleaninup any instance of model
          Backbone.Manager.clean model
          # Merge the objects
          _.extend @, models

      # If a model does a sync to the server then tell all the children and its parents about it
      @.on "sync", (model, resp, options) =>
        _.each(model.children, (element, index, list) ->
            element.trigger "sync:parent", element, model, _.clone(_.result(element, 'url'))
        )
        _.each(model.parents, (element, index, list) ->
            element.trigger "sync:child", element, model, _.clone(_.result(element, 'url'))
        )

      # Register the Model with the ModelManager
      _.extend @, Backbone.Manager.add(@) 

    toJSON: () ->
      obj = {}
      if _.has(@, "modelName")
        obj[@['modelName'].toUnderscore()] = _.clone @.attributes
      else
        obj['to_json'] = _.clone @.attributes

      obj

    url: (collection) ->
      if !_.isUndefined collection
        base = _.result(@, 'urlRoot') || urlError()
        if @.isNew() 
          base
        else
          if !(base.slice(-1) is '/')
            base = base + '/'
          base = base + encodeURIComponent @.id
      else
        collection = _.find(@.parents, (item) =>
          if !_.isUndefined(item) and _.has(item, 'models')
            tempModel = new item.model()
            _.isEqual tempModel._className, @._className
        )

        base = (if _.isUndefined(collection) or _.isEmpty(collection["parents"]) then "" else _.result(collection, "url"))
        base = base + _.result(@, 'urlRoot') + '/'
        if !@.isNew()
          base = base + encodeURIComponent(@.id)

      base

    #
    # Method:      addParent
    # Interface:   Public
    # Prototype:   Boolean addParent(Backbone.Model || Backbone.Collection)
    # Return Type: Boolean
    # Description: Adds the given parent as a Parent of this Model. Returns true if it was successfully added, false otherwise.
    # Author:      Joseph J. Viscomi | jjviscomi@gmail.com
    #
    addParent: (parent) ->
      if _.has(@, 'parents')
        # Checks to see if the current model is already the parent of this collection
        index = _.find(@.parents, (element, index, list) ->
          _.isEqual parent, element
        )

        # Add the modelOrCollection as a parent to the model
        if _.isUndefined(index)
          @.parents.push parent
          # Trigger an "add:parent" event on this model
          @.trigger "add:parent", @, parent

          # Only add it to the child of a parent who is a model
          if _.isBackboneModel parent
            _.defer (parent) ->
              parent.addChild @
            , parent
          true 
        else
          false
      else
        false

    #
    # Method:      removeParent
    # Interface:   Public
    # Prototype:   Boolean removeParent(Backbone.Model || Backbone.Collection)
    # Return Type: Boolean
    # Description: Removes the given parent from this Model. Returns true if it was successfully removed, false otherwise.
    # Author:      Joseph J. Viscomi | jjviscomi@gmail.com
    #
    removeParent: (modelOrCollection) ->
      if _.has(@, 'parents')
        # Remove the given parent
        @.parents = _.reject(@.parents, (item) ->
          _.isEqual item, modelOrCollection
        )
        @.trigger "remove:parent", @, modelOrCollection
        _.defer (modelOrCollection) ->
          # Remove the child relationship
          modelOrCollection.removeChild @    
        , modelOrCollection   
        true 
      else
        false 

    #
    # Method:      addChild
    # Interface:   Public
    # Prototype:   Boolean addChild(Backbone.Model || Backbone.Collection)
    # Return Type: Boolean
    # Description: Adds the given child as a Child of this Model. Returns true if it was successfully added, false otherwise.
    # Author:      Joseph J. Viscomi | jjviscomi@gmail.com
    #
    addChild: (child) ->
      if !_.isUndefined(child) and _.has(@, 'children')
        # Checks to see if the current model is already the parent of this collection
        index = _.find(@.children, (element, index, list) ->
          _.isEqual child, element
        )

        # Add the modelOrCollection as a parent to the model
        if _.isUndefined(index) and !_.isNull(child)
          @.children.push child
          # Trigger an "add:parent" event on this model
          @.trigger "add:child", @, child
          _.defer (child, parent) ->
            child.addParent parent
          , child, @
          true 
        else
          false
      else
        false

    #
    # Method:      removeChild
    # Interface:   Public
    # Prototype:   Boolean removeChild(Backbone.Model || Backbone.Collection)
    # Return Type: Boolean
    # Description: Removes the given child from this Model. Returns true if it was successfully removed, false otherwise.
    # Author:      Joseph J. Viscomi | jjviscomi@gmail.com
    #
    removeChild: (child) ->
      if !_.isUndefined(child) and _.has(@, 'children')
        # Checks to see if the given child is in the children array
        index = _.find(@.children, (element, index, list) ->
          _.isEqual child, element
        )

        if !_.isUndefined(index) and !_.isNull(child)
          @.children = _.reject(@.children, (item) ->
            _.isEqual child, item
          )
          @.trigger "remove:child", @, child
          _.defer (child, parent) ->
            child.removeParent parent
          , child, @
          true 
        else
          false
      else
        false

    all: () ->
      console.log "Model:Events", arguments

  #### 
  #### Extend the Backbone.Collection
  ####

  #
  # This addes some basic functinoality to the Backbone.Collections for interacting with the Model.Manager and maintaining parent
  # child relationships with RESTful style routes, and other events to help manage these relationships. 
  #

  #### 
  #### NEW COLLECTION PROPERTIES
  ####

  # name: This should be the server side (Table) and client side name of the Collection (usually the model name in the plural). This does expect some level of convention here.
  # parents: This is an array that contains refrences to all the "parents" of this collection, most of the time you do not want to access this array directly.

  #### 
  #### NEW COLLECTION EVENTS
  ####

  # register:collection is triggered when the collection is registered with the ModelManager
  # duplicate:collection is triggered when another model with the same id has been located in the ModelManager
  # sync:parent is triggered when the parent of this collection is synced with the server
  # sync:child is triggered when a child of this collection is synced with the server
  # add:parent is triggered when a parent is added to this collection
  # remove:parent is triggered when a parent is removed from this collection
  # add:child is triggered when a child is added to this collection
  # remove:child is triggered when a child is removed from this collection

  #### 
  #### NEW COLLETION METHODS
  ####

  # addParent
  # removeParent
  # addChild
  # removeChild
  # urlBase

  #### 
  #### OVER WRITEN COLLECTION METHODS
  ####

  # initalize
  #
  _.extend Backbone.Collection::, Backbone.Events, 

    initialize: () ->

      # Register all new methods 
      _.bindAll @, "all", "addParent", "removeParent", "urlBase"

      #Set a Collection name, make sure this is formated correctly
      @.name || (@.name = "default")
      @.name =  @.name.toCamel().capitalize()
      @.collectionName = @.name

      # Containers for relationships
      @.parents || (@.parents = [])

      # This extends the default Backbone.Model with information
      @._className || (@._className = "Backbone.Collection.#{@.collectionName}")

      @._created = new Date().getTime()

      # Used for debugging the backbone events
      #@.on "all", @.all, @

      @.on "add", (model, collection, options) =>
        model.addParent collection
        @.trigger "add:child", @, model

      @.on "remove", (model, collection, options) =>
        model.removeParent collection
        @.trigger "remove:child", @, model

      @.on "reset sync", (collection, options) =>
        _.each(collection.models, (element, index, list) ->
          # Ensure the child adds the collection as the parent
          element.addParent collection
          element.trigger "sync:parent", element, collection, _.clone(_.result(element, 'url'))
        )

        _.each(collection.parents, (element, index, list) ->
            element.trigger "sync:child", element, collection, _.clone(_.result(element, 'url'))
        )

      # Register the Collection with the ModelManager
      _.extend @, Backbone.Manager.add(@)

    #
    # Method:      addParent
    # Interface:   Public
    # Prototype:   Boolean addParent(Backbone.Model || Backbone.Collection)
    # Return Type: Boolean
    # Description: Adds the given parent as a Parent of this collection. Returns true if it was successfully added, false otherwise.
    # Author:      Joseph J. Viscomi | jjviscomi@gmail.com
    #
    addParent: (parent) ->
      if !_.isUndefined(parent) and _.has(@, 'parents')
        # Checks to see if the current model is already the parent of this collection
        index = _.find(@.parents, (element, index, list) ->
          _.isEqual parent, element
        )

        # Add the modelOrCollection as a parent to this collection
        if _.isUndefined(index) and !_.isNull(parent)
          _.each(@.models, (element, index, list) ->
            _.defer (element, parent) ->
              element.addParent parent 
            , element, parent
          )
          @.parents.push parent
          @.trigger "add:parent", @, parent
          # This allows the nexting collection under the parent to construct a proper URL
          @.url = @.urlBase parent

          if _.isBackboneModel parent
            _.defer (parent, child) ->
              parent.addChild child
            , parent, @
          true 
        else
          false
      else
        false

    #
    # Method:      removeParent
    # Interface:   Public
    # Prototype:   Boolean removeParent(Backbone.Model || Backbone.Collection)
    # Return Type: Boolean
    # Description: Removes the given parent from this Collection. Returns true if it was successfully removed, false otherwise.
    # Author:      Joseph J. Viscomi | jjviscomi@gmail.com
    #
    removeParent: (parent) ->
      if !_.isUndefined(parent) and _.has(@, 'parents')
        index = _.find(@.parents, (element, index, list) ->
          _.isEqual parent, element
        )

        if !_.isUndefined(index) and !_.isNull(parent)
          # Remove it from the array
          @.parents = _.reject(@.parents, (item) ->
            _.isEqual item, parent
          )

          @.trigger "remove:parent", @, parent

          # Trigger the remove event for all of its children
          _.each(@.models, (element, index, list) ->
            #element.trigger "remove:parent", element, parent
            _.defer (element, parent) ->
              element.removeParent parent 
            , element, parent
          )

          if _.isBackboneModel parent 
            _.defer (parent, child) ->
              parent.removeChild child
            , parent, child
          true 
        else
          false
      else
        false

    #
    # Method:      addChild
    # Interface:   Public
    # Prototype:   Boolean addChild(Backbone.Model || Backbone.Collection)
    # Return Type: Boolean
    # Description: Adds the given child as a Child of this Collection. Returns true if it was successfully added, false otherwise.
    # Author:      Joseph J. Viscomi | jjviscomi@gmail.com
    #
    addChild: (child) ->
      @.add child
          
    #
    # Method:      removeChild
    # Interface:   Public
    # Prototype:   Boolean removeChild(Backbone.Model || Backbone.Collection)
    # Return Type: Boolean
    # Description: Removes the given child from this Collection. Returns true if it was successfully removed, false otherwise.
    # Author:      Joseph J. Viscomi | jjviscomi@gmail.com
    #
    removeChild: (child) ->
      @.remove child

    #
    # Method:      urlBase
    # Interface:   Public
    # Prototype:   String urlBase(Backbone.Model)
    # Return Type: String
    # Description: Returns a url based on the specified parent model.
    # Author:      Joseph J. Viscomi | jjviscomi@gmail.com
    #
    urlBase: (model) ->
      if !_.isUndefined(model) and _.isBackboneModel(model)
        url = model.url @
      else
        url = '/' + @['collectionName'].toUnderscore().toLowerCase()
      
      url.toLowerCase()

    all: () -> 
      console.log "Collection:Events", arguments


  # Register the classes with Backbone.Manager #
  Backbone.Manager.registerClass(Backbone.Model, Backbone.Manager.Models)
  Backbone.Manager.registerClass(Backbone.Collection, Backbone.Manager.Collections)
  Backbone.Manager.registerClass(Backbone.Router, Backbone.Manager.Routers)
  Backbone.Manager.registerClass(Backbone.View, Backbone.Manager.Views)

  
)()
