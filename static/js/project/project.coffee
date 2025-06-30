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
    
    # Check project language and warn if needed
    if @language != "javascript"
      console.warn "⚠️ Project language is set to '#{@language}'. For JavaScript files, consider changing project language to 'javascript' in project settings."
    
    # Generate all three files
    console.info "Generating component_data.js..."
    @generateComponentDataFile(data)
    
    console.info "Generating functions.js..."
    @generateFunctionsLibrary(data)
    
    console.info "Generating main.js..."
    @generateMainFileTemplate()
    
    # Show success message after a short delay to ensure files are created
    setTimeout ()=>
      console.info "Component system files generated successfully!"
      if @language != "javascript"
        console.info "💡 Tip: Change project language to 'JavaScript' in project settings for better syntax highlighting"
    , 1000

  generateComponentDataFile:(data)->
    # Generate clean component data in JavaScript for microStudio
    codeLines = []
    codeLines.push "// Component data from db.json"
    codeLines.push "// This object is globally available across all files in microStudio"
    codeLines.push "const component_objects = {"
    
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
    lines.push ""
    
    # Core drawing functions
    lines.push "function drawObject(id, customX, customY) {"
    lines.push "  if (component_objects[id]) {"
    lines.push "    const obj = component_objects[id];"
    lines.push "    const x = customX !== undefined ? customX : obj.x;"
    lines.push "    const y = customY !== undefined ? customY : obj.y;"
    lines.push "    "
    lines.push "    if (obj.color) screen.setDrawColor(obj.color);"
    lines.push "    "
    lines.push "    if (obj.shape === 'rectangle') {"
    lines.push "      screen.fillRect(x, y, obj.w, obj.h);"
    lines.push "    } else if (obj.shape === 'circle') {"
    lines.push "      screen.fillRound(x, y, obj.r * 2, obj.r * 2);"
    lines.push "    }"
    lines.push "  }"
    lines.push "}"
    lines.push ""
    
    # Component system functions
    lines.push "function applyPhysics(id, dt) {"
    lines.push "  if (component_objects[id] && component_objects[id].data && component_objects[id].data.physics) {"
    lines.push "    const obj = component_objects[id];"
    lines.push "    const physics = obj.data.physics;"
    lines.push "    "
    lines.push "    // Apply gravity"
    lines.push "    if (physics.gravity) obj.y += physics.gravity * dt;"
    lines.push "    "
    lines.push "    // Apply friction (simple implementation)"
    lines.push "    if (physics.friction && obj.velocity_x) {"
    lines.push "      obj.velocity_x *= (1 - physics.friction * dt);"
    lines.push "    }"
    lines.push "  }"
    lines.push "}"
    lines.push ""
    
    lines.push "function applyAllPhysics(dt) {"
    lines.push "  for (const id of Object.keys(component_objects)) {"
    lines.push "    applyPhysics(id, dt);"
    lines.push "  }"
    lines.push "}"
    lines.push ""
    
    # Utility functions
    lines.push "function getObject(id) {"
    lines.push "  return component_objects[id];"
    lines.push "}"
    lines.push ""
    
    lines.push "function getObjectsWithComponent(componentName) {"
    lines.push "  const result = [];"
    lines.push "  for (const id of Object.keys(component_objects)) {"
    lines.push "    const obj = component_objects[id];"
    lines.push "    if (obj.components && obj.components.indexOf(componentName) >= 0) {"
    lines.push "      result.push(id);"
    lines.push "    }"
    lines.push "  }"
    lines.push "  return result;"
    lines.push "}"
    lines.push ""
    
    lines.push "function drawAllObjects() {"
    lines.push "  for (const id of Object.keys(component_objects)) {"
    lines.push "    drawObject(id);"
    lines.push "  }"
    lines.push "}"
    lines.push ""
    
    # Example usage
    lines.push "/* Example usage in main.js:"
    lines.push "function init() {"
    lines.push "  // Setup complete - component_objects and all functions are available"
    lines.push "}"
    lines.push ""
    lines.push "function update() {"
    lines.push "  applyAllPhysics(1/60);  // 60 FPS"
    lines.push "}"
    lines.push ""
    lines.push "function draw() {"
    lines.push "  screen.clear();"
    lines.push "  drawAllObjects();"
    lines.push "}"
    lines.push "*/"
    
    @insertCodeIntoFile(lines.join("\n"), "functions", "js")

  generateMainFileTemplate:->
    # Generate a clean main.js template for microStudio
    lines = []
    lines.push "// Main game logic - uses component_objects and functions from other files"
    lines.push "// In microStudio, all files are automatically available globally"
    lines.push ""
    lines.push "function init() {"
    lines.push "  // Initialization code here"
    lines.push "  console.log('Component system initialized with', Object.keys(component_objects).length, 'objects');"
    lines.push "}"
    lines.push ""
    lines.push "function update() {"
    lines.push "  // Update physics and game logic"
    lines.push "  applyAllPhysics(1/60);  // 60 FPS"
    lines.push "}"
    lines.push ""
    lines.push "function draw() {"
    lines.push "  screen.clear();"
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
