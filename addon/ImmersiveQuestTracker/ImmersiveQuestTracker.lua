local trackerAddon = "EllesmereUIQuestTracker"
local eui = EllesmereUI
local namespace = eui and eui._ModuleNS and eui._ModuleNS[trackerAddon]
local tracker = namespace and namespace.EQT
local mergeHeadersSetting = "immersiveQuestTrackerMergeHeaders"
local borderSetting = "immersiveQuestTrackerBorder"
local borderStyleSetting = "immersiveQuestTrackerBorderStyle"
local borderWidthSetting = "immersiveQuestTrackerBorderWidth"
local borderOffsetSetting = "immersiveQuestTrackerBorderOffset"
local customHeaderSpace = 0

local borderStyles = {
  bronze = { file = "Interface\\Tooltips\\UI-Tooltip-Border", color = { 0.68, 0.52, 0.34, 0.9 } },
  silver = { file = "Interface\\DialogFrame\\UI-DialogBox-Border", color = { 1, 1, 1, 0.9 } },
  gold = { file = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", color = { 1, 1, 1, 0.9 } },
}

local stockAppearance = {
  hideAllObjectivesHeader = false,
  skinHeaders = false,
  filterHeaderToggle = false,
}

local function RestorePreviewProfiles()
  local profiles = EllesmereUIDB and EllesmereUIDB.profiles
  if type(profiles) ~= "table" then return end

  -- Version 0.1.0 stored a preset in EUI's profiles. Restore only the
  -- values that still match what that version wrote.
  local preview = {
    useBlizzardStyle = true,
    useClassicStyle = false,
    customTrackerPick = false,
    hideAllObjectivesHeader = false,
    skinHeaders = false,
    filterHeaderToggle = false,
  }
  for _, profile in pairs(profiles) do
    local addonProfile = type(profile) == "table" and type(profile.addons) == "table"
        and profile.addons[trackerAddon]
    local config = type(addonProfile) == "table" and addonProfile.questTracker
    local original = type(config) == "table" and config.immersiveQuestTrackerOriginal
    if type(original) == "table" then
      for key, value in pairs(preview) do
        local previous = original[key]
        if type(previous) == "table" and config[key] == value then
          local oldValue = previous.value
          if oldValue == nil or type(oldValue) == "boolean" then
            config[key] = oldValue
          end
        end
      end
      config.immersiveQuestTrackerOriginal = nil
    end
  end
end

local function DefaultToQuestLog()
  local defaults = namespace.QT_DEFAULTS
  local config = defaults and defaults.profile and defaults.profile.questTracker
  if not config or config.customClickAction ~= "collapse" then return end

  -- EUI uses its secure quest tracker button for the Open Quest Log action.
  config.customClickAction = "map"

  local db = EllesmereUIDB
  if not db or type(db.profiles) ~= "table" or db.immersiveQuestTrackerQuestClickMigrated then return end
  for _, profile in pairs(db.profiles) do
    local addonProfile = type(profile) == "table" and type(profile.addons) == "table"
        and profile.addons[trackerAddon]
    local saved = type(addonProfile) == "table" and addonProfile.questTracker
    if type(saved) == "table" and saved.customClickAction == "collapse" then
      saved.customClickAction = "map"
    end
  end
  db.immersiveQuestTrackerQuestClickMigrated = true
end

local function RestoreTextureSnap(texture)
  if not texture or texture:IsForbidden() or texture:IsSnappingToPixelGrid() then return end
  texture:SetTexelSnappingBias(0.3)
  texture:SetSnapToPixelGrid(true)
end

local function KeepStockQuestIcons()
  local frame = ObjectiveTrackerFrame
  if not frame or type(frame.Update) ~= "function" then return end

  local queued = false
  hooksecurefunc(frame, "Update", function()
    if queued then return end
    queued = true
    -- EUI disables snapping when any texture gets an atlas. Restore the
    -- native POI art after Blizzard's layout finishes and its buttons exist.
    C_Timer.After(0, function()
      queued = false
      for _, module in ipairs(frame.modules or {}) do
        for _, blocks in pairs(module.usedBlocks or {}) do
          for _, block in pairs(blocks) do
            local button = block.poiButton
            if button and not button:IsForbidden() then
              RestoreTextureSnap(button.NormalTexture)
              RestoreTextureSnap(button.PushedTexture)
              RestoreTextureSnap(button.HighlightTexture)
              RestoreTextureSnap(button.Glow)
              RestoreTextureSnap(button.Display and button.Display.Icon)
            end
          end
        end
      end
    end)
  end)
end

local function AddStockHeader(frame, controller, template, label, offset)
  local header = CreateFrame("Frame", nil, frame, template)
  header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -offset)
  header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -offset)
  header:SetFrameLevel(controller:GetFrameLevel() + 1)
  header.Text:SetText(label)
  header.Text:SetAlpha(1)
  header.Text:Show()
  local button = header.MinimizeButton
  button:SetScript("OnClick", function() controller:Click() end)
  local background = header.Background
  if template == "ObjectiveTrackerContainerHeaderTemplate" then
    local atlas = C_Texture.GetAtlasInfo("ui-questtracker-primary-objective-header")
    local file = atlas and (atlas.file or atlas.filename)
    if file then
      -- Crop the uneven padding around the two trim lines, leaving room for their end caps.
      local left, right = atlas.leftTexCoord, atlas.rightTexCoord
      local span = right - left
      background:SetTexture(file)
      background:SetTexCoord(left + span * 0.025, right - span * 0.052,
          atlas.topTexCoord, atlas.bottomTexCoord)
    end
  end
  background:ClearAllPoints()
  background:SetPoint("LEFT", header, "LEFT")
  background:SetPoint("RIGHT", header, "RIGHT")
  RestoreTextureSnap(background)
  RestoreTextureSnap(button:GetHighlightTexture())
  return header
