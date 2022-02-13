EXCEPTION_OVERFLOW = -1
NO_SELECTED = -1
MAX_HITS = 500
ELEMENT_NODE = 1
TEXT_NODE = 3

SEQ_SYB_HAN = "0123456789 !#$%()*+,-./:;<=>?@[\\]^_`{|}~&"
SEQ_SYB_ZEN = "０１２３４５６７８９　！＃＄％（）＊＋，－．／：；＜＝＞？＠［＼］＾＿｀｛｜｝～＆"
SEQ_LRG_HAN = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
SEQ_SML_HAN = "abcdefghijklmnopqrstuvwxyz"
SEQ_LRG_ZEN = "ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ"
SEQ_SML_ZEN = "ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ"
SEQ_HRA_ZEN = "あいうえおかきくけこさしすせそたちつってとなにぬねのはひふへほまみむめもやゆよらりるれろわをんゃゅょぁぃぅぇぉがぎぐげござじずぜぞだじづでどばびぶべぼぱぴぷぺぽゔ"
SEQ_KAT_ZEN = "アイウエオカキクケコサシスセソタチツッテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲンャュョァィゥェォガギグゲゴザジズゼゾダジヅデドバビブベボパピプペポヴ"

XPATH_TRANS_TARGET_HIRA = "translate(., \"#{SEQ_SML_HAN}#{SEQ_SML_ZEN}#{SEQ_LRG_ZEN}#{SEQ_SYB_ZEN}#{SEQ_KAT_ZEN}\", \"#{SEQ_LRG_HAN}#{SEQ_LRG_HAN}#{SEQ_LRG_HAN}#{SEQ_SYB_HAN}#{SEQ_HRA_ZEN}\")"
XPATH_TRANS_TARGET_KATA = "translate(., \"#{SEQ_SML_HAN}#{SEQ_SML_ZEN}#{SEQ_LRG_ZEN}#{SEQ_SYB_ZEN}#{SEQ_HRA_ZEN}\", \"#{SEQ_LRG_HAN}#{SEQ_LRG_HAN}#{SEQ_LRG_HAN}#{SEQ_SYB_HAN}#{SEQ_KAT_ZEN}\")"

TRANS_EXPR_TARGET_HIRA = document.createExpression XPATH_TRANS_TARGET_HIRA, null
TRANS_EXPR_TARGET_KATA = document.createExpression XPATH_TRANS_TARGET_KATA, null

workspaces = null

