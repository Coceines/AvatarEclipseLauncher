-- Fullscreen loading screen. Holds the game entry while the server streams the
-- full world map once (right after login), then preloads the textures of the
-- items the map actually uses. The callback (the real game login) is fired
-- immediately so the map stream can start; the screen stays up until both the
-- map download and the texture preload finish.
--
-- Visuals: the APNG /data/images/Background2.png as the fullscreen animated
-- background (plays once and holds the last frame; falls back to a slideshow
-- of the /data/loadingimages photos with crossfade + slow zoom when the APNG
-- is missing), a radial vignette that fades the image into the black
-- background, and a single big progress bar (pure Lua panels, no progress-bar
-- style image, so it never gets "cut").
--
-- NOTE: preloading ALL ~19k thing type textures is disabled on purpose - the
-- 32-bit client runs out of memory (bad_alloc) with HD/xBRZ textures. Only the
-- item ids found on the downloaded map are preloaded (a few thousand, fits).

local loadingWindow
local loadingBar
local loadingBarFill
local loadingPercent
local loadingLabel
local slideA
local slideB
local animatedBG

local updateEvent
local slideEvent
local onFinished
local loginStarted = false
local loginStartedAt = 0
local preloadStarted = false

-- slideshow state
local slides = {}
local slideIdx = 1
local slidePhase = 'show'      -- 'show' | 'fade'
local slidePhaseStart = 0
local slideZoomStart = 0
local slideCurrent
local slidePending
local SHOW_MS = 7000
local FADE_MS = 1500
local ZOOM = 0.12

-- the bar animates toward the real progress for a buttery feel
local displayedPercent = 0

-- animated background (APNG, plays once and holds). Falls back to the
-- photo slideshow when the file is missing.
local ANIMATED_BG = '/data/images/Background2.png'
local animatedMode = false
local lastCoverW = 0
local lastCoverH = 0

local function ensureWindow()
  if loadingWindow then
    return
  end
  loadingWindow = g_ui.displayUI('loading')
  loadingBar = loadingWindow:getChildById('loadingBar')
  loadingBarFill = loadingBar:getChildById('loadingBarFill')
  loadingPercent = loadingBar:getChildById('loadingPercent')
  loadingLabel = loadingWindow:getChildById('loadingLabel')
  local slideshow = loadingWindow:getChildById('loadingSlideshow')
  slideA = slideshow:getChildById('slideA')
  slideB = slideshow:getChildById('slideB')
  animatedBG = loadingWindow:getChildById('loadingAnimated')
  loadingWindow:hide()
end

local function collectSlides()
  local list = {}
  local ok, files = pcall(function() return g_resources.listDirectoryFiles('/data/loadingimages') end)
  -- NOTE: the client texture loader only supports PNG/APNG, so only .png
  -- files are picked here (.jpg files in the folder are ignored)
  if ok and files then
    for _, name in ipairs(files) do
      if string.lower(name):match('%.png$') then
        table.insert(list, '/data/loadingimages/' .. name)
      end
    end
  end
  if #list == 0 then
    for _, name in ipairs({ 'appa.png', 'appa2.png', 'appa3.png', 'iroh.png', 'katara.png', 'Katara2.png', 'sokkadraw.png' }) do
      table.insert(list, '/data/loadingimages/' .. name)
    end
  end
  return list
end

-- scale an image to *cover* the whole screen (no motion; used for the APNG)
local function applyCover(widget)
  local tw = widget:getImageTextureWidth()
  local th = widget:getImageTextureHeight()
  local sw = g_window:getWidth()
  local sh = g_window:getHeight()
  if tw <= 0 or th <= 0 or sw <= 0 or sh <= 0 then
    return false
  end
  local cover = math.max(sw / tw, sh / th)
  local w = tw * cover
  local h = th * cover
  widget:setImageWidth(math.floor(w + 0.5))
  widget:setImageHeight(math.floor(h + 0.5))
  widget:setImageOffsetX(math.floor((sw - w) / 2 + 0.5))
  widget:setImageOffsetY(math.floor((sh - h) / 2 + 0.5))
  return true
end

local function applyCoverIfNeeded()
  if not animatedMode then
    return
  end
  local sw = g_window:getWidth()
  local sh = g_window:getHeight()
  if sw == lastCoverW and sh == lastCoverH then
    return
  end
  lastCoverW, lastCoverH = sw, sh
  applyCover(animatedBG)
end

