# String helper methods
String::toUnderscore = ->
  str = @.replace(/([A-Z])/g, (str)->
    "_" + str.toLowerCase()
  )
  str = str.slice(1)  while str.charAt(0) is "_"
  str
String::toCamel = ->
  @.replace(/([ \-_][a-z])/g, (str)->
    str.toUpperCase().replace '_',''
  )
String::trim = -> 
  @.replace /^\s+|\s+$/g, ""

String::capitalize = ->
  @.charAt(0).toUpperCase() + @.slice(1)

String::titleize = ->
  tmp = @.replace /[ \-_]/g, ' '
  tmp = tmp.replace /,/g, ', '
  words = tmp.match /\w+/g
  
  (word.capitalize() for word in words).join ' '
  