end

local function GetBorderGeometry(frame, config)
  local offset = math.max(-6, math.min(16, tonumber(config[borderOffsetSetting]) or 0))
  local width = math.max(2, math.min(24, tonumber(config[borderWidthSetting]) or 12))
  -- Leave room for two bottom corners across the width and one along the height.
  local maxWidth = math.floor(math.min((frame:GetWidth() + 2 * offset - 1) / 2, frame:GetHeight() + offset - 1))
  return math.min(width, math.max(1, maxWidth)), offset
end

local function KeepHeaderButtonsVisible(frame, main, section)
  local inset
  local function Adjust()
    local right, screenRight = frame:GetRight(), UIParent:GetRight()
    if not (right and screenRight) then return end
    local scale = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
    local overflow = math.max(0, right - screenRight * scale)
    if overflow >= frame:GetWidth() - 20 then return end
    local newInset = overflow
    local config = tracker.DB()
    if config[borderSetting] == true then
      local width, offset = GetBorderGeometry(frame, config)
      newInset = newInset + math.max(0, math.ceil(width / 2) - offset)
    end
    if newInset == inset then return end
    inset = newInset
    main.MinimizeButton:SetPoint("RIGHT", main, "RIGHT", -1 - inset, 0)
    section.MinimizeButton:SetPoint("RIGHT", section, "RIGHT", 1 - inset, 0)
  end
  hooksecurefunc(frame, "SetPoint", Adjust)
  frame:HookScript("OnSizeChanged", Adjust)
  if type(tracker.ApplyBackground) == "function" then
    hooksecurefunc(tracker, "ApplyBackground", Adjust)
  end
  Adjust()
end

local function CenterHeaderMinus(button)
  local atlas = C_Texture.GetAtlasInfo("ui-questtrackerbutton-collapse-all")
  local file = atlas and (atlas.file or atlas.filename)
  if not file then return end

  -- The mark and its shadow are baked into the lower half of the face.
  -- Replace just that part of the face and redraw the mark at its center.
  local left, right = 0.21, 0.79
  local markTop, markBottom, lift = 0.42, 0.76, 0.14
  local u, v = atlas.leftTexCoord, atlas.topTexCoord
  local widthUV, heightUV = atlas.rightTexCoord - u, atlas.bottomTexCoord - v
  local function AddSlice(layer, sourceTop, sourceBottom, top)
    local slice = button:CreateTexture(nil, "OVERLAY", nil, layer)
    slice:SetTexture(file)
    slice:SetTexCoord(u + widthUV * left, u + widthUV * right,
        v + heightUV * sourceTop, v + heightUV * sourceBottom)
    slice:SetPoint("TOPLEFT", button:GetNormalTexture(), "TOPLEFT", atlas.width * left, -atlas.height * top)
    slice:SetSize(atlas.width * (right - left), atlas.height * (markBottom - markTop))
    RestoreTextureSnap(slice)
    return slice
  end
  local face = AddSlice(0, 0.20, 0.40, markTop)
  local mark = AddSlice(1, markTop, markBottom, markTop - lift)

  local expanded = true
  local function SetShown(shown)
    face:SetShown(shown)
    mark:SetShown(shown)
  end
  button:HookScript("OnMouseDown", function(_, key)
    if key == "LeftButton" then SetShown(false) end
  end)
  button:HookScript("OnMouseUp", function() SetShown(expanded) end)
  button:HookScript("OnLeave", function() SetShown(expanded) end)
  return function(collapsed)
    expanded = not collapsed
    SetShown(expanded)
  end