-- scale the photo to *cover* the whole screen and slowly zoom/pan it
local function applySlideTransform(widget, progress)
  local tw = widget:getImageTextureWidth()
  local th = widget:getImageTextureHeight()
  local sw = g_window:getWidth()
  local sh = g_window:getHeight()
  if tw <= 0 or th <= 0 or sw <= 0 or sh <= 0 then
    return
  end
  if progress < 0 then progress = 0 elseif progress > 1 then progress = 1 end
  local cover = math.max(sw / tw, sh / th)
  local zoom = 1.0 + ZOOM * progress
  local w = tw * cover * zoom
  local h = th * cover * zoom
  local ox = (sw - w) / 2
  local oy = (sh - h) / 2
  -- gentle diagonal pan so the photo feels alive
  ox = ox - (w - sw) * 0.06 * progress
  oy = oy - (h - sh) * 0.06 * progress
  widget:setImageWidth(math.floor(w + 0.5))
  widget:setImageHeight(math.floor(h + 0.5))
  widget:setImageOffsetX(math.floor(ox + 0.5))
  widget:setImageOffsetY(math.floor(oy + 0.5))
end

local function slideshowTick()
  if #slides == 0 then
    return
  end
  local now = g_clock.millis()
  if slidePhase == 'show' then
    if now - slidePhaseStart >= SHOW_MS then
      -- start crossfading to the next photo
      slidePhase = 'fade'
      slidePhaseStart = now
      slideZoomStart = now
      slideIdx = slideIdx % #slides + 1
      slidePending:setImageSource(slides[slideIdx])
      slidePending:setOpacity(0)
      slidePending:raise()
      applySlideTransform(slidePending, 0)
      applySlideTransform(slideCurrent, 1)
      return
    end
    applySlideTransform(slideCurrent, (now - slideZoomStart) / SHOW_MS)
  else
    local k = (now - slidePhaseStart) / FADE_MS
    if k >= 1 then
      slidePending:setOpacity(1)
      slideCurrent:setOpacity(0)
      slideCurrent, slidePending = slidePending, slideCurrent
      slidePhase = 'show'
      slidePhaseStart = now
      applySlideTransform(slideCurrent, (now - slideZoomStart) / SHOW_MS)
      return
    end
    slidePending:setOpacity(k)
    slideCurrent:setOpacity(1 - k)
    applySlideTransform(slidePending, (now - slideZoomStart) / SHOW_MS)
    applySlideTransform(slideCurrent, 1)
  end
end

local function startSlideshow()
  slides = collectSlides()
  if #slides == 0 then
    return
  end
  slideIdx = 1
  slideCurrent = slideA
  slidePending = slideB
  -- preload every photo up front (they stay cached in g_textures) so each
  -- crossfade is instant and never hitches mid-login
  for i = 1, #slides do
    slidePending:setImageSource(slides[i])
  end
  slideCurrent:setImageSource(slides[1])
  slideCurrent:setOpacity(1)
  slideCurrent:raise()
  slidePending:setOpacity(0)
  local now = g_clock.millis()
  slidePhase = 'show'
  slidePhaseStart = now
  slideZoomStart = now
  applySlideTransform(slideCurrent, 0)
  if slideEvent then
    removeEvent(slideEvent)
    slideEvent = nil
  end
  slideEvent = cycleEvent(slideshowTick, 100)
end

local function stopSlideshow()
  if slideEvent then
    removeEvent(slideEvent)
    slideEvent = nil
  end
  if slideA then slideA:setOpacity(0) end
  if slideB then slideB:setOpacity(0) end
  slidePhase = 'show'
end

-- picks the background: the APNG (plays once and holds) when available,
-- otherwise the photo slideshow
local function setupBackground()
  animatedMode = false
  lastCoverW, lastCoverH = 0, 0
  if g_resources.fileExists(ANIMATED_BG) then
    animatedBG:setImageSource(ANIMATED_BG)
    animatedMode = animatedBG:getImageTextureWidth() > 0
  end
  if animatedMode then
    animatedBG:setImageAnimationLoops(1) -- play once, then hold the last frame
    applyCover(animatedBG)
    animatedBG:setOpacity(1)
    stopSlideshow()
  else
    animatedBG:setOpacity(0)
    startSlideshow()
  end
end

local function clamp(p)
  if p < 0 then p = 0 elseif p > 1 then p = 1 end
  return p
end

local function updateBar(p)
  displayedPercent = displayedPercent + (p - displayedPercent) * 0.35
  if math.abs(p - displayedPercent) < 0.002 then
    displayedPercent = p
  end
  local maxW = loadingBar:getWidth()
  if maxW > 0 then
    local w = math.floor(maxW * displayedPercent + 0.5)
    if w < 2 and p > 0 then w = 2 end
    loadingBarFill:setWidth(w)
  end
  loadingPercent:setText(string.format('%d%%', math.floor(displayedPercent * 100 + 0.5)))