escape = (text) ->
  entity =
    "&": "&amp;"
    "<": "&lt;"
    ">": "&gt;"
    '"': "&quot;"
    "'": "&apos;"
  text.replace /[&<>"']/g, (match) ->
    entity[match]

isChangeDom = false
cachedNodeSet = {}
cachedNodeSetCs = {}

onDomChangeHandler = ->
  isChangeDom = true
  for key of cachedNodeSet
    delete cachedNodeSet[key]
  cachedNodeSet = {}
  for key of cachedNodeSetCs
    delete cachedNodeSetCs[key]
  cachedNodeSetCs = {}
  #console.log "DOM changed"
  return

addDomChangeHandler = ->
  document.addEventListener "DOMNodeInserted", onDomChangeHandler, false
  document.addEventListener "DOMNodeRemoved" , onDomChangeHandler, false

removeDomChangeHandler = ->
  document.removeEventListener "DOMNodeInserted", onDomChangeHandler, false
  document.removeEventListener "DOMNodeRemoved" , onDomChangeHandler, false

class Activity
  constructor: (params) ->
    @hits = 0
    @selectId = NO_SELECTED
    {@keyword, @ignore, @regexp, @shade} = params

class Workspace

  constructor: (@win) ->
    
    @doc = @win.document
    if @doc.querySelectorAll("canvas.__esCanvas").length > 0
      @conflictFrame = true
      return
    
    @miniShade = []
    @textNodeSet = []
    @iframeRects = []
    @searchResults = []
    @shade = []
    @ctx = []
    @lastSelect = null
    @hits = 0
    @timer = false
    
    styles = []
    styles.push "position:absolute"
    styles.push "z-index:2147483643"
    styles.push "top:0px"
    styles.push "left:0px"
    styles.push "display:none"
    styles.push "pointer-events:none"
    @style = styles.join(";")
    @elStyle = @doc.createElement "style"
    @elStyle.setAttribute "type", "text/css"
    styleSheet = @doc.querySelector("head").appendChild(@elStyle).sheet
    styleSheet.addRule "esspan.__esHilite", "background:#FFFF00;color:#000;border-radius:2px;margin:-1px;padding:1px;position:relative;z-index:2147483645;display:inline-block;"
    styleSheet.addRule "esspan.__esSelect", "background:#FF7600;color:#000;border-radius:2px;margin:-1px;padding:1px;position:relative;z-index:2147483646;display:inline-block;"
    styleSheet.addRule "esspan.__esSelArea", "background:#FFFFFF;color:#000;margin:-3px;padding:3px;border-radius:2px;position:relative;z-index:2147483644;display:inline-block;-webkit-box-shadow: 0px 1px 10px #000;"
    
    @win.addEventListener "resize", @onResize.bind(@)
    @doc.body.normalize()
    
    @calcClipRects()
  
  onResize: ->
    if @timer
      clearTimeout @timer
    @timer = setTimeout((=> @resizeShade()), 200)
  
  destroy: ->
    try
      @win.removeEventListener "resize", @onResize.bind(@)
    catch
    @doc.querySelector("head").removeChild @elStyle
    @clearResult()
    @clearShade()
  
  calcClipRects: ->
    if @win is parent
      iframes = @doc.getElementsByTagName("IFRAME")
      [].forEach.call iframes, (iframe) =>
        {offsetLeft, offsetTop, offsetWidth, offsetHeight} = iframe
        target = iframe
        while target = target.offsetParent
          offsetTop += target.offsetTop
          offsetLeft += target.offsetLeft
        @iframeRects.push [offsetLeft, offsetTop, offsetWidth, offsetHeight, iframe.src]
        #rect = iframe.getBoundingClientRect()
        #@iframeRects.push [@win.scrollX + rect.left, @win.scrollY + rect.top, rect.width, rect.height, iframe.src]
      @resetMiniFrame()
  
  resizeShade: ->
    removeDomChangeHandler()
    if @shade.length > 0
      @iframeRects = []
      @calcClipRects()
      @removeShade()
      @showShade()
      @clearRectResults()
    addDomChangeHandler()
  
  clearRectResults: ->
      @searchResults.forEach (result) =>
        @clearRectSelected result[0]
      if !workspaces.activity?.shade || workspaces.activity.hits is 0
        @hideShade()
  
  clearShadeCtx: (shade) ->
    ctx = shade.getContext "2d"
    ctx.clearRect 0, 0, shade.offsetWidth, shade.offsetHeight
    ctx.globalCompositeOperation = "source-over"
    ctx.fillStyle = "rgba(0, 0, 0, 0.4)"
    ctx.fillRect 0, 0, shade.offsetWidth, shade.offsetHeight
    ctx.globalCompositeOperation = "destination-out"
    ctx.fillStyle = "black"
  
  drawShade: (shade, ctx, height) ->
    try
      computedStyle = @doc.defaultView.getComputedStyle?(@doc.body)
    catch
      return
    canvasWidth = @win.innerWidth
    if @doc.body.clientHeight > @win.innerHeight || computedStyle?["overflow-y"] is "scroll"
      canvasWidth = @doc.body.scrollWidth
    shade.setAttribute "width", canvasWidth   #@doc.body.scrollWidth #@win.innerWidth
    shade.setAttribute "height", height
    ctx.fillStyle = "rgba(0, 0, 0, 0.4)"
    ctx.fillRect 0, 0, shade.offsetWidth, height
    ctx.globalCompositeOperation = "destination-out"
    ctx.fillStyle = "black"
    if @win is parent
      for i in [0...@iframeRects.length]
        ctx.clearRect @iframeRects[i][0], @iframeRects[i][1], @iframeRects[i][2], @iframeRects[i][3]
  
  hideShade: ->
    if @shade.length > 0
      for i in [0...@shade.length]
        @shade[i].setAttribute "style", @shade[i].getAttribute("style").replace "display:block", "display:none"
    if @miniShade.length > 0
      for i in [0...@miniShade.length]
        @miniShade[i].setAttribute "style", @miniShade[i].getAttribute("style").replace "display:block", "display:none"
  
  removeShade: ->
    if @shade.length > 0
      while shade = @shade.shift()
        @doc.body.removeChild shade
    if @miniShade.length > 0
      css = @style.replace "display:none", "display:block"
      for i in [0...@miniShade.length]
        shade = @miniShade[i]
        @clearShadeCtx shade
        shade.setAttribute "style", shade.getAttribute("style").replace "display:block", "display:none"
  
  showShade: (options) ->
    if @shade.length > 0
      if /display:block/.test @shade[0].getAttribute "style"
        return
    else
      loops = Math.floor(@doc.body.scrollHeight / 32000)
      for i in [0..loops]
        height = Math.min 32000, 32000 * (loops - i) + (@doc.body.scrollHeight % 32000)
        @doc.body.appendChild @shade[i] = @doc.createElement "canvas"
        @shade[i].className = "__esCanvas"
        @ctx[i] = @shade[i].getContext "2d"
        @drawShade @shade[i], @ctx[i], height
    for i in [0...@shade.length]
      top = i * 32000
      css = @style.replace /top:\d+px/, "top:#{top}px"
      unless options?.hide
        css = css.replace "display:none", "display:block"
      @shade[i].setAttribute "style", css
    if @miniShade.length > 0
      css = @style
      unless options?.hide
        css = css.replace "display:none", "display:block"
      for i in [0...@miniShade.length]
        @miniShade[i].setAttribute "style", css
  
  clearShade: (options) ->
    if @miniShade.length > 0
      css = @style.replace "display:none", "display:block"
      for i in [0...@miniShade.length]
        shade = @miniShade[i]
        @clearShadeCtx shade
        unless options?.unhide
          shade.setAttribute "style", shade.getAttribute("style").replace "display:block", "display:none"
    if @shade.length > 0
      @shade.forEach (shade) =>
        @clearShadeCtx shade
        if @win is parent
          ctx = shade.getContext "2d"
          for i in [0...@iframeRects.length]
            ctx.clearRect @iframeRects[i][0], @iframeRects[i][1], @iframeRects[i][2], @iframeRects[i][3]
      unless options?.unhide
        @hideShade()
  
  clearRect: (ctx, args) ->
    [x, y, width, height] = args.pos
    rad = 2 #args.rad
    ctx.beginPath()
    ctx.moveTo(x + rad, y)
    ctx.lineTo(x + width - rad, y)
    ctx.arc(x + width - rad, y + rad, rad, Math.PI * 1.5, 0, false)
    ctx.lineTo(x + width, y + height - rad)
    ctx.arc(x + width - rad, y + height - rad, rad, 0, Math.PI * 0.5, false)
    ctx.lineTo(x + rad, y + height)
    ctx.arc(x + rad, y + height - rad, rad, Math.PI * 0.5, Math.PI, false)
    ctx.lineTo(x, y + rad)
    ctx.arc(x + rad, y + rad, rad, Math.PI, Math.PI * 1.5, false)
    ctx.closePath()
    ctx.fill()
  
  clearResult: (options, container) ->
    @clearShade options
    if @searchResults.length > 0
      if container
        @searchResults.forEach (elSearchWord) ->
          [].forEach.call elSearchWord[0].childNodes, (node) ->
            if container.selectionAnchorNode is node
              container.result = elSearchWord[1]
          elSearchWord[0].parentNode?.replaceChild elSearchWord[1], elSearchWord[0]
      else
        @searchResults.forEach (elSearchWord) ->
          elSearchWord[0].parentNode?.replaceChild elSearchWord[1], elSearchWord[0]
      @searchResults = []
  
  resetMiniFrame: ->
    if @miniShade.length > 0
      for i in [0...@miniShade.length]
        shade = @miniShade[i]
        rect = shade.getBoundingClientRect()
        @iframeRects.push [@win.scrollX + rect.left, @win.scrollY + rect.top, rect.width, rect.height, null]
        @clearShadeCtx shade
  
  setMiniFrame: (elCanvas, hilited) ->
    try
      shade = elCanvas.getElementsByClassName("__esMiniCanvas")?[0]
      if shade
        ctx = shade.getContext "2d"
      else
        shade = @doc.createElement "canvas"
        shade.setAttribute "width", Math.max elCanvas.firstChild.offsetWidth, elCanvas.offsetWidth
        shade.setAttribute "height", Math.max elCanvas.firstChild.offsetHeight, elCanvas.offsetHeight
        shade.setAttribute "class", "__esMiniCanvas"
        css = @style.replace "display:none", "display:block"
        shade.setAttribute "style", css
        elCanvas.firstChild.appendChild shade
        @clearShadeCtx shade
        rect = elCanvas.getBoundingClientRect()
        @iframeRects.push [left = @win.scrollX + rect.left, top = @win.scrollY + rect.top, rect.width, rect.height, null]
        i = Math.max Math.floor(top / 32000), 0
        @ctx[i].clearRect left, top, rect.width, rect.height
        @miniShade.push shade
      target = hilited
      offsetLeft = target.offsetLeft
      offsetTop = target.offsetTop
      while target = target.offsetParent
        if target is elCanvas
          break
        offsetLeft += target.offsetLeft
        offsetTop += target.offsetTop
      @clearRect ctx, pos: [offsetLeft, offsetTop, hilited.offsetWidth, hilited.offsetHeight]
      true
    catch e
      false
  
  digTextNodeByXPath: ->
    xpath = """//text()[normalize-space()!="" and not(parent::textarea|parent::script|parent::style|parent::noscript)]"""
    @textNodeSet = @doc.evaluate(xpath, @doc.body, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, @textNodeSet || null)
  
  digTextNode: (node) ->
    if node.nodeType is TEXT_NODE and node.textContent.replace(/[\s\t\n\r]/g, "") isnt "" and
      !(/TEXTAREA|SCRIPT|STYLE|NOSCRIPT/.test(node.parentNode.tagName)) and (node.parentNode?.offsetWidth || -1) > 0
        @textNodeSet.push node
    else
      [].forEach.call node.childNodes, (node) =>
        @digTextNode node
  
  clearRectSelected: (parentNode) ->
    hits = 0
    [].forEach.call parentNode.getElementsByTagName("esspan"), (hilited) =>
      targetRect = hilited.getBoundingClientRect()
      if (left = @win.scrollX + targetRect.left) + targetRect.width >= 0 && (top = @win.scrollY + targetRect.top) + targetRect.height >= 0
        hits++
        target = hilited
        while target = target.offsetParent
          computedStyle = @doc.defaultView.getComputedStyle?(target)
          if computedStyle?["overflow-y"] in ["scroll", "auto", "hidden"] && !(target.tagName is "BODY")
            inScrollable = @setMiniFrame target, hilited
            break
        unless inScrollable
          i = Math.max Math.floor(targetRect.top / 32000), 0
          @clearRect @ctx[i], pos: [left, top, targetRect.width, targetRect.height]      
    hits
  
  appendResult: (currentNode, newContent, hitCount) ->
    unless parentNode = currentNode.parentNode
      return
    (newNode = @doc.createElement("esspan")).innerHTML = newContent
    parentNode.replaceChild newNode, currentNode
    if workspaces.activity.shade
      hits = @clearRectSelected newNode
    else
      hits = hitCount
    if hits > 0
      @hits += hits
      @searchResults.push [newNode, currentNode]
    else
      parentNode.replaceChild currentNode, newNode
  
  searchKeyword: (keyword, escapedKeyword) ->
    @textNodeSet.forEach (node) =>
      if (content = node.textContent).indexOf(keyword) > -1
        splited = escape(content).split(escapedKeyword)
        newContent = splited.join """<esspan class="__esHilite">#{escapedKeyword}</esspan>"""
        @appendResult node, newContent
  
  searchKeywordIgnore: (keywordU, escapedKeywordU, keywordLen) ->
    @textNodeSet.forEach (node) =>
      if (contentU = (content = node.nodeValue).toUpperCase()).indexOf(keywordU) > -1
        splited = escape(contentU).split(escapedKeywordU)
        content = escape content
        newContent = ""
        pos = 0
        for i in [0...splited.length]
          matched = content.substring(pos + splited[i].length, pos + splited[i].length + keywordLen)
          newContent += content.substring(pos, pos + splited[i].length) + (if i < (splited.length - 1) then """<esspan class="__esHilite">#{matched}</esspan>""" else "")
          pos += splited[i].length + keywordLen
        @appendResult node, newContent
  
  searchKeywordRegexp: (rgKeyword) ->
    @textNodeSet.forEach (node) =>
      i = 0
      newContent = node.textContent.replace rgKeyword, (replacer) ->
        if replacer isnt ""
          i++
          """<esspan class="__esHilite">#{replacer}</esspan>"""
        else
          ""
      if i > 0
        @appendResult node, newContent, i
  
  startSearch: (params) ->
    {keyword, ignore, regexp} = params
    @hits = 0
    keywordLen = (escapedKeyword = escape keyword).length
    if regexp
      @searchKeywordRegexp new RegExp keyword, if !ignore then "ig" else "g"
    else if ignore
      @searchKeyword keyword, escapedKeyword
    else
      @searchKeywordIgnore keyword.toUpperCase(), escapedKeyword.toUpperCase(), keywordLen
  
  startSearchRT: (params, cachedNode, fnAltContent) ->
    @hits = 0
    useCache = false
    cacheAdded = false
    keys = []
    for key of cachedNode
      keys.push key
    keys.sort (a, b) -> b.length - a.length
    # console.log keys.join()
    for i in [0...keys.length]
      if params.altKeyword.lastIndexOf(keys[i], 0) is 0
        currentKey = keys[i]
        targetNodeSet = cachedNode[currentKey]
        useCache = true
        break
      #else
      #  delete cachedNode[keys[i]]
    
    if useCache
      xpath = params.xpath_usecache
    else
      xpath = params.xpath
      targetNodeSet = @doc.body
    
    textNodeSet = @doc.evaluate(xpath, targetNodeSet, null, XPathResult.UNORDERED_NODE_SNAPSHOT_TYPE, null)
    
    if (!useCache || currentKey isnt params.altKeyword) && params.altKeyword.length <= 2
      nodeSet = @doc.createElement "mynode"
      cachedNode[params.altKeyword] = nodeSet
      cacheAdded = true
    
    if textNodeSet.invalidIteratorState || textNodeSet.snapshotLength is 0
      return false
    else
      #console.log targetNodeSet.tagName
      keywordLen = params.altKeyword.length
      index = 0
      while node = textNodeSet.snapshotItem(index++)
        if cacheAdded
          nodeSet.appendChild copyNode = node.cloneNode(false)
          copyNode.orgNode = node.orgNode || node
        [altContent, node, copyNode] = fnAltContent node, useCache, copyNode
        splited = altContent.split(params.altKeyword)
        content = node.textContent
        newContent = ""
        pos = 0
        for i in [0...splited.length]
          matched = escape content.substring(pos + splited[i].length, pos + splited[i].length + keywordLen)
          newContent += escape(content.substring(pos, pos + splited[i].length)) + (if i < (splited.length - 1) then """<esspan class="__esHilite">#{matched}</esspan>""" else "")
          pos += splited[i].length + keywordLen
        @appendResult node, newContent, splited.length - 1
  
  selectResult: (rsid) ->
    @lastSelect = @searchResults[rsid][0]
    @lastSelect.scrollIntoView "block": "center"
    [].forEach.call @lastSelect.getElementsByTagName("esspan"), (myhilite) ->
      myhilite.setAttribute "class", "__esSelect"
  
  selectFrame: (frameSrc, itemRect) ->
    if window is parent
      @iframeRects.forEach (iframeRect) ->
        if iframeRect[4] is frameSrc
          scrollLeft = itemRect[0] + iframeRect[0] - Math.round(window.innerWidth / 2) + Math.round(itemRect[2] / 2)
          scrollTop = itemRect[1] + iframeRect[1] - Math.round(window.innerHeight / 2) + Math.round(itemRect[3] / 2)
          document.scrollingElement.scrollLeft = scrollLeft
          document.scrollingElement.scrollTop = scrollTop
  
class WorkspacesBase extends Array

  uuid: null
  frameType: null
  frameSrc: null
  results: []
  activity: null
  
  constructor: (params) ->
    super()
    @uuid = @getUuid()
    
    if window is parent
      @frameType = "normal"
    else if window is window.top
      @frameType = "frameset"
    else if window.frameElement?.tagName is "FRAME"
      @frameType = "frame"
    else
      @frameType = "iframe"
      @frameSrc = window.location.href
    
    addDomChangeHandler()
  
  destroy: ->
    removeDomChangeHandler()
    @forEach (ws) ->
      ws.destroy()
      ws = null
    @activity = null
    @results = null
  
  run: ->
    unless @frameType is "frameset"
      @digDocument window
  
  getUuid: ->
    S4 = ->
      "g" + (((1+Math.random())*0x10000)|0).toString(16).substring(1)
    [S4(), S4(), S4(), S4()].join("")
  
  checkChangeDom: ->
    if isChangeDom
      @[0]?.textNodeSet = []
      @[0]?.digTextNode document.body
      isChangeDom = false
  
  checkChangeDomRT: ->
  
  beginDimLights: ->
    removeDomChangeHandler()
    @forEach (ws) ->
      ws.showShade hide: true
      ws.clearRectResults()
      ws.showShade()
    addDomChangeHandler()
  
  selectFrame: (message) ->
    @[0].selectFrame message.frameSrc, message.rect
  
  wsSelectResult: (result) ->
    rect = @[result.wsid].selectResult result.rsid
    if @frameType is "iframe"
      portPtoC.postMessage @addActivity
        action: "resSelectResult"
        rect: rect
  
  selectNextResult: (result, resMessage) ->
    if result
      @wsSelectResult result
    else
      @activity.selectId = NO_SELECTED
      portPtoC.postMessage
        action: resMessage
  
  selectResult: (message) ->
    @clearSelect()
    if @activity
      if message.selectId[0] is @uuid
        @wsSelectResult @results[@activity.selectId = message.selectId[1]]
      else
        @activity.selectId = NO_SELECTED
  
  selectNext: (message) ->
    @clearSelect()
    if message.frameId is @uuid
      @selectNextResult @results[++@activity.selectId], "selectNextFrame"
    else
      @activity.selectId = NO_SELECTED
  
  selectPrev: (message) ->
    @clearSelect()
    if message.frameId is @uuid
      if @activity.selectId is NO_SELECTED
        @activity.selectId = @results.length
      @selectNextResult @results[--@activity.selectId], "selectPrevFrame"
    else
      @activity.selectId = NO_SELECTED
  
  clearSelect: ->
    @forEach (ws) ->
      if ws.lastSelect
        [].forEach.call ws.lastSelect.getElementsByTagName("esspan"), (myselect) ->
          myselect.setAttribute "class", "__esHilite"
  
  clearResult: (options) ->
    removeDomChangeHandler()
    if @selectionAnchorNode
      @forEach (ws) =>
        ws.clearResult options, container = selectionAnchorNode: @selectionAnchorNode
        if container.result
          @selectionAnchorNode = container.result
    else
      @forEach (ws) ->
        ws.clearResult options
    @results = null
    @activity = null  
    addDomChangeHandler()
  
  showShade: (options) ->
    removeDomChangeHandler()
    @forEach (ws) ->
      ws.showShade options
    addDomChangeHandler()
  
  hideShade: ->
    @forEach (ws) ->
      ws.hideShade()
  
  removeShade: ->
    removeDomChangeHandler()
    @forEach (ws) ->
      ws.removeShade()
    addDomChangeHandler()
  
  addActivity: (message) ->
    resp =
      frameId:   @uuid
      frameType: @frameType
      frameSrc:  @frameSrc
      activity:  @activity
    for key of message
      resp[key] = message[key]
    resp
  
  digDocument: (win) ->
    ws = new Workspace win
    if ws.conflictFrame
      return
    @push ws
    if (iframes = win.document.getElementsByTagName("IFRAME"))?.length > 0
      [].forEach.call iframes, (iframe) =>
        try
          if iframe.contentWindow.document
            @digDocument iframe.contentWindow
        catch
  
  startSearch: (params) ->
    
    unless document.body
      return
    
    @clearResult unhide: true
    @activity = new Activity params
    if @selectionAnchorNode
      @removeShade()
      @showShade()
    else 
    if @activity.shade
      @showShade hide: true
    @checkChangeDom()
    @results = []
    workspaceId = 0
    
    try
      removeDomChangeHandler()
      
      @wsStartSearches params
      @forEach (ws) =>
        resultId = 0
        ws.searchResults.forEach (result) =>
          @results.push
            wsid: workspaceId
            rsid: resultId
            rs: result[0].innerHTML
          if @selectionAnchorNode
            if @selectionAnchorNode is result[1]
              @activity.selectId = resultId
          resultId++
        workspaceId++
        @activity.hits += ws.hits
        if @activity.hits > MAX_HITS
          throw EXCEPTION_OVERFLOW
    catch e
      if e is EXCEPTION_OVERFLOW
        @activity.hits = EXCEPTION_OVERFLOW
      else
        alert e.message
    finally
      @selectionAnchorNode = null
      addDomChangeHandler()
  
class SearchRegExp
  constructor: ->
    @wsStartSearches = (params) ->
      @forEach (ws) ->
        ws.startSearch params

class SearchRT
  constructor: ->
    @wsStartSearches = (params) ->
      @forEach (ws) =>
        ws.startSearchRT params, cachedNodeSet, (node, useCache, copyNode) ->
          if useCache
            altContent = node.textContent
            node = node.orgNode
          else
            altContent = TRANS_EXPR_TARGET_HIRA.evaluate(node, XPathResult.STRING_TYPE, null).stringValue
            copyNode?.textContent = altContent
          [altContent, node, copyNode]
    
    @startSearch = (params) ->
      
      unless document.body
        return
      
      textNode = document.createTextNode params.keyword
      params.altKeyword = TRANS_EXPR_TARGET_HIRA.evaluate(textNode, XPathResult.STRING_TYPE, null).stringValue
      if params.keyword.indexOf("'") > -1
        concatArgs = params.altKeyword.replace /'/g, "',\"'\",'"
        concatArgs = "'" + concatArgs.replace(/^,'/, "") + "'"
        params.xpath = "*//text()[not(parent::textarea|parent::script|parent::style|parent::noscript) and contains(#{XPATH_TRANS_TARGET_HIRA},concat(#{concatArgs}))]"
        params.xpath_usecache = "//text()[contains(.,concat(#{concatArgs}))]"
      else
        params.xpath = "*//text()[not(parent::textarea|parent::script|parent::style|parent::noscript) and contains(#{XPATH_TRANS_TARGET_HIRA},'#{params.altKeyword}')]"
        params.xpath_usecache = "//text()[contains(.,'#{params.altKeyword}')]"
      
      # @__proto__.startSearch.call @, params
      Object.getPrototypeOf(@).startSearch.call @, params

class SearchCsRT
  constructor: ->
    @wsStartSearches = (params) ->
      @forEach (ws) =>
        ws.startSearchRT params, cachedNodeSetCs, (node, useCache, copyNode) ->
          if useCache
            node = node.orgNode
          [node.textContent, node, copyNode]
    
    @startSearch = (params) ->
      
      unless document.body
        return
      
      params.altKeyword = params.keyword
      if params.keyword.indexOf("'") > -1
        concatArgs = params.keyword.replace /'/g, "',\"constructor'\",'"
        concatArgs = "'" + concatArgs.replace(/^,'/, "") + "'"
        params.xpath = "*//text()[not(parent::textarea|parent::script|parent::style|parent::noscript) and contains(.,concat(#{concatArgs}))]"  
        params.xpath_usecache = "//text()[contains(.,concat(#{concatArgs}))]"
      else
        params.xpath = "*//text()[not(parent::textarea|parent::script|parent::style|parent::noscript) and contains(.,'#{params.keyword}')]"  
        params.xpath_usecache = "//text()[contains(.,'#{params.keyword}')]"
      
      # @__proto__.startSearch.call @, params
      Object.getPrototypeOf(@).startSearch.call @, params

portPtoC = null
onMessageHandler = (message, sender, response) ->
  #console.log message
  switch message.action
    when "askLoadedScript"
      response "loaded"
    when "clearResult"
      workspaces.clearResult()
  true
chrome.runtime.onMessage.addListener onMessageHandler

onPortConnectHandler = (port) ->
  if (port.name is "PtoC")
    portPtoC = port
    portPtoC.onMessage.addListener onPortMessageHandler
    portPtoC.onDisconnect.addListener (event) ->
      portPtoC.onMessage.removeListener onPortMessageHandler
chrome.runtime.onConnect.addListener onPortConnectHandler

onWindowUnloadHandler = ->
  if (top = window.top)
    if (frames = top.document.getElementsByTagName("FRAME")).length > 0
      [].forEach.call frames, (frame) ->
        frame.contentWindow.destroy?()
    top.destroy?()
window.addEventListener "unload", onWindowUnloadHandler, false

clearFrames = (doc, tagName) ->
  if (frames = doc.getElementsByTagName(tagName)).length > 0
    [].forEach.call frames, (frame) ->
      frame.contentWindow.postMessage "clearResult", "*"

onWindowMessageHandler = (message) ->
  if message.data is "clearResult"
    workspaces.clearResult()
    clearFrames document, "IFRAME"
window.addEventListener "message", onWindowMessageHandler, false

onWindowKeydownHandler = (event) ->
  if event.key is "Escape"
    workspaces.clearResult()
    clearFrames document, "IFRAME"
    if (top = window.top)
      top.workspaces.clearResult()
      clearFrames top.document, "FRAME"
window.addEventListener "keydown", onWindowKeydownHandler, false

window.destroy = ->
  chrome.runtime.onConnect.removeListener onPortConnectHandler
  window.workspaces.destroy()
  window.workspaces = null
  window.removeEventListener "unload", onWindowUnloadHandler, false
  window.removeEventListener "message", onWindowMessageHandler, false
  window.removeEventListener "keydown", onWindowKeydownHandler, false

switchClass = (properties) ->
  if properties.regexp
    workspaces = searchRegExp
    isChangeDom = true
  else if properties.ignore
    workspaces = searchCsRT
  else
    workspaces = searchRT

onPortMessageHandler = (message) ->
  #console.log message
  switch message.action
    when "getActivity"
      if (range = window.getSelection()).type is "Range"
        selection = range.getRangeAt(0).toString()
        workspaces.selectionAnchorNode = range.anchorNode
      else
        selection = null
        workspaces.selectionAnchorNode = null
      portPtoC.postMessage workspaces.addActivity
        action: "resGetActivity"
        selection: selection
    when "sendProperties"
      switchClass message.properties
    when "startSearch"
      workspaces.startSearch message
      portPtoC.postMessage workspaces.addActivity
        action: "resStartSearch"
    when "getResults"
      portPtoC.postMessage workspaces.addActivity
        action: "resGetResults"
        results: workspaces.results
    when "startSearchRT"
      workspaces.startSearch message
      portPtoC.postMessage workspaces.addActivity
        action: "resStartSearchRT"
    when "clearResultRT"
      workspaces.clearResult()
      portPtoC.postMessage
        action: "resClearResultRT"
    when "selectResult"
      workspaces.selectResult message
    when "selectNext"
      workspaces.selectNext message
    when "selectPrev"
      workspaces.selectPrev message
    when "selectFrame"
      workspaces.selectFrame message
    when "clearSelect"
      workspaces.clearSelect()
      workspaces.activity.selectId = NO_SELECTED
    when "clearResult"
      workspaces.clearResult()
    when "showShade"
      workspaces.showShade()
    when "hideShade"
      workspaces.hideShade()
      unless message.hideOnly
        workspaces.activity?.shade = false
    when "beginDimLights"
      if workspaces.activity?.shade = true
        workspaces.beginDimLights()
  true

workspacesBase = new WorkspacesBase
workspaces = window.workspaces = workspacesBase

SearchRegExp.prototype = workspacesBase
searchRegExp = new SearchRegExp()

SearchRT.prototype = workspacesBase
searchRT = new SearchRT()

SearchCsRT.prototype = workspacesBase
searchCsRT = new SearchCsRT()

workspacesBase.run()