end

local function PadZoneRow(row, height)
  if row.kind ~= "zone" or row.id == "@recipes" or not height or height <= 0
      or not row.lastText or row.lastText:sub(1, 2) == "+ " then return false end
  row.lastH = height + 8
  row:SetHeight(row.lastH)
  return true
end

local function StyleCompletedRow(row, useStockColor)
  if not row:IsShown() or type(row.id) ~= "number" or row.id <= 0 then return end
  if row.kind == "quest" and useStockColor and C_QuestLog.IsComplete(row.id) then
    local r, g, b
    if tracker.TitleDifficultyOn() then r, g, b = tracker.QuestDifficultyRGB(row.id) end
    local color = OBJECTIVE_TRACKER_COLOR.Header
    row.text:SetTextColor(r or color.r, g or color.g, b or color.b)
  elseif row.kind == "obj" and not row.key then
    if not C_QuestLog.IsComplete(row.id) then return end
    local index = C_QuestLog.GetLogIndexForQuestID(row.id)
    local completionText = index and GetQuestLogCompletionText(index)
    if completionText and row.text:GetText() == "- " .. completionText then
      row.text:SetText(completionText)
    end
    local r, g, b = row.text:GetTextColor()
    if useStockColor and math.abs(r - 0.251) < 0.002 and g == 1 and math.abs(b - 0.349) < 0.002 then
      local color = OBJECTIVE_TRACKER_COLOR.Normal
      row.text:SetTextColor(color.r, color.g, color.b)
    end
  end
end

local function SkinCustomBorder(frame, header)
  local holder, topLine = frame.bgHolder, frame.topLine
  if not (holder and topLine and type(tracker.ApplyBackground) == "function") then return end

  -- Parent the border to EUI's background holder so it inherits the hover fade.
  local headerBackground = header.Background
  local border, appliedStyle, appliedWidth, appliedOffset
  local topLineAlpha = topLine:GetAlpha()
  local function UpdateBorder()
    local config = tracker.DB()
    if config[borderSetting] ~= true then
      if appliedOffset ~= nil then
        border:Hide()
        headerBackground:SetPoint("LEFT", header, "LEFT", 0, 0)
        headerBackground:SetPoint("RIGHT", header, "RIGHT", 0, 0)
        topLine:SetAlpha(topLineAlpha)
        appliedOffset = nil
      end
      return
    end

    if not border then border = CreateFrame("Frame", nil, holder, "BackdropTemplate") end
    local style = borderStyles[config[borderStyleSetting]] or borderStyles.bronze
    local width, offset = GetBorderGeometry(frame, config)
    if offset ~= appliedOffset or width ~= appliedWidth then
      -- The side textures start directly below the hidden top corners.
      border:SetPoint("TOPLEFT", holder, "TOPLEFT", -offset, width)
      border:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", offset, -offset)
    end
    if offset ~= appliedOffset then
      local overhang = math.max(0, offset) + 4
      headerBackground:SetPoint("LEFT", header, "LEFT", -overhang, 0)
      headerBackground:SetPoint("RIGHT", header, "RIGHT", overhang, 0)
    end
    if style ~= appliedStyle or width ~= appliedWidth then
      border:SetBackdrop({ edgeFile = style.file, edgeSize = width })
      border:SetBackdropBorderColor(unpack(style.color))
      border.TopEdge:Hide()
      border.TopLeftCorner:Hide()
      border.TopRightCorner:Hide()
    end
    appliedStyle, appliedWidth, appliedOffset = style, width, offset
    border:Show()
    topLine:SetAlpha(0)
  end
  hooksecurefunc(tracker, "ApplyBackground", UpdateBorder)
  frame:HookScript("OnSizeChanged", UpdateBorder)
  UpdateBorder()
end

