EXCEPTION_OVERFLOW = -1
NO_SELECTED = -1

local = JSON.parse(localStorage.extSearch || null) || { shade: true }
checkItems = ["regexp", "ignore", "shade"]
activity = null
portPtoC = null
frames = []
frameSrc = {}
frameCount = 0
queryCount = 0
keyintimer = false

$$ = (selector) -> [document.querySelectorAll(selector)...]

$ = (elementOrSelector, fns...) ->
  [, objectType] = (/\[object\s(\w+)\]/.exec({}.toString.call(elementOrSelector)) || [null, null])
  elements = switch objectType
    when "String"
      [document.querySelectorAll(elementOrSelector)...]
    when "Array"
      elementOrSelector
    when "NodeList", "HTMLCollection"
      [elementOrSelector...]
    else # expect HTMLxxxElement
      [elementOrSelector]
  return elements[0] if fns.length is 0
  fns.forEach((fn) -> elements.forEach((el) -> fn(el)))
  elements[0]

addClass = (className) -> (el) -> el.classList.add className
removeClass = (classNames) -> (el) -> classNames.split(" ").forEach (className) -> el.classList.remove className
setClass = (className) -> (el) -> el.className = className
setAttribute = (prop, value) -> (el) -> el.setAttribute prop, value
removeAttribute = (prop) -> (el) -> el.removeAttribute prop
text = (content) -> (el) -> el.textContent = content
html = (content) -> (el) -> el.innerHTML = content
val = (value) -> (el) -> el.value = value
addListener = (eventName, listener) -> (el) -> el.addEventListener eventName, listener.bind(el)
focus = (el) -> el.focus()
select = (el) -> el.select()
show = (el) -> el.style.display = ""
hide = (el) -> el.style.display = "none"
toggle = (el) -> if el.offsetHeight > 0 then hide el else show el
toggleClass = (className) -> (el) -> if hasClass(el, className) then removeClass(className)(el) else addClass(className)(el)
method = (methodName, args...) -> (el) -> el[methodName](args...)

hasClass = (el, className) -> el.classList.contains className
isVisible = (selector) ->
  $$(selector).some (el) -> el.offsetHeight > 0

class Deferred
  constructor: ->
    @_state = "pending"
    @result = null
    @resultFailed = null
    @fn = null
    @fnFailed = null
    @innerDfd = null
  state: -> @_state
  promise: -> @
  done: (fn) ->
    if @state() is "resolved"
      fn @result
    else
      @fn = fn
      @innerDfd = new Deferred()
  resolve: (@result) ->
    @_state = "resolved"
    if @fn
      @innerDfd.resolve @fn(@result)
    @
  fail: (fnFailed) ->
    if @state() is "rejected"
      fnFailed @resultFailed
    else
      @fnFailed = fnFailed
      @
  reject: (@resultFailed) ->
    @_state = "rejected"
    if @fnFailed
      @fnFailed @resultFailed
    @

selectResult = (tdSelected) ->
  selectId = tdSelected.id.split("-")
  portPtoC.postMessage
    action: "selectResult"
    selectId: selectId
  if selectedParent = $("esspan.__esSelect")?.parentNode
    $ selectedParent.querySelectorAll("esspan"), setClass "__esHilite"
  activity.selectId = tdSelected.id
  $ tdSelected.querySelectorAll("esspan"), setClass "__esSelect"

dfdGetResults = null

showResult = ->
  dfdGetResults = new Deferred()
  portPtoC.postMessage
    action: "getResults"
  dfdGetResults.promise()

doneGetResults = (resp) ->
  if resp.results.length is 0
    return
  
  elResults = $ ".tabResults"
  if resp.frameType is "normal"
    targetAfter = elResults.querySelector("tr")
  for i in [0...resp.results.length]
    result = resp.results[i]
    if resp.frameType is "normal"
      elResults.insertBefore tr = document.createElement("tr"), targetAfter
    else
      elResults.appendChild tr = document.createElement "tr"
    tr.appendChild td = document.createElement "td"
    td.id = resp.frameId + "-" + i
    td.className = "result"
    td.innerHTML = result.rs
    td.addEventListener "click", ->
      selectResult @
      event.stopPropagation()
  
  unless resp.activity.selectId is NO_SELECTED 
    activity.selectId = resp.frameId + "-" + resp.activity.selectId
    tdSelected = $ "#" + activity.selectId, scrollIntoView
    $ tdSelected.getElementsByTagName("esspan"), setClass "__esSelect"
  
  dfdGetResults.resolve()

