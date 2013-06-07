Backbone-Manager
================

Extension to Backbone, adds model and collection tracking, model recycling, and parent child tracking. Generates correct RESTful style routes for parent/child relationships, and designed with Rails in mind. This is in early development and has a long way to go! For more information checkout the source it is well documented.

#Installation
 * Just make sure to include this file after Underscore and Backbone ... thats it.

#Backbone.Manager

This is injected into the Backbone Object and can be inspected in the console with `Backbone.Manager`.

1. Under the manager you will see objects: Models, Collections, Routers, Views. These Class types when being extended should be defined with a name attribute, they will automatically be collected under the appropriate name space under the manager.
2. When you instanciate models or collections the Manager will track them allowing duplicate models elsewhere in your application to be "recycled" which eliminates duplicated unsynced models. The Manager will allocate and track all models and collections accross your entire application independently of any specific view.
3. You do not need to do anything in your code. The Manager in NOT invasive meaning you can include it with NO modification to your code, unless you do NOT want to defaultly use the recycle property.
4. Allows you to track child/parent relationships between models and collections. Helps construct RESTful URLs with these relationships. For example: `Application.Roles.addParent(Application.CurrentUser);` When a save event occures it will construct URLs like /user/1/role/3.

#Backbone.Model
NEW MODEL PROPERTIES

  * name: This should be the server side and client side name of the model. This does expect some level of convention here.
  * parents: This is an array that contains refrences to all the "parents" of this model, most of the time you do not want to access this array directly.
  * children: This is an array that contains the refrences to all the "children" of this model, most of the time you do not want to access this array directly.
  * recycle: This property defaults to true, it indicates to reuse models if one already exists. The newest info will be merged with existing models. This will help keep all client views in sync with the same data.
  * timeToDestroy: This is the number of seconds to wait before auto destroying an unused client side model, setting it to 0 disables auto destroy. Its default is 5.


NEW MODEL EVENTS

  * register:model is triggered when the model is registered with the ModelManager
  * duplicate:model is triggered when another model with the same id has been located in the ModelManager
  * destruct:model is triggered when a model is auto destroyed
  * sync:parent is triggered when the parent of this model is synced with the server
  * sync:child is triggered when a child of this model is synced with the server
  * add:parent is triggered when a parent is added to this model
  * remove:parent is triggered when a parent is removed from this child
  * add:child is triggered when a child is added to this model
  * remove:child is triggered when a child is removed from this parent


NEW MODEL METHODS

  * addParent
  * removeParent
  * addChild
  * removeChild


OVER WRITEN MODEL METHODS

  * toJSON
  * url
  * initalize
  

#Backbone.Collection

NEW COLLECTION PROPERTIES

  * name: This should be the server side (Table) and client side name of the Collection (usually the model name in the plural). This does expect some level of convention here.
  * parents: This is an array that contains refrences to all the "parents" of this collection, most of the time you do not want to access this array directly.

 
NEW COLLECTION EVENTS

  * register:collection is triggered when the collection is registered with the ModelManager
  * duplicate:collection is triggered when another model with the same id has been located in the ModelManager
  * sync:parent is triggered when the parent of this collection is synced with the server
  * sync:child is triggered when a child of this collection is synced with the server
  * add:parent is triggered when a parent is added to this collection
  * remove:parent is triggered when a parent is removed from this collection
  * add:child is triggered when a child is added to this collection
  * remove:child is triggered when a child is removed from this collection


NEW COLLETION METHODS

  * addParent
  * removeParent
  * addChild
  * removeChild
  * urlBase


OVER WRITEN COLLECTION METHODS

  * initalize
