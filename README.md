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

Backbone.DataManager.get("Users").fetch();
```

Background Auto Refreshing:
============================

Some work needs to be acomplished on your server side to properly impliment this the way it was intended. The thought is that repeaded request for collections or records from a database should be coming from a stored cache that responds much faster than a relational database, for example redis.

While we do not provide the code base to impliment this functionality in your application it is trival and we will discuss in part some of the logic.

We assume all server cache requests will be made to the following url with a GET request: /cache/:id where :id is a SHA1 hash that uniquely represents the request, therfor if multipule requests for the same recordset are made from different clients they would fetch the same stored redis object refrenced by the SHA1 key. This will maximize response time and reduce load on your database.

To enable auto cache fetching you simply need to include a refresh option and set it to some numeric value which indicates an offset from a clock tick in milliseconds to preform the refresh.

```js
// Register a new backbone collection into the DataManager and give it a name of "Users" with an refresh option
Backbone.DataManager.set(new Backbone.Collections.Users(), {name:"Users", refresh:5000});

Backbone.DataManager.get("Users").fetch();
```

Some things to note about this:
1. Clock Ticks occur approximatly every 61 seconds, so the shortest time between refreshes will be 61 seconds.
2. Time between requests will grow, making them less frequent. Until the know cache expire time is reached. Thie time is communicated to the framework through a config option called `timeout` which indicates in how many seconds the server will remove the cache object if no request is made, the default time is 300 seconds (5 min).
3. When updates are done to your collection it will fire the appropriate events, your collection is updated using the set mthod.

4. Toggeling on/off autorefresh

```js
// Register a new backbone collection into the DataManager and give it a name of "Users" with an refresh option
Backbone.DataManager.set(new Backbone.Collections.Users(), {name:"Users", refresh:5000});

Backbone.DataManager.get("Users").fetch();

Backbone.DataManager.toggleAutoRefresh("Users"); //Backbone.DataManager.enableAutoRefresh("Users"); //Backbone.DataManager.disableAutoRefresh("Users");
```

5. Passing query params to your controllers you need to include the data object that you intend to use for your fetch so that information is included when compiling the hash, this will eventually be abstracted out.

```js
// Register a new backbone collection into the DataManager and give it a name of "Users" with an refresh option
Backbone.DataManager.set(new Backbone.Collections.Users(), {
  name:"Users", 
  refresh:5000,
  data: {
    from:"2014-07-01",
    to:"2014-07-31"
  }
});

Backbone.DataManager.get("Users").fetch({
  data: {
    from:"2014-07-01",
    to:"2014-07-31"
  }
});
```
6. Computing the hash key is trivial, simply SHA1(url) for example: `http://localhost:5100/users` -> `e6ef7307a2fd72eff84c626a8699010841f0e61d` So the refresh requests will be made to: `http://localhost:5100/cache/e6ef7307a2fd72eff84c626a8699010841f0e61d` or with a data object you would hash `http://localhost:5100/users?from:2014-07-01&to:2014-07-31` This way the server never needs to tell the client what the key is for the cached data set.

7. In our configurations we use background jobs to refresh the cache object on a timed interval or record collection update, so if another user makes an update to the same dataset other clients will be given the updated data on the following refresh.