local function FadeQuestListBottom(scroll)
  local gradient = CreateVector2D(0, 0)
  local fadeLength = 0
  scroll:SetFlattensRenderLayers(true)
  scroll:SetAlphaGradient(0, gradient)
  scroll:SetAlphaGradient(1, gradient)

  local function UpdateFade()
    local remaining = scroll:GetVerticalScrollRange() - scroll:GetVerticalScroll()
    -- Taper the fade as the last rows come fully into view.
    local length = math.max(0, math.min(24, scroll:GetHeight() / 4, remaining))
    if length == fadeLength then return end
    fadeLength = length
    gradient:SetXY(0, length)
    scroll:SetAlphaGradient(1, gradient)
  end

  scroll:HookScript("OnVerticalScroll", UpdateFade)
  scroll:HookScript("OnScrollRangeChanged", UpdateFade)
  scroll:HookScript("OnSizeChanged", UpdateFade)
  UpdateFade()
end

local function SkinCustomFrame(frame)
  if not frame then return end
  local scroll, controller
  for _, child in ipairs({ frame:GetChildren() }) do
    if child:IsObjectType("ScrollFrame") then
      scroll = child
    elseif child:IsObjectType("Button") and child.text and child.toggle and child.count then
      controller = child
    end
  end
  if not (scroll and controller) then return end

  -- Stock Forever reserves 38 units for the main header and starts the
  -- rows 10 units below the 26-unit Quests header.
  local originalHeaderHeight = controller:GetHeight()
  local sectionOffset = 38
  local separateContentOffset = sectionOffset + 26 + 10
  local main = AddStockHeader(frame, controller, "ObjectiveTrackerContainerHeaderTemplate",
      TRACKER_ALL_OBJECTIVES, 0)
  SkinCustomBorder(frame, main)
  local section = AddStockHeader(frame, controller, "ObjectiveTrackerModuleHeaderTemplate",
      TRACKER_HEADER_QUESTS, sectionOffset)
  KeepHeaderButtonsVisible(frame, main, section)
  local SetCollapsedMinus = CenterHeaderMinus(main.MinimizeButton)
  controller:SetHeight(main:GetHeight())
  controller.text:SetAlpha(0)
  controller.toggle:SetAlpha(0)
  controller.count:SetAlpha(0)
  local count = main:CreateFontString(nil, "OVERLAY", "ObjectiveTrackerHeaderFont")
  count:SetPoint("RIGHT", main.MinimizeButton, "LEFT", -5, 0)
  count:SetJustifyH("RIGHT")
  main.Text:SetPoint("RIGHT", count, "LEFT", -8, 0)
  local headerLabels = { main.Text, section.Text, count }
  local function UpdateCount()
    count:SetText(controller.count:GetText())
  end
  hooksecurefunc(controller.count, "SetText", UpdateCount)
  UpdateCount()

  local function UpdateHeaderColor()
    -- The hidden EUI label can report zero alpha. The replacement labels
    -- take their color from the existing setting and stay fully opaque.
    local r, g, b = tracker.GetHeaderRGB()
    for _, label in ipairs(headerLabels) do label:SetTextColor(r, g, b, 1) end
  end
  local function UpdateHeaderFont()
    local face, size, flags = controller.text:GetFont()
    if not face then return end
    local selected = tracker.Cfg("font")
    local entry = eui.GetModuleFontEntry and eui.GetModuleFontEntry("questTracker")
    local customOutline = entry and entry.outline and entry.outline ~= "__global"
    local defaultSize = (tracker.Cfg("headerFontSize") or 13) == 13
    local stockFace, stockSize = ObjectiveTrackerHeaderFont:GetFont()
    for _, label in ipairs(headerLabels) do
      if (not selected or selected == "__global") and defaultSize and not customOutline then
        label:SetFontObject(ObjectiveTrackerHeaderFont)
      else
        local shadow = eui.GetFontUseShadow("questTracker")
        local headerFace = (not selected or selected == "__global") and stockFace or face
        eui.SetFontFamily(label, headerFace, defaultSize and stockSize or size, flags, shadow)
      end
    end
    count:SetJustifyH("RIGHT")
    UpdateHeaderColor()
  end
  hooksecurefunc(controller.text, "SetFont", UpdateHeaderFont)
  hooksecurefunc(controller.text, "SetTextColor", UpdateHeaderColor)
  UpdateHeaderFont()

  local _, relative, relativePoint, left = scroll:GetPoint(1)
  local showWidgetTooltip = eui.ShowWidgetTooltip
  eui.ShowWidgetTooltip = function(owner, label, ...)
    if owner and owner.GetParent and (label == SUPER_TRACK_QUEST or label == STOP_SUPER_TRACK_QUEST) then
      local row = owner:GetParent()
      if row and row.focus == owner and row:GetParent() == scroll:GetScrollChild() then return end
    end
    return showWidgetTooltip(owner, label, ...)
  end

  local contentOffset, wasMerged, wasCollapsed
  local function UpdateHeaders()
    local merged = tracker.Cfg(mergeHeadersSetting) == true
    local collapsed = controller.toggle:GetText() == "+"
    if merged == wasMerged and collapsed == wasCollapsed then return end
    if merged ~= wasMerged then
      wasMerged = merged
      main.Text:SetText(merged and TRACKER_HEADER_QUESTS or TRACKER_ALL_OBJECTIVES)
      contentOffset = merged and sectionOffset or separateContentOffset
      customHeaderSpace = contentOffset - originalHeaderHeight
      scroll:SetPoint("TOPLEFT", relative, relativePoint, left, -contentOffset)
    end
    section:SetShown(not merged and not collapsed)
    if collapsed == wasCollapsed then return end
    wasCollapsed = collapsed
    main:SetCollapsed(collapsed)
    if SetCollapsedMinus then SetCollapsedMinus(collapsed) end
    for _, header in ipairs({ main, section }) do
      local button = header.MinimizeButton
      RestoreTextureSnap(button:GetNormalTexture())
      RestoreTextureSnap(button:GetPushedTexture())
    end
  end
  hooksecurefunc(controller.toggle, "SetText", UpdateHeaders)
  UpdateHeaders()
  FadeQuestListBottom(scroll)

  local queued, applyingHeight = false, false
  local zoneRows = {}
  hooksecurefunc(frame, "SetHeight", function(_, height)
    if applyingHeight then return end
    local headerHeight = wasCollapsed and main:GetHeight() or contentOffset
    if not eui._unlockActive then
      applyingHeight = true
      frame:SetHeight(height + headerHeight - originalHeaderHeight)
      applyingHeight = false
    end
    if queued then return end
    queued = true
    C_Timer.After(0, function()
      queued = false
      local content = scroll:GetScrollChild()
      if not content then return end
      local config = tracker.DB()
      local useStockCompleted = config.completedR == 0.251 and config.completedG == 1
          and config.completedB == 0.349
      local refreshLayout = false
      for _, row in ipairs({ content:GetChildren() }) do
        if row.kind == "zone" and row:IsShown() and not zoneRows[row] then
          zoneRows[row] = true
          -- EUI lays out each next row using the height cached by SetSize.
          hooksecurefunc(row, "SetSize", function(line, _, height) PadZoneRow(line, height) end)
          refreshLayout = PadZoneRow(row, row.lastH) or refreshLayout
        end
        StyleCompletedRow(row, useStockCompleted)
        local button = row.focus
        if button and button:IsShown() and row:IsShown() then
          local _, _, _, x, y = button:GetPoint(1)
          if x ~= -7 or y ~= 5 then
            button:SetSize(20, 20)
            button.ring:SetSize(32, 32)
            button.icon:SetSize(32, 32)
            button:ClearAllPoints()
            button:SetPoint("TOPRIGHT", row, "TOPLEFT", -7, 5)
          end
          if button.ring:GetAtlas() == "UI-QuestIcon-TurnIn-Normal" then
            button.ring:SetAtlas(button.lastFocused and "UI-QuestPoi-QuestNumber-SuperTracked"
                or "UI-QuestPoi-QuestNumber")
            button.icon:SetAtlas("UI-QuestIcon-TurnIn-Normal", true)
            button.icon:Show()
          end
          button.glow:SetAlpha(0)
          button.hl:SetAlpha(0)
          RestoreTextureSnap(button.ring)
          RestoreTextureSnap(button.icon)
        end
      end
      if refreshLayout then tracker.RefreshCustom() end
    end)
  end)