end

local function setProgress(p, text)
  updateBar(clamp(p))
  loadingLabel:setText(text)
end

function hide()
  if updateEvent then
    removeEvent(updateEvent)
    updateEvent = nil
  end
  stopSlideshow()
  onFinished = nil
  loginStarted = false
  loginStartedAt = 0
  preloadStarted = false
  displayedPercent = 0
  if loadingWindow then
    loadingWindow:hide()
  end
end

local function update()
  if not loadingWindow or not loadingWindow:isVisible() then
    return
  end

  -- Kick the login off immediately so the server starts streaming the map.
  if not loginStarted then
    loginStarted = true
    loginStartedAt = g_clock.millis()
    setProgress(0, tr('Conectando ao servidor...'))
    local cb = onFinished
    onFinished = nil
    if cb then cb() end
    return
  end

  local now = g_clock.millis()
  applyCoverIfNeeded()

  -- true when nothing is left to wait for on the animated background (or when
  -- there is no APNG at all)
  local apngDone = not animatedMode or animatedBG:isImageAnimationFinished()

  -- login failed / cancelled (the login module shows its own error box)
  if not g_game.isLogging() and not g_game.isOnline() then
    hide()
    return
  end

  -- actively streaming the world map
  if g_game.isFullMapDownloading() then
    setProgress(clamp(g_game.getFullMapProgress()), tr('Baixando mapa do mundo...'))
    return
  end

  -- map download finished -> preload the textures the map actually uses
  if g_game.isFullMapDownloadDone() and not preloadStarted then
    preloadStarted = true
    setProgress(0, tr('Preparando texturas do mundo...'))
    g_game.preloadMapItems()
    return
  end

  -- texture preload in progress
  if preloadStarted and not g_things.isPreloadFinished() then
    setProgress(clamp(g_things.getPreloadProgress()), tr('Preparando texturas do mundo...'))
    return
  end

  -- everything loaded, just waiting for the intro animation to finish
  if g_game.isFullMapDownloadDone() and g_things.isPreloadFinished() and not apngDone then
    setProgress(1, tr('Entrando no jogo...'))
    return
  end

  -- map downloaded, textures ready and the APNG has played at least once ->
  -- enter the game (the intro is never cut mid-animation)
  if g_game.isFullMapDownloadDone() and g_things.isPreloadFinished() and apngDone then
    hide()
    return
  end

  -- safety: a download that never announced itself (server without the feature)
  -- must not hold the player forever - but it still waits for the animation
  if g_game.isOnline() and now - loginStartedAt > 3000 and apngDone then
    hide()
    return
  end

  -- absolute cap: never hold the player forever (broken APNG that never
  -- reports finished, or an extremely long animation)
  if now - loginStartedAt > 90000 then
    hide()
    return
  end

  setProgress(1, tr('Conectando ao servidor...'))
end

local function hideOnLoginError()
  hide()
end

function init()
  -- Window is created lazily on first show() to avoid any style/load-order issues.
  connect(g_game, { onLoginError = hideOnLoginError })
  connect(g_game, { onConnectionError = hideOnLoginError })
end

function terminate()
  disconnect(g_game, { onLoginError = hideOnLoginError })
  disconnect(g_game, { onConnectionError = hideOnLoginError })
  if updateEvent then
    removeEvent(updateEvent)
    updateEvent = nil
  end
  stopSlideshow()
  onFinished = nil
  loginStarted = false
  loginStartedAt = 0
  preloadStarted = false
  if loadingWindow then
    loadingWindow:destroy()
    loadingWindow = nil
  end
end

-- Shows the loading screen. The callback (the real login) is fired right away
-- so the map stream starts; the screen stays up until the full world map has
-- been downloaded and its textures preloaded.
function show(callback)
  -- option "disableLoadingScreen": skip the fullscreen loading screen and
  -- enter the game directly (the world map is streamed normally).
  if modules.client_options and modules.client_options.getOption
     and modules.client_options.getOption('disableLoadingScreen') then
    if callback then callback() end
    return
  end

  ensureWindow()
  onFinished = callback
  loginStarted = false
  loginStartedAt = 0
  preloadStarted = false
  displayedPercent = 0

  setupBackground()
  setProgress(0, tr('Carregando...'))
  loadingWindow:show()
  loadingWindow:raise()
  loadingWindow:focus()

  if updateEvent then
    removeEvent(updateEvent)
    updateEvent = nil
  end
  updateEvent = cycleEvent(update, 50)
end

function isVisible()
  return loadingWindow and loadingWindow:isVisible()
end