checkResult = (resp) ->
  if resp.activity
    if activity
      if resp.activity.hits is EXCEPTION_OVERFLOW || activity.hits is EXCEPTION_OVERFLOW
        activity.hits = EXCEPTION_OVERFLOW
      else
        activity.hits += resp.activity.hits
    else
      activity = resp.activity
    
    if resp.activity.selectId isnt NO_SELECTED
      activity.selectReason = "selected"
      activity.selectId = resp.frameId + "-" + resp.activity.selectId
    else if resp.frameType is "normal" && (!activity.selectReason || activity.selectReason is "firstHits") && resp.activity.hits > 0
      activity.selectReason = "topFrameHits"
      activity.selectId = resp.frameId + "-0"
    else if !activity.selectReason && resp.activity.hits > 0
      activity.selectReason = "firstHits"
      activity.selectId = resp.frameId + "-0"
    
    if resp.activity.hits > 0
      if resp.frameType is "frame"
        frames.push resp.frameId
      else
        frames.unshift resp.frameId
      frameSrc[resp.frameId] = resp.frameSrc
  
  disableUI false

setResultSummary = (options) ->
  if activity
    if activity.hits <= 0
      summary = $ ".summary",
        text if activity.hits is EXCEPTION_OVERFLOW then "Too many hits.(500over)" else "No hits"
        removeClass "matched"
      if hasClass(summary, "arrow-down") && !options.keepVisible
        hideResult()
    else
      summary = $ ".summary",
        text "Hits: #{activity.hits} or less "
        addClass "matched"
      if hasClass(summary, "arrow-down")
        return showResult()
  (new Deferred()).resolve()

checkSubmit = ->
  unless activity
    return true
  unless $(".keyword").value.trim() is activity.keyword &&
    local.ignore is activity.ignore &&
    local.regexp is activity.regexp
      return true
  false

checkRegexp = (keyword) ->
  returnFalse = (msg) ->
    clearResult()
    $ ".summary", text msg
    false
  try
    re = new RegExp keyword, "g"
  catch e
    return returnFalse "The regexp pattern is not supported. "
  true

hideResult = ->
  $ ".matched", removeClass "matched arrow-down"

clearResult = ->
  activity = null
  $ ".summary", text ""
  hideResult()
  $ ".tabResults", html ""

scrollIntoView = (elem) ->
  divResultsHalfH = Math.round((divResults = $(".results")).offsetHeight / 2)
  divResults.scrollTop = elem.offsetTop - divResultsHalfH + Math.round(elem.offsetHeight / 2)

disableUI = (disable = true) ->
  if disable
    $ "form, input, .icon-search", addClass "disabled"
    $ ".keyword", setAttribute "disabled", "disabled"
  else
    $ "form, input, .icon-search", removeClass "disabled"
    $ ".keyword", removeAttribute "disabled", focus

setCheckItems = (source) ->
  checkItems.forEach (className) ->
    if source[className]
      $ "." + className, addClass "checked"
    else
      $ "." + className, removeClass "checked"
    local[className] = hasClass $("." + className), "checked"
  
  if source.regexp
    $ ".regex", show
  else
    $ ".regex", hide

dfdInitialize  = new Deferred()
(dfdSearchQueue = new Deferred()).resolve()
dfdInSearchRT = null

startSearchRT = (input) ->
  dfdInitialize.done ->
    keyword = input.value.trim()
    unless checkSubmit()
      return
    if local.regexp
      return
    if keyword.length is 0 || (keyword.length is 1 && /[\x20-\x7F０-９ａ-ｚＡ-Ｚぁ-んァ-ン。、]/.test(keyword))
      $ ".formInput", addClass "searching"
      clearResult()
      portPtoC.postMessage action: "clearResultRT"
      return
    
    dfdSearchQueue = dfdSearchQueue.done ->
      $ ".summary", text "", removeClass "matched"
      $ ".formInput", addClass "searching"
      activity = null
      frames = []
      frameSrc = {}
      queryCount = 0
      $ ".tabResults", html ""
      message = Object.assign {}, local, action: "startSearchRT", keyword: keyword
      dfdInSearchRT = new Deferred()
      portPtoC.postMessage message
      dfdInSearchRT.promise()