end

local function SkinCustomTracker()
  local defaults = namespace.QT_DEFAULTS
  local config = defaults and defaults.profile and defaults.profile.questTracker
  if config then
    config[mergeHeadersSetting] = false
    config[borderSetting] = false
    config[borderStyleSetting] = "bronze"
    config[borderWidthSetting] = 12
    config[borderOffsetSetting] = 0
  end

  local getFont = tracker.GetFont
  tracker.GetFont = function()
    local selected = tracker.Cfg("font")
    if (not selected or selected == "__global") and ObjectiveTrackerLineFont then
      local face = ObjectiveTrackerLineFont:GetFont()
      if face then return face end
    end
    return getFont()
  end

  -- The stock tracker uses a drop shadow. Keep an explicitly selected
  -- module outline and avoid inheriting the rest of EUI's global outline.
  local function UseStockOutline(addonKey)
    if addonKey ~= "questTracker" or not namespace.UseCustomTracker() then return false end
    local entry = eui.GetModuleFontEntry and eui.GetModuleFontEntry(addonKey)
    return not (entry and entry.outline and entry.outline ~= "__global")
  end
  if type(eui.GetFontOutlineFlag) == "function" and type(eui.GetFontUseShadow) == "function" then
    local getOutline, getShadow = eui.GetFontOutlineFlag, eui.GetFontUseShadow
    eui.GetFontOutlineFlag = function(addonKey)
      if UseStockOutline(addonKey) then return "" end
      return getOutline(addonKey)
    end
    eui.GetFontUseShadow = function(addonKey)
      if UseStockOutline(addonKey) then return true end
      return getShadow(addonKey)
    end
  end

  local getHeaderColor = tracker.GetHeaderRGB
  tracker.GetHeaderRGB = function()
    local config = tracker.DB()
    if config.headerUseAccent == nil and not config.headerShowClassColor and NORMAL_FONT_COLOR then
      return NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b
    end
    return getHeaderColor()
  end

  if type(tracker.GetFocusRGB) == "function" and type(tracker.QuestDifficultyRGB) == "function"
      and type(tracker.TitleDifficultyOn) == "function" then
    local getFocusColor = tracker.GetFocusRGB
    tracker.GetFocusRGB = function()
      local r, g, b = getFocusColor()
      -- Substitute the stock title color for EUI's default purple, with
      -- the native quest marker still showing which quest is focused.
      if r == 0.871 and g == 0.251 and b == 1 then
        if tracker.TitleDifficultyOn() then
          local red, green, blue = tracker.QuestDifficultyRGB(C_SuperTrack.GetSuperTrackedQuestID())
          if red then return red, green, blue end
        end
        if OBJECTIVE_TRACKER_COLOR and OBJECTIVE_TRACKER_COLOR.Header then
          local color = OBJECTIVE_TRACKER_COLOR.Header
          return color.r, color.g, color.b
        end
      end
      return r, g, b
    end
  end

  hooksecurefunc(tracker, "InitCustom", function()
    SkinCustomFrame(EUI_CustomQuestTracker)
  end)
