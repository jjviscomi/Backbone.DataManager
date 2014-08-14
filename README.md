Backbone.DataManager
================

Extension to Backbone and Thorax. This class provides a base for object, model, or collection management. Intended to serve as the basis for a application data layer in large web based applications.


Look at the source for basic documentation, this is in active development.

Simple Example:
================
```js
// Register a new backbone collection into the DataManager and give it a name of "Users"
Backbone.DataManager.set(new Backbone.Collections.Users(), {name:"Users"});

Backbone.DataManager.get("Users").fetch()
```

