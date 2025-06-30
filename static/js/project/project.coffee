class @Project
  constructor:(@app,data)->
    @id = data.id
    @owner = data.owner
    @accepted = data.accepted
    @slug = data.slug
    @code = data.code
    @title = data.title
    @description = data.description
    @tags = data.tags
    @public = data.public
    @unlisted = data.unlisted
    @platforms = data.platforms
    @controls = data.controls
    @type = data.type
    @orientation = data.orientation
    @graphics = data.graphics or "M1"
    @language = data.language or "microscript_v1_i"
    @libs = data.libs or []
    @aspect = data.aspect
    @users = data.users
    @tabs = data.tabs
    @plugins = data.plugins
    @libraries = data.libraries
    @networking = data.networking
    @properties = data.properties or {}
    @flags = data.flags or {}

    @file_types = ["source","sprite","map","asset","sound","music"]
    for f in @file_types
      @["#{f}_list"] = []
      @["#{f}_table"] = {}
      @["#{f}_folder"] = new ProjectFolder null,f

    @locks = {}
    @lock_time = {}
    @friends = {}

    @url = location.origin+"/#{@owner.nick}/#{@slug}/"
    @listeners = []
    setInterval (()=>@checkLocks()),1000

    @pending_changes = []
    @onbeforeunload = null

  getFullURL:()->
    if @public
      @url
    else
      location.origin+"/#{@owner.nick}/#{@slug}/#{@code}/"

  addListener:(lis)->
    @listeners.push lis

  notifyListeners:(change)->
    for lis in @listeners
      lis.projectUpdate(change)
    return

  load:()->
    @updateSourceList()
    @updateSpriteList()
    @updateMapList()
    @updateSoundList()
    @updateMusicList()
    @updateAssetList()
    @loadDoc()

  loadDoc:()->
    @app.doc_editor.setDoc ""
    @app.readProjectFile @id,"doc/doc.md",(content)=>
      @app.doc_editor.setDoc content

  updateFileList:(folder,callback)->
    @app.client.sendRequest {
      name: "list_project_files"
      project: @app.project.id
      folder: folder
    },(msg)=>
      @[callback] msg.files

  updateSourceList:()-> @updateFileList "ms","setSourceList"
  updateSpriteList:()-> @updateFileList "sprites","setSpriteList"
  updateMapList:()-> @updateFileList "maps","setMapList"
  updateSoundList:()-> @updateFileList "sounds","setSoundList"
  updateMusicList:()-> @updateFileList "music","setMusicList"
  updateAssetList:()-> @updateFileList "assets","setAssetList"

  lockFile:(file)->
    lock = @lock_time[file]
    return if lock? and Date.now()<lock
    @lock_time[file] = Date.now()+2000
    console.info "locking file #{file}"
    @app.client.sendRequest {
      name: "lock_project_file"
      project: @id
      file: file
    },(msg)=>

  fileLocked:(msg)->
    @locks[msg.file] =
      user: msg.user
      time: Date.now()+10000

    @friends[msg.user] = Date.now()+120000

    @notifyListeners("locks")

  isLocked:(file)->
    lock = @locks[file]
    if lock? and Date.now()<lock.time
      lock
    else
      false

  checkLocks:()->
    change = false
    for file,lock of @locks
      if Date.now()>lock.time
        delete @locks[file]
        change = true

    for user,time of @friends
      if Date.now()>time
        delete @friends[user]
        change = true

    @notifyListeners("locks") if change

  changeSpriteName:(old,name)->
    old = old.replace /-/g,"/"
    for map in @map_list
      changed = false
      for i in [0..map.width-1] by 1
        for j in [0..map.height-1] by 1
          s = map.get(i,j)
          if s? and s.length>0
            s = s.split(":")
            if s[0] == old
              changed = true
              if s[1]?
                map.set(i,j,name+":"+s[1])
              else
                map.set(i,j,name)

      if changed
        @app.client.sendRequest {
          name: "write_project_file"
          project: @app.project.id
          file: "maps/#{map.name}.json"
          content: map.save()
        },(msg)=>

    return

  changeMapName:(old,name)->
    @map_table[name] = @map_table[old]
    delete @map_table[old]

  fileUpdated:(msg)->
    if msg.file.indexOf("ms/") == 0
      # Handle both .ms and .js files in the ms/ directory
      if msg.file.indexOf(".ms") > 0
        name = msg.file.substring("ms/".length,msg.file.indexOf(".ms"))
      else if msg.file.indexOf(".js") > 0
        name = msg.file.substring("ms/".length,msg.file.indexOf(".js"))
      else
        name = msg.file.substring("ms/".length)
      
      if @source_table[name]?
        @source_table[name].reload()
      else
        @updateSourceList()
    else if msg.file == "doc/doc.md"
      @app.doc_editor.setDoc msg.content
    else if msg.file.indexOf("sprites/") == 0
      name = msg.file.substring("sprites/".length,msg.file.indexOf(".png"))
      if @sprite_table[name]?
        if msg.properties?
          @sprite_table[name].properties = msg.properties
          if msg.properties.fps?
            @sprite_table[name].fps = msg.properties.fps
        @sprite_table[name].reload ()=>
          if name == @app.sprite_editor.selected_sprite
            @app.sprite_editor.currentSpriteUpdated()
      else
        @updateSpriteList()
    else if msg.file.indexOf("maps/") == 0
      name = msg.file.substring("maps/".length,msg.file.indexOf(".json"))
      if @map_table[name]?
        @map_table[name].loadFile()
      else
        @updateMapList()
    else if msg.file.indexOf("sounds/") == 0
      name = msg.file.substring("sounds/".length,msg.file.length).split(".")[0]
      if not @sound_table[name]?
        @updateSoundList()
    else if msg.file.indexOf("music/") == 0
      name = msg.file.substring("music/".length,msg.file.length).split(".")[0]
      if not @music_table[name]?
        @updateMusicList()
    else if msg.file.indexOf("assets/") == 0
      name = msg.file.substring("assets/".length,msg.file.length).split(".")[0]
      if not @asset_table[name]?
        @updateAssetList()

  fileDeleted:(msg)->
    if msg.file.indexOf("ms/") == 0
      @updateSourceList()
    else if msg.file.indexOf("sprites/") == 0
      @updateSpriteList()
    else if msg.file.indexOf("maps/") == 0
      @updateMapList()
    else if msg.file.indexOf("sounds/") == 0
      @updateSoundList()
    else if msg.file.indexOf("music/") == 0
      @updateMusicList()

  optionsUpdated:(data)->
    @slug = data.slug
    @title = data.title
    @public = data.public
    @platforms = data.platforms
    @controls = data.controls
    @type = data.type
    @orientation = data.orientation
    @aspect = data.aspect

  addSprite:(sprite)->
    s = new ProjectSprite @,sprite.file,null,null,sprite.properties,sprite.size
    @sprite_table[s.name] = s
    @sprite_list.push s
    @sprite_folder.push s
    s

  getSprite:(name)->
    @sprite_table[name]

  createSprite:(width,height,name="sprite")->
    if @getSprite(name)
      count = 2
      loop
        filename = "#{name}#{count++}"
        break if not @getSprite(filename)?
    else
      filename = name

    sprite = new ProjectSprite @,filename+".png",width,height
    @sprite_table[sprite.name] = sprite
    @sprite_list.push sprite
    @sprite_folder.push sprite
    @notifyListeners "spritelist"
    sprite

  importComponentData:(callback)->
    @app.client.sendRequest
      name: "read_component_data"
    , (msg)=>
      if msg.data
        @processComponentData(msg.data)
        callback() if callback?

  processComponentData:(data)->
    if data.entities or data.objects
      @generateComponentCode(data)

  generateComponentCode:(data)->
    # Generate component data file and functions library
    console.info "Starting component code generation..."
    console.info "Data received:", data
    
    # Check project language
    if @language == "javascript"
      console.info "✅ Project language is JavaScript - generating .js files"
      # Generate all three files as .js files
      console.info "Generating component_data.js..."
      @generateComponentDataFile(data)
      
      console.info "Generating functions.js..."
      @generateFunctionsLibrary(data)
      
      console.info "Generating main.js..."
      @generateMainFileTemplate()
    else
      console.warn "⚠️ Project language is '#{@language}' - generating microScript-compatible .ms files"
      # Generate microScript-compatible versions as .ms files
      console.info "Generating component_data.ms..."
      @generateMicroScriptComponentDataFile(data)
      
      console.info "Generating functions.ms..."
      @generateMicroScriptFunctionsLibrary(data)
      
      console.info "Generating main.ms..."
      @generateMicroScriptMainFileTemplate()
    
    # Show success message after a short delay to ensure files are created
    setTimeout ()=>
      if @language == "javascript"
        console.info "✅ JavaScript component system files generated successfully!"
      else
        console.info "✅ microScript component system files generated successfully!"
        console.info "💡 Tip: Change project language to 'JavaScript' in project settings for better JavaScript support"
    , 1000

  generateComponentDataFile:(data)->
    # Generate clean component data in JavaScript for microStudio
    codeLines = []
    codeLines.push "// Component data from db.json"
    codeLines.push "// This object is globally available across all files in microStudio"
    codeLines.push "component_objects = {"

    # Use entities if available, fallback to objects for backwards compatibility
    objectsData = data.entities || data.objects

    if objectsData
      objectEntries = []
      for objectName, objectData of objectsData
        objLines = []
        objLines.push "  #{objectName}: {"
        objLines.push "    shape: \"#{objectData.shape}\","
        objLines.push "    x: #{objectData.position?.x || 0},"
        objLines.push "    y: #{objectData.position?.y || 0},"
        
        if objectData.shape == "rectangle" and objectData.size
          objLines.push "    w: #{objectData.size.width},"
          objLines.push "    h: #{objectData.size.height},"
        else if objectData.shape == "circle" and objectData.radius
          objLines.push "    r: #{objectData.radius},"
        
        if objectData.variableValues?.visual?.color
          objLines.push "    color: \"#{objectData.variableValues.visual.color}\","
        
        if objectData.components and objectData.components.length > 0
          objLines.push "    components: #{JSON.stringify(objectData.components)},"
        
        if objectData.variableValues
          objLines.push "    data: {"
          for component, values of objectData.variableValues
            objLines.push "      #{component}: {"
            for key, value of values
              if typeof value == "string"
                objLines.push "        #{key}: \"#{value}\","
              else
                objLines.push "        #{key}: #{JSON.stringify(value)},"
            objLines.push "      },"
          objLines.push "    },"
        
        objLines.push "  },"
        objectEntries.push objLines.join("\n")
      
      codeLines.push objectEntries.join("\n")
    
    codeLines.push "};"
    
    @insertCodeIntoFile(codeLines.join("\n"), "component_data", "js")

  generateFunctionsLibrary:(data)->
    # Generate functions library in JavaScript for microStudio
    lines = []
    lines.push "// Component Functions Library"
    lines.push "// All functions are globally available across files in microStudio"
    lines.push "drawObject = function(id, customX, customY) {"
    lines.push "  var obj = component_objects[id];"
    lines.push "  if (!obj) {"
    lines.push "    // Debug: Object not found"
    lines.push "    return;"
    lines.push "  }"
    lines.push ""
    lines.push "  var x = customX !== undefined ? customX : obj.x;"
    lines.push "  var y = customY !== undefined ? customY : obj.y;"
    lines.push ""
    lines.push "  // Debug: Log what we're trying to draw"
    lines.push "  // Temporarily commented out to avoid spam: print('Drawing object: ' + id + ' at (' + x + ', ' + y + ')');"
    lines.push ""
    lines.push "  if (obj.color) screen.setColor(obj.color);"
    lines.push ""
    lines.push "  // Try to draw sprite with object ID as sprite name"
    lines.push "  try {"
    lines.push "    screen.drawSprite(id, x, y);"
    lines.push "  } catch (e) {"
    lines.push "    // If sprite doesn't exist, draw a simple rectangle as fallback"
    lines.push "    var w = obj.w || 20;"
    lines.push "    var h = obj.h || 20;"
    lines.push "    var r = obj.r || 10;"
    lines.push "    "
    lines.push "    screen.setColor(obj.color || '#FF0000');"
    lines.push "    "
    lines.push "    if (obj.shape === 'circle') {"
    lines.push "      screen.fillRound(x, y, r, r);"
    lines.push "    } else {"
    lines.push "      screen.fillRect(x, y, w, h);"
    lines.push "    }"
    lines.push "  }"
    lines.push "}"
    lines.push ""
    lines.push "applyPhysics = function(id, dt) {"
    lines.push "  var obj = component_objects[id];"
    lines.push "  if (obj && obj.data && obj.data.physics) {"
    lines.push "    var physics = obj.data.physics;"
    lines.push ""
    lines.push "    if (physics.gravity) obj.y += physics.gravity * dt;"
    lines.push ""
    lines.push "    if (physics.friction && obj.velocity_x !== undefined) {"
    lines.push "      obj.velocity_x *= (1 - physics.friction * dt);"
    lines.push "    }"
    lines.push "  }"
    lines.push "}"
    lines.push ""
    lines.push "applyAllPhysics = function(dt) {"
    lines.push "  var keys = Object.keys(component_objects);"
    lines.push "  for (var i = 0; i < keys.length; i++) {"
    lines.push "    applyPhysics(keys[i], dt);"
    lines.push "  }"
    lines.push "}"
    lines.push ""
    lines.push "getObject = function(id) {"
    lines.push "  return component_objects[id];"
    lines.push "}"
    lines.push ""
    lines.push "getObjectsWithComponent = function(componentName) {"
    lines.push "  var result = [];"
    lines.push "  var keys = Object.keys(component_objects);"
    lines.push "  for (var i = 0; i < keys.length; i++) {"
    lines.push "    var obj = component_objects[keys[i]];"
    lines.push "    if (obj.components && obj.components.indexOf(componentName) >= 0) {"
    lines.push "      result.push(keys[i]);"
    lines.push "    }"
    lines.push "  }"
    lines.push "  return result;"
    lines.push "}"
    lines.push ""
    lines.push "drawAllObjects = function() {"
    lines.push "  var keys = Object.keys(component_objects);"
    lines.push "  for (var i = 0; i < keys.length; i++) {"
    lines.push "    drawObject(keys[i]);"
    lines.push "  }"
    lines.push "}"
    
    @insertCodeIntoFile(lines.join("\n"), "functions", "js")

  generateMicroScriptComponentDataFile:(data)->
    # Generate clean component data in microScript format for microStudio
    codeLines = []
    codeLines.push "// Component data from db.json"
    codeLines.push "// This object is globally available across all files in microStudio"
    codeLines.push "component_objects = object"

    # Use entities if available, fallback to objects for backwards compatibility
    objectsData = data.entities || data.objects
    if objectsData
      for objectName, objectData of objectsData
        codeLines.push "  #{objectName} = object"
        codeLines.push "    shape = \"#{objectData.shape}\""
        codeLines.push "    x = #{objectData.position?.x || 0}"
        codeLines.push "    y = #{objectData.position?.y || 0}"
        
        if objectData.shape == "rectangle" and objectData.size
          codeLines.push "    w = #{objectData.size.width}"
          codeLines.push "    h = #{objectData.size.height}"
        else if objectData.shape == "circle" and objectData.radius
          codeLines.push "    r = #{objectData.radius}"
        
        if objectData.variableValues?.visual?.color
          codeLines.push "    color = \"#{objectData.variableValues.visual.color}\""
        
        if objectData.components and objectData.components.length > 0
          codeLines.push "    components = #{JSON.stringify(objectData.components)}"
        
        if objectData.variableValues
          codeLines.push "    data = object"
          for component, values of objectData.variableValues
            codeLines.push "      #{component} = object"
            for key, value of values
              if typeof value == "string"
                codeLines.push "        #{key} = \"#{value}\""
              else
                codeLines.push "        #{key} = #{JSON.stringify(value)}"
            codeLines.push "      end"
          codeLines.push "    end"
        
        codeLines.push "  end"

    codeLines.push "end"
    @insertCodeIntoFile(codeLines.join("\n"), "component_data", "ms")

  generateMicroScriptFunctionsLibrary:(data)->
    # Generate functions library in microScript for microStudio
    lines = []
    lines.push "// Component Functions Library"
    lines.push "// All functions are globally available across files in microStudio"
    lines.push ""
    lines.push "drawObject = function(id, customX, customY)"
    lines.push "  obj = component_objects[id]"
    lines.push "  if not obj then return end"
    lines.push ""
    lines.push "  x = if customX != null then customX else obj.x end"
    lines.push "  y = if customY != null then customY else obj.y end"
    lines.push ""
    lines.push "  if obj.color then screen.setColor(obj.color) end"
    lines.push ""
    lines.push "  // Use object ID as sprite name"
    lines.push "  screen.drawSprite(id, x, y)"
    lines.push "end"
    lines.push ""
    lines.push "applyPhysics = function(id, dt)"
    lines.push "  obj = component_objects[id]"
    lines.push "  if obj and obj.data and obj.data.physics then"
    lines.push "    physics = obj.data.physics"
    lines.push ""
    lines.push "    if physics.gravity then obj.y += physics.gravity * dt end"
    lines.push ""
    lines.push "    if physics.friction and obj.velocity_x != null then"
    lines.push "      obj.velocity_x *= (1 - physics.friction * dt)"
    lines.push "    end"
    lines.push "  end"
    lines.push "end"
    lines.push ""
    lines.push "applyAllPhysics = function(dt)"
    lines.push "  for id in system.keys(component_objects)"
    lines.push "    applyPhysics(id, dt)"
    lines.push "  end"
    lines.push "end"
    lines.push ""
    lines.push "getObject = function(id)"
    lines.push "  return component_objects[id]"
    lines.push "end"
    lines.push ""
    lines.push "getObjectsWithComponent = function(componentName)"
    lines.push "  result = []"
    lines.push "  for id in system.keys(component_objects)"
    lines.push "    obj = component_objects[id]"
    lines.push "    if obj.components and obj.components.indexOf(componentName) >= 0 then"
    lines.push "      result.push(id)"
    lines.push "    end"
    lines.push "  end"
    lines.push "  return result"
    lines.push "end"
    lines.push ""
    lines.push "drawAllObjects = function()"
    lines.push "  for id in system.keys(component_objects)"
    lines.push "    drawObject(id)"
    lines.push "  end"
    lines.push "end"
    @insertCodeIntoFile(lines.join("\n"), "functions", "ms")
  generateMainFileTemplate:()->
    # Generate a clean main.js template for microStudio
    lines = []
    lines.push "// Main game logic - uses component_objects and functions from other files"
    lines.push "// In microStudio, all files are automatically available globally"
    lines.push ""
    lines.push "init = function() {"
    lines.push "  // Initialization code here"
    lines.push "  // Debug: Check if component system is working"
    lines.push "  if (typeof component_objects !== 'undefined') {"
    lines.push "    // Component system initialized successfully"
    lines.push "  } else {"
    lines.push "    // Component system not found"
    lines.push "  }"
    lines.push "}"
    lines.push ""
    lines.push "update = function() {"
    lines.push "  // Update physics and game logic"
    lines.push "  applyAllPhysics(1/60);  // 60 FPS"
    lines.push "}"
    lines.push ""
    lines.push "draw = function() {"
    lines.push "  screen.clear();"
    lines.push "  "
    lines.push "  // Set white color for drawing"
    lines.push "  screen.setColor('#FFFFFF');"
    lines.push "  "
    lines.push "  // Draw all objects"
    lines.push "  drawAllObjects();"
    lines.push "  "
    lines.push "  // Or draw specific objects:"
    lines.push "  // drawObject('rect1');"
    lines.push "  // drawObject('circle1', 150, 200);  // custom position"
    lines.push "}"
    @insertCodeIntoFile(lines.join("\n"), "main", "js")

  addSource:(file)->
    s = new ProjectSource @,file.file,file.size
    @source_table[s.name] = s
    @source_list.push s
    @source_folder.push s
    s

  getSource:(name)->
    @source_table[name]

  createSource:(basename="source", fileType="ms")->
    count = 2
    filename = basename
    while @getSource(filename)?
      filename = "#{basename}#{count++}"

    fileExtension = if fileType == "js" then "js" else "ms"
    source = new ProjectSource @,filename+".#{fileExtension}"
    source.fetched = true
    @source_table[source.name] = source
    @source_list.push source
    @source_folder.push source
    @notifyListeners "sourcelist"
    source

  getFullSource:()->
    res = ""
    for s in @source_list
      res += s+"\n"
    res

  setFileList:(list,target_list,target_table,get,add,item_id)->
    notification = item_id+"list"
    li = []

    for f in list
      li.push f.file

    folder = @[item_id+"_folder"]
    folder.removeNoMatch(li)
    #@[item_id+"_folder"] = new ProjectFolder(null,item_id)

    for i in [target_list.length-1..0] by -1
      s = target_list[i]
      if li.indexOf(s.filename)<0
        target_list.splice i,1
        delete target_table[s.name]

    for s in list
      if not @[get] s.file.split(".")[0]
        @[add] s

    folder.removeEmptyFolders()
    folder.sort()

    @notifyListeners notification

  setSourceList: (list) => @setFileList list,@source_list,@source_table,"getSource","addSource","source"
  setSpriteList: (list) => @setFileList list,@sprite_list,@sprite_table,"getSprite","addSprite","sprite"
  setMapList: (list) => @setFileList list,@map_list,@map_table,"getMap","addMap","map"
  setSoundList: (list) => @setFileList list,@sound_list,@sound_table,"getSound","addSound","sound"
  setMusicList: (list) => @setFileList list,@music_list,@music_table,"getMusic","addMusic","music"
  setAssetList: (list) => @setFileList list,@asset_list,@asset_table,"getAsset","addAsset","asset"

  addMap:(file)->
    m = new ProjectMap @,file.file,file.size
    @map_table[m.name] = m
    @map_list.push m
    @map_folder.push m
    m

  getMap:(name)->
    @map_table[name]

  addAsset:(file)->
    m = new ProjectAsset @,file.file,file.size
    @asset_table[m.name] = m
    @asset_list.push m
    @asset_folder.push m
    m

  getAsset:(name)->
    @asset_table[name]

  createMap:(basename="map")->
    name = basename
    count = 2
    while @getMap(name)
      name = "#{basename}#{count++}"

    m = @addMap
          file: name+".json"
          size: 0

    @notifyListeners "maplist"
    m

  createSound:(name="sound",thumbnail,size)->
    if @getSound(name)
      count = 2
      loop
        filename = "#{name}#{count++}"
        break if not @getSound(filename)?
    else
      filename = name

    sound = new ProjectSound @,filename+".wav",size
    if thumbnail then sound.thumbnail_url = thumbnail
    @sound_table[sound.name] = sound
    @sound_list.push sound
    @sound_folder.push sound
    @notifyListeners "soundlist"
    sound

  addSound:(file)->
    m = new ProjectSound @,file.file,file.size
    @sound_table[m.name] = m
    @sound_list.push m
    @sound_folder.push m
    m

  getSound:(name)->
    @sound_table[name]

  createMusic:(name="music",thumbnail,size)->
    if @getMusic(name)
      count = 2
      loop
        filename = "#{name}#{count++}"
        break if not @getMusic(filename)?
    else
      filename = name

    music = new ProjectMusic @,filename+".mp3",size
    if thumbnail then music.thumbnail_url = thumbnail
    @music_table[music.name] = music
    @music_list.push music
    @music_folder.push music
    @notifyListeners "musiclist"
    music

  addMusic:(file)->
    m = new ProjectMusic @,file.file,file.size
    @music_table[m.name] = m
    @music_list.push m
    @music_folder.push m
    m

  getMusic:(name)->
    @music_table[name]


  createAsset:(name="asset",thumbnail,size,ext)->
    if @getAsset(name)
      count = 2
      loop
        filename = "#{name}#{count++}"
        break if not @getAsset(filename)?
    else
      filename = name

    asset = new ProjectAsset @,filename+".#{ext}",size
    if thumbnail then asset.thumbnail_url = thumbnail
    @asset_table[asset.name] = asset
    @asset_list.push asset
    @asset_folder.push asset
    @notifyListeners "assetlist"
    asset

  setTitle:(@title)->
    @notifyListeners "title"

  setSlug:(@slug)->
    @notifyListeners "slug"

  setCode:(@code)->
    @notifyListeners "code"

  setType:(@type)->

  setOrientation:(@orientation)->
    #window.dispatchEvent(new Event('resize'))

  setAspect:(@aspect)->
    #window.dispatchEvent(new Event('resize'))

  setGraphics:(@graphics)->
    #window.dispatchEvent(new Event('resize'))

  setLanguage:(@language)->
    #window.dispatchEvent(new Event('resize'))

  addPendingChange:(item)->
    if @pending_changes.indexOf(item)<0
      @pending_changes.push item
    if not @onbeforeunload?
      @onbeforeunload = (event)=>
        event.preventDefault()
        event.returnValue = "You have pending unsaved changed."
        @savePendingChanges()
        return event.returnValue

      window.addEventListener "beforeunload",@onbeforeunload

  removePendingChange:(item)->
    index = @pending_changes.indexOf(item)
    if index>=0
      @pending_changes.splice index,1
    if @pending_changes.length == 0
      if @onbeforeunload?
        window.removeEventListener "beforeunload",@onbeforeunload
        @onbeforeunload = null

  savePendingChanges:(callback)->
    if @pending_changes.length>0
      save = @pending_changes.splice(0,1)[0]
      save.forceSave ()=>
        @savePendingChanges(callback)
    else
      callback() if callback?

  getSize:()->
    size = 0

    for type in @file_types
      t = @["#{type}_list"]
      for s in t
        size += s.size

    size

  writeFile:(name,content,options)->
    name = name.split("/")
    folder = name[0]
    for i in [0..name.length-1]
      name[i] = RegexLib.fixFilename name[i]
    name = name.slice(1).join("-")

    switch folder
      when "ms"
        @writeSourceFile name,content

      when "sprites"
        @writeSpriteFile name,content,options.frames,options.fps

      when "maps"
        @writeMapFile name,content

      when "sounds"
        @writeSoundFile name,content

      when "music"
        @writeMusicFile name,content

      when "assets"
        @writeAssetFile name,content,options.ext

  writeSourceFile:(name,content)->
    @app.client.sendRequest {
      name: "write_project_file"
      project: @id
      file: "ms/#{name}.ms"
      content: content
    },(msg)=>
      @updateSourceList()

  writeSoundFile:(name,content)->
    base64ToArrayBuffer = (base64)->
      binary_string = window.atob(base64)
      len = binary_string.length
      bytes = new Uint8Array(len)
      for i in [0..len-1] by 1
        bytes[i] = binary_string.charCodeAt(i)
      bytes.buffer

    audioContext = new AudioContext()
    audioContext.decodeAudioData base64ToArrayBuffer(content),(decoded)=>
      console.info decoded
      thumbnailer = new SoundThumbnailer(decoded,96,64)

      @app.client.sendRequest {
        name: "write_project_file"
        project: @id
        file: "sounds/#{name}.wav"
        properties: {}
        content: content
        thumbnail: thumbnailer.canvas.toDataURL().split(",")[1]
      },(msg)=>
        console.info msg
        @updateSoundList()

  writeMusicFile:(name,content)->
    base64ToArrayBuffer = (base64)->
      binary_string = window.atob(base64)
      len = binary_string.length
      bytes = new Uint8Array(len)
      for i in [0..len-1] by 1
        bytes[i] = binary_string.charCodeAt(i)
      bytes.buffer

    audioContext = new AudioContext()
    audioContext.decodeAudioData base64ToArrayBuffer(content),(decoded)=>
      console.info decoded
      thumbnailer = new SoundThumbnailer(decoded,192,64,"hsl(200,80%,60%)")

      @app.client.sendRequest {
        name: "write_project_file"
        project: @id
        file: "music/#{name}.mp3"
        properties: {}
        content: content
        thumbnail: thumbnailer.canvas.toDataURL().split(",")[1]
      },(msg)=>
        console.info msg
        @updateMusicList()

  writeSpriteFile:(name,content,frames,fps)->
    @app.client.sendRequest {
      name: "write_project_file"
      project: @id
      file: "sprites/#{name}.png"
      properties: { frames: frames , fps: fps }
      content: content
    },(msg)=>
      @fileUpdated
        file: "sprites/#{name}.png"
        properties:
          frames: frames
          fps: fps
      # @updateSpriteList()

  writeMapFile:(name,content)->
    @app.client.sendRequest {
      name: "write_project_file"
      project: @id
      file: "maps/#{name}.json"
      content: content
    },(msg)=>
      @fileUpdated
        file: "maps/#{name}.json"

      @updateMapList()

  writeAssetFile:(name,content,ext)->
    if ext == "json"
      content = JSON.stringify content

    thumbnail = undefined

    if ext in ["txt","csv","json","obj"]
      thumbnail = @app.assets_manager.text_viewer.createThumbnail content,ext
      thumbnail = thumbnail.toDataURL().split(",")[1]

    if ext == "obj"
      content = btoa content

    send = ()=>
      @app.client.sendRequest {
        name: "write_project_file"
        project: @id
        file: "assets/#{name}.#{ext}"
        content: content
        thumbnail: thumbnail
      },(msg)=>
        @updateAssetList()

    if ext in ["png","jpg"]
      @app.assets_manager.image_viewer.createThumbnail content,(canvas)=>
        thumbnail = canvas.toDataURL().split(",")[1]
        content = content.split(",")[1]
        send()
      return

    send()

  insertCodeIntoFile:(code, filename, fileType = "ms")->
    # Create or overwrite the file directly on the server
    fileExtension = if fileType == "js" then "js" else "ms"
    
    # Save the file directly to the server
    @app.client.sendRequest {
      name: "write_project_file"
      project: @id
      file: "ms/#{filename}.#{fileExtension}"
      content: code
    }, (msg)=>
      console.info "Created file: #{filename}.#{fileExtension}"
      
      # Manually trigger file updated to ensure proper handling
      @fileUpdated
        file: "ms/#{filename}.#{fileExtension}"
        content: code
      
      # If this is the main file, switch to it in the editor
      if filename == "main"
        setTimeout ()=>
          # Find and select the new file
          source = @getSource(filename)
          if source and @app.editor
            @app.editor.setSelectedItem(source.name)
        , 500