end

local detailsColors = {
  shell = { 0.110, 0.086, 0.064 },
  body = { 0.077, 0.060, 0.047 },
  edge = { 0.48, 0.35, 0.22 },
  gold = { 1, 0.81, 0.47 },
  text = { 0.97, 0.93, 0.86 },
  secondary = { 0.82, 0.75, 0.66 },
}

local function SkinDetailsButton(button)
  for _, region in ipairs({ button:GetRegions() }) do
    if region:IsObjectType("Texture") then region:Hide() end
  end
  for _, decoration in ipairs({ button:GetChildren() }) do decoration:Hide() end

  -- Use the stock gold-border button art on EUI's existing action buttons.
  local art = "Interface\\Common\\dark-goldframe-button"
  button:SetNormalTexture(art)
  button:SetDisabledTexture(art)
  button:SetPushedTexture(art .. "-pressed")
  button:SetHighlightTexture("Interface\\Buttons\\UI-Silver-Button-Highlight", "ADD")
  local highlight = button:GetHighlightTexture()
  highlight:SetTexCoord(0, 1, 0.03, 0.7175)
  highlight:SetVertexColor(0.92, 0.69, 0.40, 0.3)
  button:GetDisabledTexture():SetVertexColor(0.75, 0.73, 0.70)

  local function SetLabelColor() button.label:SetTextColor(unpack(detailsColors.text)) end
  button:HookScript("OnLeave", SetLabelColor)
  SetLabelColor()
end

local function BrightenDifficultyColor(alpha, red, green, blue)
  local r, g, b = tonumber(red, 16), tonumber(green, 16), tonumber(blue, 16)
  local brightness = 0.2126 * r + 0.7152 * g + 0.0722 * b
  if brightness >= 160 then return end
  local mix = (160 - brightness) / (255 - brightness)
  return ("|c%s%02x%02x%02x"):format(alpha, math.floor(r + (255 - r) * mix + 0.5),
      math.floor(g + (255 - g) * mix + 0.5), math.floor(b + (255 - b) * mix + 0.5))
