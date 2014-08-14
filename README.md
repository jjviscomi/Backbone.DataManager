Backbone.DataManager
================

Extension to Backbone and Thorax. This class provides a base for object, model, or collection management. Intended to serve as the basis for a application data layer in large web based applications.


Backbone.DataManager API
================

set
```js
DataManager.set(obj, options);
```
obj can be any JSON / JavaScript object. This tell the DataManager to start tracking this obj and keep a refrence to it.
This has 3 possible return values:

1. null   - Meaning it is not managed my the DataManager
2. string - This is a SHA1 has or key that the DataManager uses to track this object with and it can be used to refrence it.
3. object - {key:string, name:string} If you pass an options hash specifing a name `DataManager.set(obj, {name:'myRef'});`. 

If you set a name you can refrence your stored object with either the key or the name you registered.

get
```js
DataManager.get(keyOrName);
```
You can use `get` to recall any saved object in the DataManager using the generated key or a name you set.

remove
```js
DataManager.remove(keyOrName);
```
You can use `remove` to remove all saved refrences to the saved object in the DataManager, it will return the object upon success or null on failure to remove the associated item.

remove
```js
DataManager.flush();
```
You can use `flush` to reset the DataManager to an initial state, it removes all refrences to all objects.

inspector methods: `getKeys()`, `getNames()`, `hasKey(key)`, `hasName(name)`.


Simple Example:
================
```js
// Register a new backbone collection into the DataManager and give it a name of "Users"
Backbone.DataManager.set(new Backbone.Collections.Users(), {name:"Users"});

Backbone.DataManager.get("Users").fetch()
```