startSearch = (input) ->
  if keyword = input.value.trim()
    unless checkSubmit()
      return
    unless checkRegexp keyword
      return
    dfdInitialize.done ->
      if keyword.length is 1 && /[\x20-\x7F０-９ａ-ｚＡ-Ｚぁ-んァ-ン。、]/.test(keyword)
        $ ".summary", text "2 or more char is required. "
        return
      # 開始
      $ ".summary", text "", removeClass "matched"
      $ ".ajax1", show
      activity = null
      frames = []
      frameSrc = {}
      queryCount = 0
      disableUI()
      $ ".tabResults", html ""
      message = Object.assign {}, local, action: "startSearch", keyword: keyword
      portPtoC.postMessage message

onPortMessageHandler = (message) ->
  #console.log message
  switch message.action
    when "resGetActivity"
      checkResult message
      setResultSummary()
      if message.selection
        fromSelectText = message.selection
        inputKeyword = $ ".keyword",
          val fromSelectText
          select
        if local.regexp
          local.regexp = false
          setCheckItems local
          portPtoC.postMessage
            action: "sendProperties"
            properties: local
        startSearchRT inputKeyword
      if message.activity
        setCheckItems message.activity
        keyword = fromSelectText || message.activity.keyword
        $ ".keyword",
          val keyword
          select
      else
        portPtoC.postMessage
          action: "sendProperties"
          properties: local
      frameCount++
      dfdInitialize.resolve()
    when "resStartSearch"
      checkResult message
      if ++queryCount is frameCount
        $ ".ajax1", hide
        $(".keyword").focus()
        if activity.hits > 0 && activity.shade
          portPtoC.postMessage
            action: "selectResult"
            selectId: activity.selectId.split "-"
          portPtoC.postMessage
            action: "showShade"
          local.keyword = $(".keyword").value
        else if activity.hits is EXCEPTION_OVERFLOW
          portPtoC.postMessage
            action: "showShade"
          portPtoC.postMessage
            action: "clearResult"
          hideResult()
        else
          portPtoC.postMessage
            action: "hideShade"
            hideOnly: true
        setResultSummary()
    when "resStartSearchRT"
      #console.log message
      checkResult message
      if ++queryCount is frameCount
        $ ".formInput", removeClass "searching"
        if activity.hits > 0
          local.keyword = $(".keyword").value
          if activity.shade
            portPtoC.postMessage
              action: "showShade"
          unless activity.selectId is NO_SELECTED
            portPtoC.postMessage
              action: "selectResult"
              selectId: activity.selectId.split "-"
        else if activity.hits is EXCEPTION_OVERFLOW
          portPtoC.postMessage
            action: "clearResult"
          hideResult()
        else
          portPtoC.postMessage
            action: "hideShade"
            hideOnly: true
        setResultSummary keepVisible: true
          .done ->
            activity.selectId = NO_SELECTED
            dfdInSearchRT.resolve()
    when "resClearResultRT"
      clearResult()
      $ "form.formInput", removeClass "searching"
    when "resGetResults"
      doneGetResults message
    when "selectNextFrame", "selectPrevFrame"
      if frameId = activity.selectFrameId
        index = frames.indexOf frameId
      else
        index = 0
      if message.action is "selectNextFrame"
        frameId = frames[++index] || frames[0]
        portPtoC.postMessage
          action: "selectNext"
          frameId: frameId
      else
        frameId = frames[--index] || frames[frames.length - 1]
        activity.selectId = frameId + "-0"
        portPtoC.postMessage
          action: "selectPrev"
          frameId: frameId
      activity.selectFrameId = frameId
    when "resSelectResult"
      portPtoC.postMessage
        action: "selectFrame"
        frameSrc: message.frameSrc
        rect: message.rect