end

local function SkinDetailsContents(content, meta)
  local rewardTiles = {}
  local function SetRewardBorder(tile, hovered)
    tile.frame:SetColor(0.64, 0.45, 0.24, hovered and 1 or 0.6)
  end

  local function Refresh()
    local subtitle = meta and meta:GetText()
    if subtitle then
      local brighter = subtitle:gsub("|c(%x%x)(%x%x)(%x%x)(%x%x)", BrightenDifficultyColor)
      if brighter ~= subtitle then meta:SetText(brighter) end
    end

    for _, region in ipairs({ content:GetRegions() }) do
      if region:IsShown() then
        if region:IsObjectType("FontString") then
          local _, size = region:GetFont()
          local _, green = region:GetTextColor()
          local dim = math.abs(green - eui.TEXT_DIM.g) < 0.01
          -- EUI uses 11-point text for section headings and 12 for body copy.
          local color = size == 11 and detailsColors.gold or dim and detailsColors.secondary or detailsColors.text
          region:SetTextColor(unpack(color))
          region:SetShadowColor(0, 0, 0, 0)
        elseif region:IsObjectType("Texture") and region:GetWidth() == 4 then
          region:SetColorTexture(unpack(detailsColors.gold))
        end
      end
    end

    for _, tile in ipairs({ content:GetChildren() }) do
      if tile.entry and tile.frame and tile:IsShown() then
        if not rewardTiles[tile] then
          rewardTiles[tile] = true
          for _, region in ipairs({ tile:GetRegions() }) do
            if region:IsObjectType("Texture") and region:GetDrawLayer() == "BACKGROUND" then
              region:SetColorTexture(0.16, 0.11, 0.07)
            end
          end
          tile:HookScript("OnEnter", function(self) SetRewardBorder(self, true) end)
          tile:HookScript("OnLeave", function(self) SetRewardBorder(self, false) end)
        end
        SetRewardBorder(tile, tile:IsMouseOver())
      end
    end
  end

  -- EUI sizes the content after updating all its pooled text and reward tiles.
  hooksecurefunc(content, "SetSize", Refresh)
  Refresh()
end

local function SkinQuestDetails(window)
  if not (window.bar and window.focus and window.untrack and window.share and window.abandon) then return end
  local scroll, close, oldBorder
  for _, child in ipairs({ window:GetChildren() }) do
    local kind = child:GetObjectType()
    if kind == "ScrollFrame" then scroll = child
    elseif kind == "Button" and child.icon then close = child
    elseif kind == "Frame" then oldBorder = child end
  end
  local content = scroll and scroll:GetScrollChild()
  if not content then return end

  local meta
  for _, region in ipairs({ window:GetRegions() }) do
    if region:IsObjectType("FontString") then
      local point, relative = region:GetPoint(1)
      if relative == window.bar then
        local isTitle = point == "TOPLEFT"
        local y = isTitle and -12 or -34
        local color = isTitle and detailsColors.gold or detailsColors.secondary
        if not isTitle then meta = region end
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", 14, y)
        region:SetPoint("TOPRIGHT", -34, y)
        region:SetJustifyH("LEFT")
        region:SetTextColor(unpack(color))
        region:SetShadowOffset(1, -1)
        region:SetShadowColor(0, 0, 0, 0.85)
      end
    elseif region:IsObjectType("Texture") then
      local layer = region:GetDrawLayer()
      if layer == "BACKGROUND" then
        region:SetColorTexture(unpack(detailsColors.shell))
      elseif layer == "BORDER" then
        region:SetColorTexture(0.39, 0.28, 0.17)
      end
    end
  end
  window.bar:SetAlpha(0)

  local body = window:CreateTexture(nil, "BACKGROUND", nil, 1)
  body:SetPoint("TOPLEFT", scroll, "TOPLEFT", -5, 6)
  body:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 5, -6)
  body:SetColorTexture(unpack(detailsColors.body))
  if oldBorder then oldBorder:Hide() end
  eui.MakeBorder(window, unpack(detailsColors.edge))

  local atlas = "UI-QuestTracker-Secondary-Objective-Header"
  if C_Texture.GetAtlasInfo(atlas) then
    local header = window:CreateTexture(nil, "BACKGROUND", nil, 1)
    header:SetPoint("TOPLEFT", 4, -4)
    header:SetPoint("TOPRIGHT", -4, -4)
    header:SetHeight(29)
    header:SetAtlas(atlas)
    header:SetAlpha(0.74)
    RestoreTextureSnap(header)
  end

  if close then
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", -7, -6)
    close:SetSize(24, 24)
    close.icon:ClearAllPoints()
    close.icon:SetPoint("CENTER")
    close.icon:SetSize(12, 12)
    close.icon:SetVertexColor(unpack(detailsColors.gold))
  end
  for _, button in ipairs({ window.focus, window.untrack, window.share, window.abandon }) do
    SkinDetailsButton(button)
  end
  SkinDetailsContents(content, meta)
  return true
