class @SpriteEditor extends Manager
  constructor:(app)->
    super app

    @folder = "sprites"
    @item = "sprite"
    @list_change_event = "spritelist"
    @get_item = "getSprite"
    @use_thumbnails = false
    @extensions = ["png","jpg","jpeg"]
    @update_list = "updateSpriteList"

    @init()
    @splitbar.auto = 1

    @spriteview = new SpriteView @

    @auto_palette = new AutoPalette @
    @colorpicker = new ColorPicker @
    document.getElementById("colorpicker").appendChild @colorpicker.canvas

    @animation_panel = new AnimationPanel @

    @save_delay = 1000
    @save_time = 0
    setInterval (()=>@checkSave()),@save_delay/2

    document.getElementById("sprite-width").addEventListener "input",(event)=>@spriteDimensionChanged("width")
    document.getElementById("sprite-height").addEventListener "input",(event)=>@spriteDimensionChanged("height")
    document.getElementById("colortext").addEventListener "input",(event)=>@colortextChanged()
    document.getElementById("colortext-copy").addEventListener "click",(event)=>@colortextCopy()
    document.getElementById("import-component-data-button").addEventListener "click",(event)=>@importComponentData()

    @sprite_size_validator = new InputValidator [document.getElementById("sprite-width"),document.getElementById("sprite-height")],
      document.getElementById("sprite-size-button"),
      null,
      (value)=>
        @saveDimensionChange(value)

    @selected_sprite = null

    @app.appui.setAction "undo-sprite",()=>@undo()
    @app.appui.setAction "redo-sprite",()=>@redo()
    @app.appui.setAction "copy-sprite",()=>@copy()
    @app.appui.setAction "cut-sprite",()=>@cut()
    @app.appui.setAction "paste-sprite",()=>@paste()

    @app.appui.setAction "sprite-helper-tile",()=>@toggleTile()
    @app.appui.setAction "sprite-helper-vsymmetry",()=>@toggleVSymmetry()
    @app.appui.setAction "sprite-helper-hsymmetry",()=>@toggleHSymmetry()

    @app.appui.setAction "selection-operation-film",()=>@stripToAnimation()
    @app.appui.setAction "selection-action-horizontal-flip",()=>@flipHSprite()
    @app.appui.setAction "selection-action-vertical-flip",()=>@flipVSprite()
    @app.appui.setAction "selection-action-rotate-left",()=>@rotateSprite(-1)
    @app.appui.setAction "selection-action-rotate-right",()=>@rotateSprite(1)

    document.addEventListener "keydown",(event)=>
      return if not document.getElementById("spriteeditor").offsetParent?
      #console.info event
      return if document.activeElement? and document.activeElement.tagName.toLowerCase() == "input"

      if event.key == "Alt" and not @tool.selectiontool
        @setColorPicker(true)
        @alt_pressed = true

      if event.metaKey or event.ctrlKey
        switch event.key
          when "z" then @undo()
          when "Z" then @redo()
          when "c" then @copy()
          when "x" then @cut()
          when "v" then @paste()
          else return

        event.preventDefault()
        event.stopPropagation()

      #console.info event

    document.addEventListener "keyup",(event)=>
      if event.key == "Alt" and not @tool.selectiontool
        @setColorPicker(false)
        @alt_pressed = false

    document.getElementById("eyedropper").addEventListener "click",()=>
      @setColorPicker not @spriteview.colorpicker

    for tool,i in DrawTool.tools
      @createToolButton tool
      @createToolOptions tool
    @setSelectedTool DrawTool.tools[0].icon

    document.getElementById("spritelist").addEventListener "dragover",(event)=>
      event.preventDefault()
      #console.info event

    @code_tip = new CodeSnippetField(@app,"#sprite-code-tip")

    @background_color_picker = new BackgroundColorPicker this,((color)=>
      @spriteview.updateBackgroundColor()
      document.getElementById("sprite-background-color").style.background = color),"sprite"

    document.getElementById("sprite-background-color").addEventListener "mousedown",(event)=>
      if @background_color_picker.shown
        @background_color_picker.hide()
      else
        @background_color_picker.show()
        event.stopPropagation()

  createToolButton:(tool)->
    parent = document.getElementById("spritetools")

    div = document.createElement "div"
    div.classList.add "spritetoolbutton"
    div.title = tool.name

    div.innerHTML = "<i class='fa #{tool.icon}'></i><br />#{@app.translator.get(tool.name)}"
    div.addEventListener "click",()=>
      @setSelectedTool(tool.icon)

    div.id = "spritetoolbutton-#{tool.icon}"

    parent.appendChild div

  createToolOptions:(tool)->
    parent = document.getElementById("spritetooloptionslist")

    div = document.createElement "div"

    for key,p of tool.parameters
      if p.type == "range"
        do (p,key)=>
          label = document.createElement "label"
          label.innerText = key
          div.appendChild label
          input = document.createElement "input"
          input.type = "range"
          input.min = "0"
          input.max = "100"
          input.value = p.value
          input.addEventListener "input",(event)=>
            p.value = input.value
            if key == "Size"
              @spriteview.showBrushSize()
          div.appendChild input
      else if p.type == "size_shape"
        do (p,key)=>
          label = document.createElement "label"
          label.innerText = key
          div.appendChild label
          div.appendChild document.createElement "br"
          input = document.createElement "input"
          input.style = "width:70% ; vertical-align: top"
          input.type = "range"
          input.min = "0"
          input.max = "100"
          input.value = p.value
          input.addEventListener "input",(event)=>
            p.value = input.value
            if key == "Size"
              @spriteview.showBrushSize()
          div.appendChild input
          shape = document.createElement "i"
          shape.style = "verticla-align: top ; padding: 6px 8px ; background: hsl(200,50%,50%) ; border-radius: 4px ;margin-left: 5px ; cursor: pointer ; width: 15px"
          shape.classList.add "fas"
          shape.classList.add "fa-circle"
          shape.title = @app.translator.get "Shape"
          tool.shape = "round"
          shape.addEventListener "click",()=>
            if tool.shape == "round"
              tool.shape = "square"
              shape.classList.remove "fa-circle"
              shape.classList.add "fa-square-full"
            else
              tool.shape = "round"
              shape.classList.add "fa-circle"
              shape.classList.remove "fa-square-full"
            @spriteview.showBrushSize()

          div.appendChild shape
          div.appendChild document.createElement "br"
      else if p.type == "tool"
        toolbox = document.createElement "div"
        toolbox.classList.add "toolbox"
        div.appendChild toolbox

        for t,k in p.set
          button = document.createElement "div"
          button.classList.add "spritetoolbutton"
          if k==0
            button.classList.add "selected"
          button.title = t.name
          button.id = "spritetoolbutton-#{t.icon}"
          i = document.createElement "i"
          i.classList.add "fa"
          i.classList.add t.icon
          button.appendChild i
          button.appendChild document.createElement "br"
          button.appendChild document.createTextNode t.name
          toolbox.appendChild button
          t.button = button

          do (p,k)=>
            button.addEventListener "click",()=>
              p.value = k
              for t,i in p.set
                if i == k
                  t.button.classList.add "selected"
                else
                  t.button.classList.remove "selected"

    div.id = "spritetooloptions-#{tool.icon}"
    parent.appendChild div

  setSelectedTool:(id)->
    for tool in DrawTool.tools
      e = document.getElementById "spritetoolbutton-#{tool.icon}"
      if tool.icon == id
        @tool = tool
        e.classList.add "selected"
      else
        e.classList.remove "selected"

      e = document.getElementById "spritetooloptions-#{tool.icon}"
      if tool.icon == id
        e.style.display = "block"
      else
        e.style.display = "none"

    document.getElementById("colorpicker-group").style.display = if @tool.parameters["Color"]? then "block" else "none"
    @spriteview.update()
    @updateSelectionHints()

  toggleTile:()->
    @spriteview.tile = not @spriteview.tile
    @spriteview.update()
    if @spriteview.tile
      document.getElementById("sprite-helper-tile").classList.add "selected"
    else
      document.getElementById("sprite-helper-tile").classList.remove "selected"

  toggleVSymmetry:()->
    @spriteview.vsymmetry = not @spriteview.vsymmetry
    @spriteview.update()
    if @spriteview.vsymmetry
      document.getElementById("sprite-helper-vsymmetry").classList.add "selected"
    else
      document.getElementById("sprite-helper-vsymmetry").classList.remove "selected"

  toggleHSymmetry:()->
    @spriteview.hsymmetry = not @spriteview.hsymmetry
    @spriteview.update()
    if @spriteview.hsymmetry
      document.getElementById("sprite-helper-hsymmetry").classList.add "selected"
    else
      document.getElementById("sprite-helper-hsymmetry").classList.remove "selected"

  spriteChanged:()->
    return if @ignore_changes
    @app.project.lockFile("sprites/#{@selected_sprite}.png")
    @save_time = Date.now()
    s = @app.project.getSprite @selected_sprite
    s.updated(@spriteview.sprite.saveData()) if s?
    # s.loaded() # triggers update of all maps
    @app.project.addPendingChange @
    @animation_panel.frameUpdated()
    @auto_palette.update()
    @app.project.notifyListeners s
    @app.runwindow.updateSprite @selected_sprite
    #@updateLocalSprites()

  checkSave:(immediate=false,callback)->
    if @save_time>0 and (immediate or Date.now()>@save_time+@save_delay)
      @saveSprite(callback)
      @save_time = 0
    else
      callback() if callback?

  forceSave:(callback)->
    @checkSave(true,callback)

  projectOpened:()->
    super()
    @app.project.addListener @
    @setSelectedSprite null

  projectUpdate:(change)->
    super(change)

    switch change
      when "locks"
        @updateCurrentFileLock()
        @updateActiveUsers()

    if change instanceof ProjectSprite
      name = change.name
      c = document.querySelector "#sprite-image-#{name}"
      sprite = change
      if c? and c.updateSprite?
        c.updateSprite()

  updateCurrentFileLock:()->
    if @selected_sprite?
      @spriteview.editable = not @app.project.isLocked("sprites/#{@selected_sprite}.png")

    lock = document.getElementById("sprite-editor-locked")
    if @selected_sprite? and @app.project.isLocked("sprites/#{@selected_sprite}.png")
      user = @app.project.isLocked("sprites/#{@selected_sprite}.png").user
      lock.style = "display: block; background: #{@app.appui.createFriendColor(user)}"
      lock.innerHTML = "<i class='fa fa-user'></i> Locked by #{user}"
    else
      lock.style = "display: none"

  saveSprite:(callback)->
    return if not @selected_sprite? or not @spriteview.sprite
    data = @spriteview.sprite.saveData().split(",")[1]
    sprite = @spriteview.sprite
    saved = false
    pixels = @spriteview.pixels_drawn
    @spriteview.pixels_drawn = 0

    @app.client.sendRequest {
      name: "write_project_file"
      project: @app.project.id
      file: "sprites/#{@selected_sprite}.png"
      pixels: pixels
      properties:
        frames: @spriteview.sprite.frames.length
        fps: @spriteview.sprite.fps
      content: data
    },(msg)=>
      saved = true
      @app.project.removePendingChange(@) if @save_time == 0
      sprite.size = msg.size
      callback() if callback?

    setTimeout (()=>
      if not saved
       @save_time = Date.now()
       console.info("retrying sprite save...")
      ),10000



  createAsset:(folder,name="sprite",content="")->
    @checkSave true,()=>
      if folder?
        name = folder.getFullDashPath()+"-#{name}"
        folder.setOpen true

      @createSprite name,null

  importComponentData:()->
    if @app.project
      @app.project.importComponentData ()=>
        @app.appui.showNotification("Creating microStudio JavaScript files...")
        
        # Show success message after files are created
        setTimeout ()=>
          @app.appui.showNotification("✅ JavaScript files created! Check the Code section for: component_data.js, functions.js, main.js")
          @createObjectQueryUI()
          # Switch to code editor to show the imported code
          if @app.appui?.setSection
            @app.appui.setSection("code")
          else if @app.setSection
            @app.setSection("code")
          else
            console.info "Navigate to Code section to see the generated files"
        , 2000

  createObjectQueryUI:()->
    # Create UI elements for querying object data
    container = document.getElementById("spriteeditor")
    if container and not document.getElementById("object-query-ui")
      uiContainer = document.createElement("div")
      uiContainer.id = "object-query-ui"
      uiContainer.style.cssText = """
        position: absolute;
        top: 10px;
        right: 10px;
        background: rgba(0, 0, 0, 0.9);
        padding: 15px;
        border-radius: 8px;
        color: white;
        font-family: 'Courier New', monospace;
        z-index: 1000;
        min-width: 300px;
        border: 2px solid #444;
        box-shadow: 0 4px 8px rgba(0,0,0,0.3);
      """
      
      uiContainer.innerHTML = """
        <div style="margin-bottom: 15px; font-weight: bold; font-size: 14px; color: #4CAF50;">Object Query & Editor</div>
        <div style="margin-bottom: 10px;">
          <input type="text" id="object-id-input" placeholder="Enter object ID (e.g. rect1)" 
                 style="width: 180px; padding: 5px; margin-right: 8px; color: black; border: 1px solid #666; border-radius: 3px;">
          <button id="query-object-btn" style="padding: 5px 12px; background: #4CAF50; color: white; border: none; border-radius: 3px; cursor: pointer;">Get Data</button>
        </div>
        <div style="margin-bottom: 10px;">
          <button id="list-objects-btn" style="padding: 5px 12px; margin-right: 8px; background: #2196F3; color: white; border: none; border-radius: 3px; cursor: pointer;">List All</button>
          <button id="edit-object-btn" style="padding: 5px 12px; margin-right: 8px; background: #FF9800; color: white; border: none; border-radius: 3px; cursor: pointer; display: none;">Edit Object</button>
          <button id="close-query-ui-btn" style="padding: 5px 12px; background: #f44336; color: white; border: none; border-radius: 3px; cursor: pointer; float: right;">✕</button>
        </div>
        <div style="clear: both; margin-bottom: 5px; font-size: 12px; color: #aaa;">
          Drag bottom-right corner to resize:
        </div>
        <div id="object-query-result" style="
          min-height: 200px; 
          height: 300px;
          max-height: 500px;
          font-size: 11px; 
          overflow-y: auto; 
          background: rgba(0,0,0,0.8); 
          color: #e0e0e0;
          padding: 12px; 
          border-radius: 4px; 
          white-space: pre-wrap;
          border: 1px solid #666;
          resize: both;
          overflow: auto;
          font-family: 'Courier New', monospace;
          line-height: 1.3;
          word-wrap: break-word;
        ">Ready for queries...</div>
        <div id="object-edit-panel" style="display: none; margin-top: 10px; padding: 10px; background: rgba(0,50,0,0.8); border-radius: 5px; border: 1px solid #4CAF50;">
          <div style="font-weight: bold; margin-bottom: 10px; color: #4CAF50;">Edit Object Properties</div>
          <div id="object-edit-form"></div>
          <div style="margin-top: 10px;">
            <button id="save-object-changes-btn" style="padding: 5px 12px; margin-right: 8px; background: #4CAF50; color: white; border: none; border-radius: 3px; cursor: pointer;">Save Changes</button>
            <button id="cancel-object-edit-btn" style="padding: 5px 12px; background: #999; color: white; border: none; border-radius: 3px; cursor: pointer;">Cancel</button>
          </div>
        </div>
      """
      
      container.appendChild(uiContainer)
      
      # Add event listeners
      document.getElementById("query-object-btn").addEventListener "click", ()=>
        @queryObjectData()
      
      document.getElementById("list-objects-btn").addEventListener "click", ()=>
        @listAllObjects()
        
      document.getElementById("edit-object-btn").addEventListener "click", ()=>
        @showEditForm()
        
      document.getElementById("close-query-ui-btn").addEventListener "click", ()=>
        uiContainer.remove()
      
      document.getElementById("object-id-input").addEventListener "keypress", (event)=>
        if event.key == "Enter"
          @queryObjectData()

  queryObjectData:()->
    objectId = document.getElementById("object-id-input").value.trim()
    resultDiv = document.getElementById("object-query-result")
    editBtn = document.getElementById("edit-object-btn")
    
    if not objectId
      resultDiv.textContent = "Please enter an object ID"
      editBtn.style.display = "none"
      return
    
    # Send request to get object data
    @app.client.sendRequest {
      name: "read_component_data"
    }, (msg)=>
      if msg.data
        # Handle both entities and objects data structures
        objectsData = msg.data.entities || msg.data.objects
        
        if objectsData and objectsData[objectId]
          objectData = objectsData[objectId]
          @currentObjectData = objectData  # Store for editing
          @currentObjectId = objectId
          
          # Console log the data nicely
          console.log("=== OBJECT DATA FOR '#{objectId}' ===")
          console.log("Shape:", objectData.shape)
          console.log("Position:", objectData.position)
          if objectData.shape == "rectangle"
            console.log("Size:", objectData.size)
          else if objectData.shape == "circle"
            console.log("Radius:", objectData.radius)
          console.log("Class:", objectData.class)
          console.log("Components:", objectData.components)
          console.log("Variable Values:", objectData.variableValues)
          console.log("Full Object:", objectData)
          console.log("=== END ===")
          
          # Format the output for display
          output = "=== #{objectId.toUpperCase()} ===\n\n"
          output += "Shape: #{objectData.shape}\n"
          output += "Position: x=#{objectData.position?.x || 0}, y=#{objectData.position?.y || 0}\n"
          
          if objectData.shape == "rectangle" and objectData.size
            output += "Dimensions: #{objectData.size.width} x #{objectData.size.height}\n"
            output += "Usage: rect(#{objectData.position?.x || 0}, #{objectData.position?.y || 0}, #{objectData.size.width}, #{objectData.size.height})\n"
          else if objectData.shape == "circle" and objectData.radius
            output += "Radius: #{objectData.radius}\n"
            output += "Usage: circle(#{objectData.position?.x || 0}, #{objectData.position?.y || 0}, #{objectData.radius})\n"
          
          output += "\nClass: #{objectData.class || 'none'}\n"
          output += "Components: #{objectData.components?.join(', ') || 'none'}\n"
          
          if objectData.variableValues
            output += "\n--- Component Data ---\n"
            for component, values of objectData.variableValues
              output += "#{component}:\n"
              for key, value of values
                output += "  • #{key}: #{JSON.stringify(value)}\n"
          
          output += "\n--- Code Examples ---\n"
          output += "drawObject(\"#{objectId}\")\n"
          output += "data = getObject(\"#{objectId}\")\n"
          if objectData.shape == "rectangle"
            output += "drawObject(\"#{objectId}\", 100, 50)  // custom position"
          else
            output += "drawObject(\"#{objectId}\", 200, 150)  // custom position"
          
          resultDiv.textContent = output
          editBtn.style.display = "inline-block"  # Show edit button
        else
          console.log("Object '#{objectId}' not found in data:", msg.data)
          availableObjects = if objectsData then Object.keys(objectsData).join(', ') else 'none'
          resultDiv.textContent = "Object '#{objectId}' not found\n\nAvailable objects:\n#{availableObjects}"
          editBtn.style.display = "none"
      else
        resultDiv.textContent = "No data received from server"
        editBtn.style.display = "none"

  listAllObjects:()->
    resultDiv = document.getElementById("object-query-result")
    
    # Send request to get all object data
    @app.client.sendRequest {
      name: "read_component_data"
    }, (msg)=>
      if msg.data
        # Handle both entities and objects data structures
        objectsData = msg.data.entities || msg.data.objects
        
        if objectsData
          objectList = Object.keys(objectsData)
          
          # Console log everything nicely
          console.log("=== ALL OBJECTS ===")
          console.log("Total objects:", objectList.length)
          for objId in objectList
            obj = objectsData[objId]
            console.log("#{objId}:", obj)
          console.log("=== END ALL OBJECTS ===")
          
          output = "=== ALL OBJECTS (#{objectList.length}) ===\n\n"
          
          for objId in objectList
            obj = objectsData[objId]
            output += "#{objId.toUpperCase()}\n"
            output += "  Shape: #{obj.shape}\n"
            output += "  Position: x=#{obj.position?.x || 0}, y=#{obj.position?.y || 0}\n"
            
            if obj.shape == "rectangle" and obj.size
              output += "  Size: #{obj.size.width} x #{obj.size.height}\n"
              output += "  Usage: rect(#{obj.position?.x || 0}, #{obj.position?.y || 0}, #{obj.size.width}, #{obj.size.height})\n"
            else if obj.shape == "circle" and obj.radius
              output += "  Radius: #{obj.radius}\n"
              output += "  Usage: circle(#{obj.position?.x || 0}, #{obj.position?.y || 0}, #{obj.radius})\n"
            
            output += "  Class: #{obj.class || 'none'}\n"
            output += "  Components: #{obj.components?.join(', ') || 'none'}\n"
            
            if obj.variableValues?.visual?.color
              output += "  Color: #{obj.variableValues.visual.color}\n"
              
            output += "\n"
          
          output += "--- Quick Reference ---\n"
          output += "drawObject(\"object_id\")\n"
          output += "getObject(\"object_id\")\n"
          output += "drawAllObjects()\n"
          
          resultDiv.textContent = output
        else
          console.log("No objects found in response:", msg.data)
          resultDiv.textContent = "No objects found in db.json\n\nMake sure the server is running and db.json exists."
      else
        resultDiv.textContent = "No data received from server"

  createSprite:(name,img,callback)->
    @checkSave true,()=>
      if img?
        width = img.width
        height = img.height
      else if @spriteview.selection?
        width = Math.max(8,@spriteview.selection.w)
        height = Math.max(8,@spriteview.selection.h)
      else
        width = Math.max(8,@spriteview.sprite.width)
        height = Math.max(8,@spriteview.sprite.height)

      sprite = @app.project.createSprite(width,height,name)
      @spriteview.setSprite sprite
      @animation_panel.spriteChanged()
      if img?
        @spriteview.getFrame().getContext().drawImage img,0,0

      @spriteview.update()
      @setSelectedItem(sprite.name)
      @spriteview.editable = true
      @saveSprite ()=>
        @rebuildList()
        callback() if callback?

  setSelectedItem:(name)->
    @checkSave(true)
    sprite = @app.project.getSprite name
    if sprite?
      @spriteview.setSprite sprite

    @spriteview.windowResized()
    @spriteview.update()
    @spriteview.editable = true
    @setSelectedSprite name
    super(name)

  setSelectedSprite:(sprite)->
    @selected_sprite = sprite
    @animation_panel.spriteChanged()

    if @selected_sprite?
      if @spriteview.sprite?
        document.getElementById("sprite-width").value = @spriteview.sprite.width
        document.getElementById("sprite-height").value = @spriteview.sprite.height
        @sprite_size_validator.update()

      document.getElementById("sprite-width").disabled = false
      document.getElementById("sprite-height").disabled = false

      e = document.getElementById("spriteeditor")
      if e.firstChild?
        e.firstChild.style.display = "inline-block"
      @spriteview.windowResized()
    else
      document.getElementById("sprite-width").disabled = true
      document.getElementById("sprite-height").disabled = true
      e = document.getElementById("spriteeditor")
      if e.firstChild?
        e.firstChild.style.display = "none"

    @updateCurrentFileLock()
    @updateSelectionHints()
    @auto_palette.update()
    @updateCodeTip()
    @setCoordinates(-1,-1)

  setSprite:(data)->
    data = "data:image/png;base64,"+data
    @ignore_changes = true
    img = new Image
    img.src = data
    img.crossOrigin = "Anonymous"
    img.onload = ()=>
      @spriteview.sprite.load(img)
      @spriteview.windowResized()
      @spriteview.update()
      @spriteview.editable = true
      @ignore_changes = false
      @spriteview.windowResized()
      document.getElementById("sprite-width").value = @spriteview.sprite.width
      document.getElementById("sprite-height").value = @spriteview.sprite.height
      @sprite_size_validator.update()

  setColor:(@color)->
    @spriteview.setColor @color
    @auto_palette.colorPicked @color
    document.getElementById("colortext").value = @color

  spriteDimensionChanged:(dim)->
    if @selected_sprite == "icon"
      if dim == "width"
        document.getElementById("sprite-height").value = document.getElementById("sprite-width").value
      else
        document.getElementById("sprite-width").value = document.getElementById("sprite-height").value

  colortextChanged:()->
    @colorpicker.colorPicked(document.getElementById("colortext").value)

  colortextCopy:()->
    copy = document.getElementById("colortext-copy")
    colortext = document.getElementById("colortext")
    copy.classList.remove "fa-copy"
    copy.classList.add "fa-check"
    setTimeout (()=>
      copy.classList.remove "fa-check"
      copy.classList.add "fa-copy"),3000
    navigator.clipboard.writeText """\"#{colortext.value}\""""

  saveDimensionChange:(value)->
    return if @app.project.isLocked("sprites/#{@selected_sprite}.png")
    @app.project.lockFile("sprites/#{@selected_sprite}.png")
    w = value[0]
    h = value[1]

    try
      w = Number.parseFloat(w)
      h = Number.parseFloat(h)
    catch err

    if (@selected_sprite != "icon" or w == h) and Number.isInteger(w) and Number.isInteger(h) and w > 0 and h > 0 and w <= 1024 and h <= 1024 and @selected_sprite? and (w != @spriteview.sprite.width or h != @spriteview.sprite.height)
      @spriteview.sprite.undo = new Undo() if not @spriteview.sprite.undo?
      @spriteview.sprite.undo.pushState @spriteview.sprite.clone() if @spriteview.sprite.undo.empty()
      @spriteview.sprite.resize(w,h)
      @spriteview.sprite.undo.pushState @spriteview.sprite.clone()
      @spriteview.windowResized()
      @spriteview.update()
      @spriteChanged()
      @checkSave(true)
      document.getElementById("sprite-width").value = @spriteview.sprite.width
      document.getElementById("sprite-height").value = @spriteview.sprite.height
      @sprite_size_validator.update()
    else
      document.getElementById("sprite-width").value = @spriteview.sprite.width
      document.getElementById("sprite-height").value = @spriteview.sprite.height
      @sprite_size_validator.update()

  undo:()->
    return if @app.project.isLocked("sprites/#{@selected_sprite}.png")
    @app.project.lockFile("sprites/#{@selected_sprite}.png")
    if @spriteview.sprite and @spriteview.sprite.undo?
      s = @spriteview.sprite.undo.undo ()=>@spriteview.sprite.clone()
      @spriteview.selection = null
      if s?
        @spriteview.sprite.copyFrom s
        @spriteview.update()
        document.getElementById("sprite-width").value = @spriteview.sprite.width
        document.getElementById("sprite-height").value = @spriteview.sprite.height
        @sprite_size_validator.update()
        @spriteview.windowResized()
        @spriteChanged()
        @animation_panel.updateFrames()

  redo:()->
    return if @app.project.isLocked("sprites/#{@selected_sprite}.png")
    @app.project.lockFile("sprites/#{@selected_sprite}.png")
    if @spriteview.sprite and @spriteview.sprite.undo?
      s = @spriteview.sprite.undo.redo()
      @spriteview.selection = null
      if s?
        @spriteview.sprite.copyFrom s
        @spriteview.update()
        document.getElementById("sprite-width").value = @spriteview.sprite.width
        document.getElementById("sprite-height").value = @spriteview.sprite.height
        @sprite_size_validator.update()
        @spriteview.windowResized()
        @spriteChanged()
        @animation_panel.updateFrames()

  copy:()->
    if @tool.selectiontool and @spriteview.selection?
      @clipboard = new Sprite(@spriteview.selection.w,@spriteview.selection.h)
      @clipboard.frames[0].getContext().drawImage @spriteview.getFrame().canvas,-@spriteview.selection.x,-@spriteview.selection.y
      @clipboard.partial = true
    else
      @clipboard = @spriteview.sprite.clone()

  cut:()->
    return if @app.project.isLocked("sprites/#{@selected_sprite}.png")
    @app.project.lockFile("sprites/#{@selected_sprite}.png")

    @spriteview.sprite.undo = new Undo() if not @spriteview.sprite.undo?
    @spriteview.sprite.undo.pushState @spriteview.sprite.clone() if @spriteview.sprite.undo.empty()

    if @tool.selectiontool and @spriteview.selection?
      @clipboard = new Sprite(@spriteview.selection.w,@spriteview.selection.h)
      @clipboard.frames[0].getContext().drawImage @spriteview.getFrame().canvas,-@spriteview.selection.x,-@spriteview.selection.y
      @clipboard.partial = true
      sel = @spriteview.selection
      @spriteview.getFrame().getContext().clearRect sel.x,sel.y,sel.w,sel.h
    else
      @clipboard = @spriteview.sprite.clone()
      @spriteview.sprite.clear()

    @spriteview.sprite.undo.pushState @spriteview.sprite.clone()
    @currentSpriteUpdated()
    @spriteChanged()

  paste:()->
    return if @app.project.isLocked("sprites/#{@selected_sprite}.png")
    @app.project.lockFile("sprites/#{@selected_sprite}.png")
    if @clipboard?
      @spriteview.sprite.undo = new Undo() if not @spriteview.sprite.undo?
      @spriteview.sprite.undo.pushState @spriteview.sprite.clone() if @spriteview.sprite.undo.empty()

      if @clipboard.partial
        x = 0
        y = 0

        x = Math.max(0,Math.min(@spriteview.sprite.width-@clipboard.width,@spriteview.mouse_x))
        y = Math.max(0,Math.min(@spriteview.sprite.height-@clipboard.height,@spriteview.mouse_y))

        @spriteview.floating_selection =
          bg: @spriteview.getFrame().clone().getCanvas()
          fg: @clipboard.frames[0].getCanvas()
        @spriteview.selection =
          x: x
          y: y
          w: @clipboard.frames[0].canvas.width
          h: @clipboard.frames[0].canvas.height

        @spriteview.getFrame().getContext().drawImage @clipboard.frames[0].getCanvas(),x,y
        @setSelectedTool("fa-vector-square")
      else
        if @selected_sprite != "icon" or (@clipboard.width == @clipboard.height and @clipboard.frames.length == 1)
          @spriteview.sprite.copyFrom(@clipboard)

      @spriteview.sprite.undo.pushState @spriteview.sprite.clone()
      @currentSpriteUpdated()
      @spriteChanged()

  currentSpriteUpdated:()->
    @spriteview.update()
    document.getElementById("sprite-width").value = @spriteview.sprite.width
    document.getElementById("sprite-height").value = @spriteview.sprite.height
    @animation_panel.updateFrames()
    @sprite_size_validator.update()
    @spriteview.windowResized()

  setColorPicker:(picker)->
    @spriteview.colorpicker = picker

    if picker
      #@spriteview.canvas.classList.add "colorpicker"
      @spriteview.canvas.style.cursor = "url( '/img/eyedropper.svg' ) 0 24, pointer"
      document.getElementById("eyedropper").classList.add "selected"
    else
      #@spriteview.canvas.classList.remove "colorpicker"
      @spriteview.canvas.style.cursor = "crosshair"
      document.getElementById("eyedropper").classList.remove "selected"

  updateSelectionHints:()->
    if @spriteview.selection? and @tool.selectiontool
      document.getElementById("selection-group").style.display = "block"
      w = @spriteview.selection.w
      h = @spriteview.selection.h
      if @spriteview.sprite.frames.length == 1 and (@spriteview.sprite.width/w)%1 == 0 and (@spriteview.sprite.height/h)%1 == 0 and (@spriteview.sprite.width/w >=2 or @spriteview.sprite.height/h >= 2)
        document.getElementById("selection-operation-film").style.display = "block"
      else
        document.getElementById("selection-operation-film").style.display = "none"
    else
      document.getElementById("selection-group").style.display = "none"

  stripToAnimation:()->
    w = @spriteview.selection.w
    h = @spriteview.selection.h
    if @spriteview.sprite.frames.length == 1 and (@spriteview.sprite.width/w)%1 == 0 and (@spriteview.sprite.height/h)%1 == 0 and (@spriteview.sprite.width/w >=2 or @spriteview.sprite.height/h >= 2)
      @spriteview.sprite.undo = new Undo() if not @spriteview.sprite.undo?
      @spriteview.sprite.undo.pushState @spriteview.sprite.clone() if @spriteview.sprite.undo.empty()

      n = @spriteview.sprite.width/w
      m = @spriteview.sprite.height/h
      sprite = new Sprite(w,h)
      index = 0
      for j in [0..m-1] by 1
        for i in [0..n-1] by 1
           sprite.frames[index] = new SpriteFrame(sprite,w,h)
           sprite.frames[index].getContext().drawImage(@spriteview.sprite.frames[0].getCanvas(),-i*w,-j*h)
           index++

      @spriteview.sprite.copyFrom sprite
      @spriteview.sprite.undo.pushState @spriteview.sprite.clone()
      @currentSpriteUpdated()
      @spriteChanged()
      @animation_panel.spriteChanged()

  flipHSprite:()->
    return if @app.project.isLocked("sprites/#{@selected_sprite}.png")
    @app.project.lockFile("sprites/#{@selected_sprite}.png")
    @spriteview.flipSprite("horizontal")

  flipVSprite:()->
    return if @app.project.isLocked("sprites/#{@selected_sprite}.png")
    @app.project.lockFile("sprites/#{@selected_sprite}.png")
    @spriteview.flipSprite("vertical")

  rotateSprite:(direction)->
    return if @app.project.isLocked("sprites/#{@selected_sprite}.png")
    @app.project.lockFile("sprites/#{@selected_sprite}.png")
    @spriteview.rotateSprite(direction)

  fileDropped:(file,folder)->
    console.info "processing #{file.name}"
    console.info "folder: "+folder
    reader = new FileReader()
    reader.addEventListener "load",()=>
      console.info "file read, size = "+ reader.result.byteLength
      if reader.result.byteLength > 5000000
        @app.appui.showNotification(@app.translator.get("Image file is too heavy"))
        return

      img = new Image
      img.src = reader.result
      img.onload = ()=>
        if img.complete and img.width > 0 and img.height > 0 and img.width <= 2048 and img.height <= 2048
          name = file.name.split(".")[0]
          name = @findNewFilename name,"getSprite",folder
          if folder? then name = folder.getFullDashPath()+"-"+name
          if folder? then folder.setOpen true

          sprite = @app.project.createSprite name,img
          @setSelectedItem name

          @app.client.sendRequest {
            name: "write_project_file"
            project: @app.project.id
            file: "sprites/#{name}.png"
            properties: {}
            content: reader.result.split(",")[1]
          },(msg)=>
            console.info msg
            @app.project.removePendingChange(@)
            @app.project.updateSpriteList()
            @checkNameFieldActivation()
        else
          @app.appui.showNotification(@app.translator.get("Image size is too large"))

    reader.readAsDataURL(file)

  updateCodeTip:()->
    if @selected_sprite? and @app.project.getSprite(@selected_sprite)?
      sprite = @app.project.getSprite(@selected_sprite)
      code = """screen.drawSprite( "#{@selected_sprite.replace(/-/g,"/")}", x, y, #{sprite.width}, #{sprite.height} )"""
    else
      code = ""
    @code_tip.set code

  setCoordinates:(x,y)->
    e = document.getElementById("sprite-coordinates")
    if x<0 or y<0
      e.innerText = ""
    else
      e.innerText = "#{x} , #{y}"

  renameItem:(item,name)->
    @app.project.changeSpriteName item.name,name # needed to trigger updating of maps
    super(item,name)

  showEditForm:()->
    return unless @currentObjectData and @currentObjectId
    
    editPanel = document.getElementById("object-edit-panel")
    editForm = document.getElementById("object-edit-form")
    
    # Build edit form based on object data
    formHTML = ""
    
    # Position editing
    formHTML += """
      <div style="margin-bottom: 10px;">
        <label style="display: inline-block; width: 60px; color: #4CAF50;">Position:</label>
        <span style="color: #ccc;">X:</span> <input type="number" id="edit-pos-x" value="#{@currentObjectData.position?.x || 0}" style="width: 50px; margin-right: 8px; color: black; padding: 2px;">
        <span style="color: #ccc;">Y:</span> <input type="number" id="edit-pos-y" value="#{@currentObjectData.position?.y || 0}" style="width: 50px; color: black; padding: 2px;">
      </div>
    """
    
    # Size/radius editing based on shape
    if @currentObjectData.shape == "rectangle" and @currentObjectData.size
      formHTML += """
        <div style="margin-bottom: 10px;">
          <label style="display: inline-block; width: 60px; color: #4CAF50;">Size:</label>
          <span style="color: #ccc;">W:</span> <input type="number" id="edit-size-w" value="#{@currentObjectData.size.width}" style="width: 50px; margin-right: 8px; color: black; padding: 2px;">
          <span style="color: #ccc;">H:</span> <input type="number" id="edit-size-h" value="#{@currentObjectData.size.height}" style="width: 50px; color: black; padding: 2px;">
        </div>
      """
    else if @currentObjectData.shape == "circle" and @currentObjectData.radius
      formHTML += """
        <div style="margin-bottom: 10px;">
          <label style="display: inline-block; width: 60px; color: #4CAF50;">Radius:</label>
          <input type="number" id="edit-radius" value="#{@currentObjectData.radius}" style="width: 60px; color: black; padding: 2px;">
        </div>
      """
    
    # Component variables editing
    if @currentObjectData.variableValues
      for component, values of @currentObjectData.variableValues
        formHTML += """<div style="margin-bottom: 8px; color: #FFA500;">#{component.toUpperCase()} Component:</div>"""
        for key, value of values
          if typeof value == "number"
            formHTML += """
              <div style="margin-bottom: 6px; margin-left: 10px;">
                <label style="display: inline-block; width: 80px; color: #ccc;">#{key}:</label>
                <input type="number" id="edit-#{component}-#{key}" value="#{value}" step="0.1" style="width: 80px; color: black; padding: 2px;">
              </div>
            """
          else if typeof value == "string"
            formHTML += """
              <div style="margin-bottom: 6px; margin-left: 10px;">
                <label style="display: inline-block; width: 80px; color: #ccc;">#{key}:</label>
                <input type="text" id="edit-#{component}-#{key}" value="#{value}" style="width: 100px; color: black; padding: 2px;">
              </div>
            """
          else if typeof value == "boolean"
            checked = if value then "checked" else ""
            formHTML += """
              <div style="margin-bottom: 6px; margin-left: 10px;">
                <label style="color: #ccc;">
                  <input type="checkbox" id="edit-#{component}-#{key}" #{checked} style="margin-right: 5px;">
                  #{key}
                </label>
              </div>
            """
    
    editForm.innerHTML = formHTML
    editPanel.style.display = "block"
    
    # Add event listeners for save and cancel buttons (if not already added)
    if not @editListenersAdded
      document.getElementById("save-object-changes-btn").addEventListener "click", ()=>
        @saveObjectChanges()
      
      document.getElementById("cancel-object-edit-btn").addEventListener "click", ()=>
        @cancelObjectEdit()
      
      @editListenersAdded = true

  saveObjectChanges:()->
    return unless @currentObjectData and @currentObjectId
    
    # Collect form data
    updatedData = JSON.parse(JSON.stringify(@currentObjectData))  # Deep copy
    
    # Update position
    posX = document.getElementById("edit-pos-x")?.value
    posY = document.getElementById("edit-pos-y")?.value
    if posX? and posY?
      updatedData.position = { x: parseFloat(posX), y: parseFloat(posY) }
    
    # Update size/radius
    if updatedData.shape == "rectangle"
      sizeW = document.getElementById("edit-size-w")?.value
      sizeH = document.getElementById("edit-size-h")?.value
      if sizeW? and sizeH?
        updatedData.size = { width: parseFloat(sizeW), height: parseFloat(sizeH) }
    else if updatedData.shape == "circle"
      radius = document.getElementById("edit-radius")?.value
      if radius?
        updatedData.radius = parseFloat(radius)
    
    # Update component variables
    if updatedData.variableValues
      for component, values of updatedData.variableValues
        for key, value of values
          inputElement = document.getElementById("edit-#{component}-#{key}")
          if inputElement?
            if typeof value == "number"
              updatedData.variableValues[component][key] = parseFloat(inputElement.value)
            else if typeof value == "string"
              updatedData.variableValues[component][key] = inputElement.value
            else if typeof value == "boolean"
              updatedData.variableValues[component][key] = inputElement.checked
    
    # Send update request to server
    @app.client.sendRequest {
      name: "update_component_data"
      objectId: @currentObjectId
      objectData: updatedData
    }, (msg)=>
      if msg.success
        console.log("Object updated successfully:", @currentObjectId, updatedData)
        @app.appui.showNotification(" Object '#{@currentObjectId}' updated successfully!")
        
        # Refresh the display
        @queryObjectData()
        @cancelObjectEdit()
        
        # Regenerate component files
        @app.project.importComponentData()
      else
        console.error("Failed to update object:", msg.error)
        @app.appui.showNotification("❌ Failed to update object: #{msg.error || 'Unknown error'}")

  cancelObjectEdit:()->
    editPanel = document.getElementById("object-edit-panel")
    editPanel.style.display = "none"