onBodyKeydown = (event) ->
    if event.key is "Enter" && checkSubmit()
      return
    else if event.key in ["ArrowUp", "ArrowDown"] && !isVisible(".results") # up & down arrow
      if activity.hits > 0
        $ ".matched", addClass "arrow-down"
        if $(".tabResults").children.length is 0
          showResult()
    if event.key in ["Enter", "ArrowUp", "ArrowDown"] && activity.hits > 0
      if activity.selectId isnt NO_SELECTED && tdSelected = $ "#" + activity.selectId
        trSelected = tdSelected.parentNode
        if event.key is "ArrowUp" || (event.key is "Enter" && event.shiftKey)
          trNext = trSelected.previousSibling || trSelected.parentNode.lastElementChild
        else
          trNext = trSelected.nextSibling || trSelected.parentNode.firstElementChild
        next = trNext.firstElementChild
        scrollIntoView next
        selectResult next
      else
        unless activity.selectFrameId
          if activity.selectId is NO_SELECTED
            activity.selectId = frames[0] + "-0"
            activity.selectFrameId = frames[0]
          else
            activity.selectFrameId = activity.selectId.split("-")[0]
        if event.key is "ArrowUp" || (event.key is "Enter" && event.shiftKey)
          portPtoC.postMessage
            action: "selectPrev"
            frameId: activity.selectFrameId
            frameSrc: frameSrc[activity.selectFrameId]
        else
          portPtoC.postMessage
            action: "selectNext"
            frameId: activity.selectFrameId
            frameSrc: frameSrc[activity.selectFrameId]

onWindowUnload = ->
  unless (keyword = $(".keyword").value.trim()) is ""
    local.keyword = keyword
  localStorage.extSearch = JSON.stringify local
  portPtoC.disconnect()

loadScript = (tabId) ->
  chrome.tabs.sendMessage tabId, action: "askLoadedScript", (resp) ->
    if resp is "loaded"
      connect tabId
    else
      chrome.tabs.executeScript tabId,
        file: "lib/script.js"
        runAt: "document_end"
        allFrames: true
        (resp) ->
          if resp?.length > 0
            connect tabId
          else
            disableUI()
            $(".keyword").blur()

connect = (tabId) ->
  portPtoC = chrome.tabs.connect tabId, name: "PtoC"
  portPtoC.onMessage.addListener onPortMessageHandler
  portPtoC.postMessage
    action: "getActivity"

$ document, addListener "DOMContentLoaded", ->

  $ ".ajax1, .regex", hide

  $ ".formInput", addListener "submit", (event) -> event.preventDefault()

  $ ".submit", addListener "click", (event) ->
    if hasClass @, "disabled"
      return
    if local.regexp
      startSearch $ ".keyword"
    else
      startSearchRT $ ".keyword"
      $(".keyword").focus()
    if event.x isnt 0
      onBodyKeydown "key": "Enter"

  $ ".keyword",
    addListener "focus", ->
      $ ".formInput", addClass "focus"
    addListener "blur", ->
      clearTimeout(keyintimer)
      $ ".formInput", removeClass "focus"
    addListener "keydown", (e) ->
      keyintimer = setTimeout((=>
        startSearchRT @
      ), 0)
    val local.keyword || ""
    focus
    select
  
  $ ".clr, .icon-remove", addListener "click", (event) ->
    dfdInitialize.done =>
      portPtoC.postMessage
        action: "clearResult"
      clearResult()
      $(".keyword").focus()
      event.stopPropagation()
      if hasClass @, "icon-remove"
        onWindowUnload()
        window.close()
  
  $ ".ignore, .regexp, .shade", addListener "click", (event) ->
    checkItems.forEach (className) =>
      if hasClass @, className
        local[className] = !local[className]
    setCheckItems local
    
    if hasClass @, "shade"
      if local.shade
        portPtoC.postMessage
          action: "beginDimLights"
      else
        portPtoC.postMessage
          action: "hideShade"
    else # ignore or regexp
      portPtoC.postMessage
        action: "sendProperties"
        properties: local
    
    $(".keyword").focus()
    event.stopPropagation()
  
  $ ".summary", addListener "click", ->
    if not hasClass(@, "matched")
      return
    if hasClass(@, "arrow-down")
      $ @, removeClass "arrow-down"
    else
      $ @, addClass "arrow-down"
      if $(".tabResults").children.length is 0
        showResult()

  $ ".results", addListener "click", ->
      portPtoC.postMessage
        action: "clearSelect"
      $ "esspan.__esSelect", setClass "__esHilite"

  $ "body", addListener "keydown", onBodyKeydown

  $ window, addListener "unload", onWindowUnload
  
  setCheckItems local
  
  chrome.tabs.query
    currentWindow: true
    active: true
    ([tab]) ->
      if tab.status is "complete"
        loadScript tab.id
      else
        chrome.tabs.onUpdated.addListener (tabId, changeInfo, tab2) ->
          if changeInfo.status is "complete" and tabId is tab.id and tab2.windowId is tab.windowId
            loadScript tabId