end

local function ApplyStockAppearance()
  if not (eui and eui.IS_FOREVER and tracker and type(tracker.Cfg) == "function"
      and type(namespace.QT_Style) == "function" and type(namespace.UseCustomTracker) == "function") then
    return false
  end

  RestorePreviewProfiles()
  DefaultToQuestLog()

  -- The dependency loads first. Both EUI's font pass and its tracker read
  -- these selectors during PLAYER_LOGIN.
  namespace.QT_Style = function() return "blizzard" end
  if type(tracker.InitSkin) == "function" then
    hooksecurefunc(tracker, "InitSkin", KeepStockQuestIcons)
  end
  if type(tracker.InitCustom) == "function" and type(tracker.GetFont) == "function"
      and type(tracker.GetHeaderRGB) == "function" and type(tracker.DB) == "function" then
    SkinCustomTracker()
  end
  if type(tracker.ShowQuestDetails) == "function" then
    local skinnedWindow
    hooksecurefunc(tracker, "ShowQuestDetails", function()
      local window = EUI_QuestDetails
      if window and window ~= skinnedWindow and SkinQuestDetails(window) then skinnedWindow = window end
    end)
  end

  -- EUI's optional global game-text pass also visits stock-style modules.
  -- Exclude all tracker fonts, including the locale members of each family.
  local keepFonts = eui._GAME_TEXT_KEEP
  if type(keepFonts) == "table" then
    keepFonts[#keepFonts + 1] = "ObjectiveTrackerHeaderFont"
    keepFonts[#keepFonts + 1] = "ObjectiveTrackerLineFont"
    for size = 12, 22 do
      keepFonts[#keepFonts + 1] = "ObjectiveTrackerFont" .. size
    end
  end

  local getSetting = tracker.Cfg
  tracker.Cfg = function(key)
    local value = stockAppearance[key]
    if value ~= nil and not namespace.UseCustomTracker() then return value end
    local saved = getSetting(key)
    -- EUI's layout reserves the old header before measuring the scroll area.
    if key == "customMaxHeight" and type(saved) == "number" and not eui._unlockActive then
      return saved - customHeaderSpace
    end
    return saved
  end

  -- Compare against the effective style when EUI switches profiles.
  -- Keep the incoming profile's saved style available for when we are disabled.
  local changesStyle = eui.ProfileChangesStyle
  if type(changesStyle) == "function" then
    eui.ProfileChangesStyle = function(profile)
      if type(profile) ~= "table" or type(profile.addons) ~= "table" then
        return changesStyle(profile)
      end
      local incoming = profile.addons[trackerAddon]
      local config = type(incoming) == "table" and incoming.questTracker
      if type(namespace.CustomTrackerWanted) == "function"
          and namespace.CustomTrackerWanted(type(config) == "table" and config or {})
              ~= namespace.UseCustomTracker() then
        return true
      end
      local effective = Mixin({}, profile)
      effective.addons = Mixin({}, profile.addons)
      effective.addons[trackerAddon] = { questTracker = { useBlizzardStyle = true } }
      return changesStyle(effective)
    end
  end
  return true
end

local active = ApplyStockAppearance()

SLASH_IMMERSIVEQUESTTRACKER1 = "/iqt"
SlashCmdList.IMMERSIVEQUESTTRACKER = function()
  if active then
    local renderer = namespace.UseCustomTracker() and "EllesmereUI Custom Quest Tracker" or "Blizzard Quest Tracker"
    print("Immersive Quest Tracker Skin has applied the WoW Forever appearance to " .. renderer .. ".")
  else
    print("Immersive Quest Tracker Skin could not find a compatible EllesmereUI Quest Tracker on WoW Forever.")
  end
end
