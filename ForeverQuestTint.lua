local ADDON, ns = ...

-- Teal overlay: a desaturated copy of the parchment tinted cfg.tint, fading from cfg.alpha at the
-- bottom to cfg.topAlpha at cfg.height of the way up. Settings live in the options panel.
ns.defaults = {
    showTint = true,   -- teal overlay on non-vanilla quests
    showLogo = false,  -- WoW Forever logo above the quest text on non-vanilla quests
    tint = { 0.60, 0.90, 0.95 },
    alpha = 1.0,    -- opacity at the very bottom
    topAlpha = 0,   -- opacity where the fade ends
    height = 0.6,   -- fraction of the visible parchment (from the bottom) the fade covers
    marker = true,  -- prefix non-vanilla quests in the quest log list and tracker
    markerSymbol = "\226\136\158", -- infinity sign (UTF-8 bytes)
    markerAtStart = false, -- false: after the quest name, true: before it
    markerIcon = true,     -- draw the marker as an icon instead of the text symbol
    markerHeight = 8,      -- height of the infinity sign itself, in pixels (roughly the text's cap height)
    markerOffset = 0,      -- vertical nudge in pixels, relative to the built-in baseline (ICON_BASELINE)
    markerGap = 0,         -- extra space between the icon and the quest name, in pixels
    markerUseTint = true,
    markerColor = { 0.60, 0.90, 0.95 },
    trackerLogo = false, -- the WoW Forever logo beside non-vanilla quests in the objective tracker
    objectiveTint = false,     -- recolour the objective lines of non-vanilla quests
    objectiveUseTint = true,   -- objectives use the tint colour...
    objectiveColor = { 0.60, 0.90, 0.95 }, -- ...or this colour
    questieTint = true, -- teal gradient on the yellow ! and ? map icons (the game's and Questie's) of non-vanilla quests
    preview = "auto", -- testing aid: "auto" marks non-vanilla quests, "on" marks every quest, "off" none
}

local function CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end
ns.cfg = CopyDefaults({}, ns.defaults)

local PANELS = {
    "QuestFrameDetailPanel",
    "QuestFrameProgressPanel",
    "QuestFrameRewardPanel",
    "QuestFrameGreetingPanel",
}
local SUFFIXES = { "Bg", "MaterialTopLeft", "MaterialTopRight", "MaterialBotLeft", "MaterialBotRight" }

-- Binary search over the sorted ranges: no per-ID table, so nothing to hold in memory.
local RANGES = ns.VanillaQuestRanges
local function IsVanilla(id)
    local lo, hi = 1, #RANGES
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        local r = RANGES[mid]
        if id < r[1] then
            hi = mid - 1
        elseif id > r[2] then
            lo = mid + 1
        else
            return true
        end
    end
    return false
end

-- Whether a quest gets the tint, logo and marker. The preview setting overrides the vanilla list,
-- so the look can be checked on any client (or any quest) without hunting for a non-vanilla one.
local function IsMarked(id)
    if not id or id <= 0 then return false end
    local preview = ns.cfg.preview
    if preview == "on" then return true end
    if preview == "off" then return false end
    return not IsVanilla(id)
end

local REWARDS_OVERLAP = 24 -- how far the overlay tucks under the Rewards panel
-- Black Quest Text Contrast (setting 4) gives a dark panel; see ApplyOverlay.
local DARK_SCALE = 0.75 -- brightness of the teal on dark backgrounds
local DARK_ALPHA = 0.7  -- strength of the teal on dark backgrounds, relative to cfg.alpha

local function IsDarkBackground()
    if QuestTextContrast and QuestTextContrast.UseLightText then
        return QuestTextContrast.UseLightText() and true or false
    end
    return tonumber(GetCVar("QuestTextContrast") or 0) == 4
end

-- A page another addon has darkened through its vertex colour (ClassicUI Forever's dark themes) gets the glow too.
local function IsInkedDark(tex)
    local r, g, b = tex:GetVertexColor()
    return r ~= nil and 0.3 * r + 0.59 * g + 0.11 * b < 0.35
end

local LOGO_PATH = "Interface/AddOns/ForeverQuestTint/Media/ForeverLogo.tga"
local logos = setmetatable({}, { __mode = "k" })

-- Logo: a small badge in the top-right corner of the bar just above the quest text.
-- It lives in its own high-level frame so Blizzard's window art can't cover it.
local LOGO_SIZE = 40
local GIVER_LOGO_X = 26 -- quest-giver window: pushes the logo out to the right end of the bar
local GIVER_LOGO_Y = -1 -- quest-giver window: vertical offset above the parchment (negative = lower)
local LOG_LOGO_Y = -22 -- fallback vertical offset from the log parchment's top edge

-- Frames are ordered by strata first, then level. Find the topmost (strata, level) anywhere in
-- a window so the logo can be drawn above all of its art.
local STRATA_ORDER = {
    BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5,
    FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8,
}
local function TopOrder(frame, bestStrata, bestLevel)
    local strata = frame:GetFrameStrata()
    local level = frame:GetFrameLevel()
    local si, bi = STRATA_ORDER[strata] or 0, STRATA_ORDER[bestStrata] or 0
    if si > bi or (si == bi and level > bestLevel) then
        bestStrata, bestLevel = strata, level
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        bestStrata, bestLevel = TopOrder(child, bestStrata, bestLevel)
    end
    return bestStrata, bestLevel
end

local function ApplyLogo(tex, show)
    local holder = logos[tex]
    if not show then
        if holder then holder:Hide() end
        return
    end
    if not holder then
        -- Parent to the outermost window frame: the details frame itself may clip its children,
        -- and the bar above the parchment is outside its rectangle.
        local top = tex:GetParent()
        while top:GetParent() and top:GetParent() ~= UIParent do
            top = top:GetParent()
        end
        holder = CreateFrame("Frame", nil, top)
        local strata, level = TopOrder(top, "BACKGROUND", 0)
        holder:SetFrameStrata(strata)
        holder:SetFrameLevel(math.min(level + 1, 9999))
        holder:SetSize(LOGO_SIZE, LOGO_SIZE)
        holder.texture = holder:CreateTexture(nil, "OVERLAY")
        holder.texture:SetAllPoints()
        holder.texture:SetTexture(LOGO_PATH)
        logos[tex] = holder
    end
    holder:ClearAllPoints()
    local details = QuestMapFrame and QuestMapFrame.DetailsFrame
    if details and tex:GetParent() == details then
        -- Quest log: the parchment art has transparent padding above the paper, so line the logo
        -- up with the Back button instead (falls back to a fixed offset if it can't be found).
        local yOff = LOG_LOGO_Y
        local back = details.BackButton or QuestMapFrame.BackButton
        local top = tex:GetTop()
        if back and back.GetCenter and top then
            local _, cy = back:GetCenter()
            if cy then yOff = cy - top end
        end
        holder:SetPoint("RIGHT", tex, "TOPRIGHT", -6, yOff)
    else
        holder:SetPoint("BOTTOMRIGHT", tex, "TOPRIGHT", GIVER_LOGO_X, GIVER_LOGO_Y)
    end
    holder:Show()
end

local overlays = setmetatable({}, { __mode = "k" })
local ApplyFlat, HideFlat -- the flat glow, defined further down

-- A skin (EllesmereUI) can hide the game's parchment and paint the window flat and dark. A copy of the parchment
-- would then show its grain and torn edges out of place (and keep the parchment's old size when the skin widens the
-- window), so a skinned window gets the flat glow instead, in the vivid tint at dark-panel strength: over the quest
-- log's details, or across the quest window's text area from side to side. The parchment counts as skinned when it
-- is see-through, or when EllesmereUI's skin module is loaded (how it hides the parchment isn't known here).
local SKIN_SCALE, SKIN_ALPHA = 0.75, 0.6
local SKIN_PAD = 4 -- in from the quest window's sides
local SKIN_SCROLL = { -- each quest window panel's text area
    QuestFrameDetailPanel = "QuestDetailScrollFrame",
    QuestFrameProgressPanel = "QuestProgressScrollFrame",
    QuestFrameRewardPanel = "QuestRewardScrollFrame",
    QuestFrameGreetingPanel = "QuestGreetingScrollFrame",
}
local skinRegions = setmetatable({}, { __mode = "k" })

local function IsSkinned(tex)
    if (tex:GetAlpha() or 1) < 0.05 then return true end
    local _, _, _, a = tex:GetVertexColor()
    if a and a < 0.05 then return true end
    local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    return isLoaded and isLoaded("EllesmereUIBlizzardSkin") and true or false
end

-- What the flat glow covers for a skinned parchment: the quest window's text area widened to the window's sides
-- (the skin may resize the window, not the parchment), else the parchment's own rectangle. On the quest log it lines
-- up with the Rewards panel, which is a little narrower: its right edge is the panel's, and it ends at the panel's
-- top when the panel shows (running underneath, the glow peeked out beside it).
local function SkinRegion(tex)
    local parent = tex:GetParent()
    local rewards = parent and parent.RewardsFrameContainer
    if type(rewards) == "table" and rewards.GetRight then
        local texTop, texBottom, texRight = tex:GetTop(), tex:GetBottom(), tex:GetRight()
        local rewardsRight = rewards:GetRight()
        local rewardsTop = rewards:IsShown() and rewards:GetTop()
        if texTop and texBottom and texRight then
            local region = skinRegions[tex]
            if not region then
                region = CreateFrame("Frame", nil, parent)
                skinRegions[tex] = region
            end
            local dx = rewardsRight and rewardsRight < texRight and rewardsRight - texRight or 0
            local dy = rewardsTop and rewardsTop > texBottom and rewardsTop < texTop and rewardsTop - texBottom or 0
            region:ClearAllPoints()
            region:SetPoint("TOPLEFT", tex, "TOPLEFT")
            region:SetPoint("BOTTOMRIGHT", tex, "BOTTOMRIGHT", dx, dy)
            return region
        end
    end
    local scroll = parent and parent.GetName and _G[SKIN_SCROLL[parent:GetName() or ""] or ""]
    local sl, sr, wl, wr = scroll and scroll:GetLeft(), scroll and scroll:GetRight(), QuestFrame and QuestFrame:GetLeft(),
        QuestFrame and QuestFrame:GetRight()
    if not (sl and sr and wl and wr) then return tex end
    local region = skinRegions[tex]
    if not region then
        region = CreateFrame("Frame", nil, parent)
        skinRegions[tex] = region
    end
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", scroll, "TOPLEFT", wl + SKIN_PAD - sl, 0)
    region:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", wr - SKIN_PAD - sr, 0)
    return region
end
ns.rev = 0 -- bumped by ns.Reapply; invalidates the cached overlay geometry

local function ApplyOverlay(tex, tinted, noLogo)
    local ov = overlays[tex]
    ApplyLogo(tex, tinted and ns.cfg.showLogo and not noLogo)
    tinted = tinted and ns.cfg.showTint
    local skinKey = "skin" .. tostring(tex)
    if not tinted then
        if ov then ov:Hide() end
        HideFlat(skinKey)
        return
    end
    if IsSkinned(tex) then
        if ov then ov:Hide() end
        -- One glow per window: on the main (largest) parchment only, the one that also gets the logo.
        if noLogo then
            HideFlat(skinKey)
        else
            ApplyFlat(skinKey, tex:GetParent(), SkinRegion(tex), SKIN_SCALE, SKIN_ALPHA, nil, "BORDER", true)
        end
        return
    end
    HideFlat(skinKey)
    if not ov then
        ov = tex:GetParent():CreateTexture(nil, "BACKGROUND", nil, 2)
        overlays[tex] = ov
    end
    -- The Rewards panel (log window) slides over the bottom of the parchment, so measure
    -- from the bottom of the *visible* parchment and map the texture coords to match.
    local bgTop, bgBottom = tex:GetTop(), tex:GetBottom()
    if not bgTop or not bgBottom or bgTop <= bgBottom then
        ov:Hide()
        return
    end
    local visBottom = bgBottom
    local rewards = tex:GetParent().RewardsFrameContainer
    local rewardsTop = rewards and rewards:IsShown() and rewards:GetTop()
    -- Called up to 20 times a second by the keeper: if nothing it depends on has changed, stop here.
    local atlas = tex:GetAtlas()
    local dark = IsDarkBackground() or IsInkedDark(tex)
    if ov:IsShown() and ov.fqtRev == ns.rev and ov.fqtTop == bgTop and ov.fqtBottom == bgBottom
        and ov.fqtRewards == (rewardsTop or false) and ov.fqtAtlas == atlas and ov.fqtDark == dark then
        return
    end
    ov.fqtRev, ov.fqtTop, ov.fqtBottom = ns.rev, bgTop, bgBottom
    ov.fqtRewards, ov.fqtAtlas, ov.fqtDark = rewardsTop or false, atlas, dark
    -- Bottom strip of the parchment only, so the fade finishes cfg.height of the way up.
    local l, r, t, b
    local info = atlas and C_Texture.GetAtlasInfo(atlas)
    if info then
        l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    else
        local ulx, uly, _, _, _, _, lrx, lry = tex:GetTexCoord()
        l, r, t, b = ulx, lrx, uly, lry
    end
    if rewardsTop then
        -- Run underneath the Rewards panel: its rim starts below its reported top edge.
        rewardsTop = rewardsTop - REWARDS_OVERLAP
        if rewardsTop > visBottom then
            visBottom = math.min(rewardsTop, bgTop - 1)
        end
    end
    local total = bgTop - bgBottom
    local cfg = ns.cfg
    local height = (bgTop - visBottom) * cfg.height
    local vBot = t + (b - t) * ((bgTop - visBottom) / total)
    local vTop = t + (b - t) * ((bgTop - visBottom - height) / total)
    ov:ClearAllPoints()
    ov:SetPoint("BOTTOMLEFT", tex, "BOTTOMLEFT", 0, visBottom - bgBottom)
    ov:SetPoint("BOTTOMRIGHT", tex, "BOTTOMRIGHT", 0, visBottom - bgBottom)
    ov:SetHeight(height)
    local c = cfg.tint
    if dark then
        -- On the Black contrast setting a multiplied copy of the background would stay black,
        -- so draw a flat, deeper teal glow instead.
        ov:SetDesaturated(false)
        ov:SetColorTexture(1, 1, 1, 1)
        ov:SetGradient("VERTICAL",
            CreateColor(c[1] * DARK_SCALE, c[2] * DARK_SCALE, c[3] * DARK_SCALE, cfg.alpha * DARK_ALPHA),
            CreateColor(c[1] * DARK_SCALE, c[2] * DARK_SCALE, c[3] * DARK_SCALE, cfg.topAlpha * DARK_ALPHA))
    else
        ov:SetTexture(info and (info.file or info.filename) or tex:GetTexture())
        ov:SetTexCoord(l, r, vTop, vBot)
        ov:SetDesaturated(true)
        ov:SetGradient("VERTICAL",
            CreateColor(c[1], c[2], c[3], cfg.alpha),
            CreateColor(c[1], c[2], c[3], cfg.topAlpha))
    end
    ov:Show()
end

-- Quest Text Contrast (Default/Brown/White/Grey/Black) swaps the background atlas, so match
-- the whole family: QuestDetailsBackgrounds[-Accessibility...] and QuestBG-Parchment[-Accessibility...].
local function IsParchment(tex)
    local atlas = tex:GetAtlas()
    if not atlas then return false end
    atlas = atlas:lower()
    return atlas:find("^questdetailsbackgrounds") ~= nil or atlas:find("^questbg%-parchment") ~= nil
end

local function Walk(frame, fn, seen)
    if seen[frame] then return end
    seen[frame] = true
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.GetTexture then fn(region) end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        Walk(child, fn, seen)
    end
end

local dialogTex = setmetatable({}, { __mode = "k" }) -- every quest-window texture we have overlaid

local function SetTinted(tinted)
    -- The window has several parchment-like textures (one per panel); overlay all of them,
    -- but show the logo only once, on the largest visible one.
    local candidates = {}
    if QuestFrame then
        Walk(QuestFrame, function(tex)
            if IsParchment(tex) then candidates[#candidates + 1] = tex end
        end, {})
    end
    for _, panel in ipairs(PANELS) do
        for _, suffix in ipairs(SUFFIXES) do
            local tex = _G[panel .. suffix]
            if tex and tex:IsShown() then candidates[#candidates + 1] = tex end
        end
    end
    local best, bestArea = nil, 0
    for _, tex in ipairs(candidates) do
        local area = tex:IsVisible() and (tex:GetWidth() * tex:GetHeight()) or 0
        if area > bestArea then best, bestArea = tex, area end
    end
    local current = {}
    for _, tex in ipairs(candidates) do
        current[tex] = true
        dialogTex[tex] = true
        ApplyOverlay(tex, tinted, tex ~= best)
    end
    -- A texture Blizzard stopped reporting as parchment (new quest, new atlas) must not keep
    -- an overlay from the previous quest on screen.
    for tex in pairs(dialogTex) do
        if not current[tex] then ApplyOverlay(tex, false) end
    end
end

local currentQuestID = 0 -- the quest open in the quest-giver window; 0 for greetings

local function Refresh()
    if QuestFrame and QuestFrame:IsShown() then
        SetTinted(IsMarked(currentQuestID))
    end
end

local function Update()
    ns.rev = ns.rev + 1 -- a new quest was opened: redraw rather than trust cached geometry
    currentQuestID = GetQuestID() or 0
    Refresh()
    -- Blizzard may re-apply quest materials after the event fires.
    C_Timer.After(0, Refresh)
end

local f = CreateFrame("Frame")
f:RegisterEvent("QUEST_DETAIL")
f:RegisterEvent("QUEST_PROGRESS")
f:RegisterEvent("QUEST_COMPLETE")
f:RegisterEvent("QUEST_GREETING")
f:SetScript("OnEvent", function(_, event)
    if event == "QUEST_GREETING" then
        ns.rev = ns.rev + 1
        currentQuestID = 0
        Refresh()
    else
        Update()
    end
end)

if QuestFrame then
    QuestFrame:HookScript("OnShow", Refresh)
end

-- Map & Quest Log: the parchment is QuestMapFrame...DetailsFrame.Bg (atlas QuestDetailsBackgrounds).
local logBg, logTinted
local keeper -- created below; TintLogFrame needs it as an upvalue
local function TintLogFrame(tinted)
    if not QuestMapFrame then return end
    logTinted = tinted
    if tinted then keeper:Show() end
    -- Blizzard's own key for the parchment; works whatever atlas the contrast setting uses. ClassicUI Forever hides
    -- it and lays its own parchment, kept in details.fcui.parchment, while its map quest pane is on.
    local details = QuestMapFrame.DetailsFrame
    local own = details and details.fcui and details.fcui.parchment
    local bg = (own and own:IsShown() and own) or (details and details.Bg)
    if bg and bg.GetTexture then
        if logBg and logBg ~= bg then ApplyOverlay(logBg, false) end
        logBg = bg
        ApplyOverlay(bg, tinted)
        return
    end
    Walk(QuestMapFrame, function(tex)
        if IsParchment(tex) then
            logBg = tex
            ApplyOverlay(tex, tinted)
        end
    end, {})
end

-- Blizzard re-lays out the details panel when it scrolls, which drops the overlay;
-- keep it applied while a tinted quest is showing.
local elapsed = 0
keeper = CreateFrame("Frame")
keeper:Hide() -- an OnUpdate only runs while its frame is shown; TintLogFrame shows it when needed
keeper:SetScript("OnUpdate", function(self, dt)
    elapsed = elapsed + dt
    if elapsed < 0.05 then return end
    elapsed = 0
    if logTinted and logBg and logBg:IsVisible() then
        ApplyOverlay(logBg, true)
    else
        if logBg then ApplyLogo(logBg, false) end
        self:Hide()
    end
end)

local function RefreshLog()
    local details = QuestMapFrame and QuestMapFrame.DetailsFrame
    local id = details and details:IsShown() and details.questID
    TintLogFrame(IsMarked(id))
end

local logHooked = false
local function HookLog()
    if logHooked or not QuestMapFrame then return end
    logHooked = true
    QuestMapFrame:HookScript("OnShow", RefreshLog)
    if QuestMapFrame.DetailsFrame then
        QuestMapFrame.DetailsFrame:HookScript("OnShow", RefreshLog)
        QuestMapFrame.DetailsFrame:HookScript("OnHide", RefreshLog)
    end
    if QuestMapFrame_ShowQuestDetails then
        hooksecurefunc("QuestMapFrame_ShowQuestDetails", function()
            RefreshLog()
            C_Timer.After(0, RefreshLog)
        end)
    end
    if QuestMapFrame_CloseQuestDetails then
        hooksecurefunc("QuestMapFrame_CloseQuestDetails", RefreshLog)
    end
end

-- Dialogue UI (addon) replaces the quest window with DUIQuestFrame, which draws its own parchment
-- as three stacked pieces (top cap, stretched middle, bottom cap) in frame.Parchments. Its theme
-- is a texture folder (Theme_Brown / Theme_Dark). frame.questID is only set while a quest is open.
local DUI_LOGO_SIZE = 30
local DUI_LOGO_X, DUI_LOGO_Y = 6, -4 -- from the top-right corner of the quest title header
local DUI_DARK_SCALE = 0.7 -- Dark theme glow: brightness of the teal...
local DUI_DARK_ALPHA = 0.45 -- ...and its strength relative to cfg.alpha (lower = subtler)
local DARK_GLOW_PATH = "Interface/AddOns/ForeverQuestTint/Media/DarkParchmentGlow.png"
local duiOverlays = {}
local duiKey = {} -- geometry the DUI overlay was last drawn for
local duiLogo

-- The footer divider (shown above the buttons when the text scrolls) is a parchment-coloured fade
-- plus a line, drawn in the front layer above both the scrolling text and our overlay, so against
-- the teal it shows up as an orange band. While the tint is on, it is moved into the background
-- layer, between the parchment and our overlay, so it is tinted exactly like the paper around it
-- (and the text still draws above it). This puts it back.
local function DUIDivider(frame)
    frame = frame or _G.DUIQuestFrame
    return frame and frame.FrontFrame and frame.FrontFrame.FooterDivider
end

local function ResetDUIDivider()
    local frame = _G.DUIQuestFrame
    local div = DUIDivider(frame)
    if div and div.fqtMoved then
        div.fqtMoved = nil
        div:SetParent(frame.FrontFrame)
        div:SetDrawLayer("ARTWORK", 0)
    end
end

local function HideDUI()
    duiKey.rev = nil
    ResetDUIDivider()
    for _, ov in ipairs(duiOverlays) do ov:Hide() end
    if duiLogo then duiLogo:Hide() end
end

-- Dialogue UI's parchment is paler than Blizzard's, so push the tint away from grey (and clamp):
-- the default 0.60/0.90/0.95 becomes about 0.38/0.98/1.00.
local DUI_VIVID = 2
local function VividTint(c)
    local avg = (c[1] + c[2] + c[3]) / 3
    local function f(x) return math.max(0, math.min(1, avg + (x - avg) * DUI_VIVID)) end
    return { f(c[1]), f(c[2]), f(c[3]) }
end

local function ApplyDUIOverlay(frame, pieces)
    local bottom, top = pieces[3]:GetBottom(), pieces[1]:GetTop()
    if not bottom or not top or top <= bottom then
        duiKey.rev = nil
        for _, ov in ipairs(duiOverlays) do ov:Hide() end
        ResetDUIDivider()
        return
    end
    local cfg = ns.cfg
    local midHeight = pieces[2]:GetHeight()
    if duiKey.rev == ns.rev and duiKey.id == frame.questID and duiKey.top == top
        and duiKey.bottom == bottom and duiKey.mid == midHeight then
        return
    end
    duiKey.rev, duiKey.id, duiKey.top, duiKey.bottom, duiKey.mid = ns.rev, frame.questID, top, bottom, midHeight
    local c = VividTint(cfg.tint)
    local file = pieces[1]:GetTexture()
    -- Dialogue UI's own setting (Theme: 1 = Brown, 2 = Dark); GetTexture may return a file ID, so
    -- the texture path is only a fallback.
    local dark = (DialogueUI_DB and DialogueUI_DB.Theme == 2)
        or (type(file) == "string" and file:lower():find("theme_dark", 1, true) ~= nil)
    -- A tinted copy of the near-black Dark parchment would stay black, so use a white copy of its
    -- outline instead (same layout, so the same texture coordinates apply) and tint that.
    if dark then file = DARK_GLOW_PATH end
    if dark then ResetDUIDivider() end
    local fade = (top - bottom) * cfg.height
    -- Opacity of the teal at height y: cfg.alpha at the very bottom, cfg.topAlpha where the fade ends.
    local function alphaAt(y)
        local a = cfg.topAlpha + (cfg.alpha - cfg.topAlpha) * (1 - (y - bottom) / fade)
        return dark and a * DUI_DARK_ALPHA or a
    end
    local scale = dark and DUI_DARK_SCALE or 1
    for i, piece in ipairs(pieces) do
        local ov = duiOverlays[i]
        if not ov then
            ov = frame.BackgroundFrame:CreateTexture(nil, "BACKGROUND", nil, 2)
            duiOverlays[i] = ov
        end
        local pb, pt = piece:GetBottom(), piece:GetTop()
        local lo, hi = pb and math.max(pb, bottom), pt and math.min(pt, bottom + fade)
        if not lo or not hi or hi - lo < 0.01 or pt <= pb then
            ov:Hide()
        else
            -- Each piece only overlays the part of itself inside the fade, with the matching
            -- slice of its texture (the middle piece is stretched, so this stays proportional).
            local ulx, uly, _, _, _, _, lrx, lry = piece:GetTexCoord()
            local function v(y) return uly + (lry - uly) * ((pt - y) / (pt - pb)) end
            ov:ClearAllPoints()
            ov:SetPoint("BOTTOMLEFT", piece, "BOTTOMLEFT", 0, lo - pb)
            ov:SetPoint("BOTTOMRIGHT", piece, "BOTTOMRIGHT", 0, lo - pb)
            ov:SetHeight(hi - lo)
            local lowColor = CreateColor(c[1] * scale, c[2] * scale, c[3] * scale, alphaAt(lo))
            local highColor = CreateColor(c[1] * scale, c[2] * scale, c[3] * scale, alphaAt(hi))
            ov:SetDesaturated(not dark)
            ov:SetTexture(file)
            ov:SetTexCoord(ulx, lrx, v(hi), v(lo))
            ov:SetGradient("VERTICAL", lowColor, highColor)
            ov:Show()
        end
    end
    local div = DUIDivider(frame)
    if div and not dark and not div.fqtMoved then
        div.fqtMoved = true
        div:SetParent(frame.BackgroundFrame)
        div:SetDrawLayer("BACKGROUND", 1) -- above the parchment pieces (-1), below our overlay (2)
    end
end

local function ApplyDUILogo(frame, show)
    local header = frame.FrontFrame and frame.FrontFrame.Header
    if not show or not header then
        if duiLogo then duiLogo:Hide() end
        return
    end
    if not duiLogo then
        duiLogo = CreateFrame("Frame", nil, frame)
        duiLogo:SetFrameStrata(frame:GetFrameStrata())
        duiLogo:SetFrameLevel(math.min(frame:GetFrameLevel() + 50, 9999))
        duiLogo:SetSize(DUI_LOGO_SIZE, DUI_LOGO_SIZE)
        duiLogo.texture = duiLogo:CreateTexture(nil, "OVERLAY")
        duiLogo.texture:SetAllPoints()
        duiLogo.texture:SetTexture(LOGO_PATH)
        duiLogo:SetPoint("BOTTOMRIGHT", header, "TOPRIGHT", DUI_LOGO_X, DUI_LOGO_Y)
    end
    duiLogo:Show()
end

local function RefreshDUI()
    local frame = _G.DUIQuestFrame
    if not frame or not frame.Parchments then return end
    local id = frame.questLayout and frame.questID
    if not frame:IsVisible() or not IsMarked(id) then
        if #duiOverlays > 0 or duiLogo then HideDUI() end
        return
    end
    if ns.cfg.showTint then
        ApplyDUIOverlay(frame, frame.Parchments)
    else
        duiKey.rev = nil
        ResetDUIDivider()
        for _, ov in ipairs(duiOverlays) do ov:Hide() end
    end
    ApplyDUILogo(frame, ns.cfg.showLogo)
end

-- Dialogue UI resizes its window to fit the text, so keep the overlay matched to it. The watcher
-- is parented to the quest frame so it only runs while that frame is visible (and not at all
-- when Dialogue UI isn't installed); show/hide/resize hooks refresh and clean up.
local duiElapsed = 0
local duiWatcher
local function HookDUI()
    local frame = _G.DUIQuestFrame
    if duiWatcher or not frame or not frame.HookScript then return end
    duiWatcher = CreateFrame("Frame", nil, frame)
    duiWatcher:SetScript("OnUpdate", function(_, dt)
        duiElapsed = duiElapsed + dt
        if duiElapsed < 0.05 then return end
        duiElapsed = 0
        RefreshDUI()
    end)
    frame:HookScript("OnShow", function() duiElapsed = 0; RefreshDUI() end)
    frame:HookScript("OnHide", function() RefreshDUI() end) -- hides the overlays
    frame:HookScript("OnSizeChanged", function() RefreshDUI() end)
    RefreshDUI()
end

-- A flat teal wash over the bottom of a page whose art can't simply be copied (sliced art, or a window's art in
-- pieces), like the Black contrast setting's glow above: brightness `scale` and strength `strength` (relative to
-- cfg.alpha). Drawn one sublevel above `region` when it is a texture, else at the top of `parent`'s background
-- layer, or of `drawLayer` when given: a backdrop draws its edges and corners on BORDER, above its BACKGROUND centre, so a glow meant to
-- cover them goes on BORDER too. With `vivid`, the tint is pushed away from grey first (VividTint), for dark panels
-- where the plain tint reads as grey.
--
-- With `corner`, the glow takes a panel's shape: shaped bottom corners and a soft rim, from corner art made by
-- logo/make_glow_corner.py: Media/GlowCorner.tga (the default) is the bottom-left of a soft-edged rounded rectangle,
-- its rim 10/32 of the corner piece and its radius 22/32; Media/GlowChamfer.tga (`art`) has its corners cut off at
-- 45 degrees, its rim 5/32 and its cut 17/32 along each side. `corner` is the size the art's 32x32 corner quadrant
-- is drawn at. `region` is the
-- glow's outer edge, where the rim has faded out. Six pieces, each carrying its share of the vertical fade: the two
-- bottom corners, the bottom edge between them and the two sides above them (stretched from the straight parts of
-- the art), and the plain centre.
local GLOW_CORNER = "Interface\\AddOns\\ForeverQuestTint\\Media\\GlowCorner.tga"
local GLOW_CHAMFER = "Interface\\AddOns\\ForeverQuestTint\\Media\\GlowChamfer.tga"
local GLOW_CORNER_UV = { 0, 0.5, 0.5, 1 }               -- the bottom-left 32x32 quadrant
local GLOW_BOTTOM_UV = { 0.74, 0.76, 0.5, 1 }           -- a column through the straight bottom edge
local GLOW_SIDE_UV = { 0, 0.5, 0.23, 0.25 }             -- a row through the straight left edge
local flats = {}

function HideFlat(key)
    local ov = flats[key]
    if not ov then return end
    ov:Hide()
    ov.fqtShown = nil
    for _, tex in ipairs(ov.fqtPieces) do tex:Hide() end
end

-- The glow's colour and strength at screen height `y` (from another frame's GetTop/GetBottom), for art drawn
-- above the glow that has to match the glowing page below it. Nil while the glow is hidden.
local function FlatColourAt(key, y)
    local ov = flats[key]
    local bottom = ov and ov.fqtShown and ov.fqtRegion:GetBottom()
    if not bottom or not y then return nil end
    local c = ov.fqtColour
    return c[1], c[2], c[3], math.max(0, math.min(1, ov.fqtAlphaAt(y - bottom)))
end

function ApplyFlat(key, parent, region, scale, strength, corner, drawLayer, vivid, art)
    local cfg = ns.cfg
    local height = region and region:GetHeight()
    local fade = height and height * cfg.height
    if not fade or fade <= 0 then
        HideFlat(key)
        return
    end
    local ov = flats[key]
    if not ov then
        ov = parent:CreateTexture(nil, drawLayer or "BACKGROUND", nil, 7)
        ov.fqtPieces = {}
        flats[key] = ov
    end
    local layer, sublevel = drawLayer or "BACKGROUND", 7
    if not drawLayer and region.GetDrawLayer then
        layer, sublevel = region:GetDrawLayer()
        sublevel = math.min((sublevel or 0) + 1, 7)
    end
    local c = vivid and VividTint(cfg.tint) or cfg.tint
    local r, g, b = c[1] * scale, c[2] * scale, c[3] * scale
    -- Opacity at y units above the bottom: cfg.alpha there, cfg.topAlpha where the fade ends.
    local function alphaAt(y)
        y = math.max(0, y)
        return (cfg.topAlpha + (cfg.alpha - cfg.topAlpha) * (1 - y / fade)) * strength
    end
    local function colour(a) return CreateColor(r, g, b, a) end
    ov.fqtRegion, ov.fqtAlphaAt, ov.fqtColour, ov.fqtShown = region, alphaAt, { r, g, b }, true
    local function place(tex, left, right, y0, y1)
        tex:SetDrawLayer(layer, sublevel)
        tex:ClearAllPoints()
        tex:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", left, y0)
        tex:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", -right, y0)
        tex:SetHeight(y1 - y0)
        tex:SetColorTexture(1, 1, 1, 1)
        tex:Show()
    end

    if not (corner and corner > 0) then
        -- One piece: the plain wash.
        place(ov, 0, 0, 0, fade)
        ov:SetGradient("VERTICAL", colour(alphaAt(0)), colour(alphaAt(fade)))
        for _, tex in ipairs(ov.fqtPieces) do tex:Hide() end
        return
    end

    ov:Hide()
    local width = region:GetWidth() or 0
    local size = math.min(corner, fade, width / 2)
    local function piece(i, uv, mirror, left, right, y0, y1)
        local tex = ov.fqtPieces[i]
        if not tex then
            tex = parent:CreateTexture(nil, layer, nil, sublevel)
            ov.fqtPieces[i] = tex
        end
        tex:SetDrawLayer(layer, sublevel)
        tex:ClearAllPoints()
        tex:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", left, y0)
        tex:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", -right, y0)
        tex:SetHeight(y1 - y0)
        if uv then
            tex:SetTexture(art or GLOW_CORNER)
            if mirror then
                tex:SetTexCoord(uv[2], uv[1], uv[3], uv[4])
            else
                tex:SetTexCoord(uv[1], uv[2], uv[3], uv[4])
            end
        else
            tex:SetColorTexture(1, 1, 1, 1)
        end
        tex:SetGradient("VERTICAL", colour(alphaAt(y0)), colour(alphaAt(y1)))
        tex:Show()
    end
    local mid = width - 2 * size
    piece(1, GLOW_CORNER_UV, false, 0, width - size, 0, size)        -- bottom-left corner
    piece(2, GLOW_CORNER_UV, true, width - size, 0, 0, size)         -- bottom-right corner
    piece(3, GLOW_BOTTOM_UV, false, size, size, 0, size)             -- bottom edge
    piece(4, GLOW_SIDE_UV, false, 0, width - size, size, fade)       -- left side
    piece(5, GLOW_SIDE_UV, true, width - size, 0, size, fade)        -- right side
    piece(6, nil, false, size, size, size, fade)                     -- centre
    -- A panel too narrow for a middle has nothing between its corners.
    if mid <= 0 then ov.fqtPieces[3]:Hide(); ov.fqtPieces[6]:Hide() end
    if fade <= size then ov.fqtPieces[4]:Hide(); ov.fqtPieces[5]:Hide(); ov.fqtPieces[6]:Hide() end
    for i = 7, #ov.fqtPieces do ov.fqtPieces[i]:Hide() end
end

-- The logo as a small badge on `anchor`, created on first use and kept per key.
local badges = {}
local function ApplyBadge(key, anchor, show, point, relPoint, x, y, size)
    local badge = badges[key]
    if not show or not anchor then
        if badge then badge:Hide() end
        return
    end
    if not badge then
        badge = CreateFrame("Frame", nil, anchor)
        badge:SetFrameLevel(math.min(anchor:GetFrameLevel() + 20, 9999))
        badge.texture = badge:CreateTexture(nil, "OVERLAY")
        badge.texture:SetAllPoints()
        badge.texture:SetTexture(LOGO_PATH)
        badges[key] = badge
    end
    badge:SetSize(size, size)
    badge:ClearAllPoints()
    badge:SetPoint(point, anchor, relPoint, x, y)
    badge:Show()
end

-- Immersion (addon): quest text in ImmersionFrame.TalkBox (its "talking head"), with the quest's objectives and
-- rewards in a dark panel below it, TalkBox.Elements: a backdrop with 16px edges that Immersion shows only for
-- quests and resizes to its contents. The glow fills the panel's dark body, with its bottom corners rounded to the
-- panel's, drawn above the backdrop's dark edge pieces so it reaches the rim. The frame is wider than the dark
-- body (its edge art fades out softly), hence the inset. The logo goes in its top-right corner (the talking head's
-- corner holds Immersion's own buttons).
-- ImmersionFrame.lastEvent says what is showing; gossip is left alone.
local IMM = {
    EVENTS = { QUEST_DETAIL = true, QUEST_PROGRESS = true, QUEST_COMPLETE = true },
    INSET = 4,                 -- the glow's outer edge: its soft rim fades out just outside the dark body
    CORNER = 12,               -- corner piece size: radius ~8 (the panel's corners), rim ~4
    SCALE = 0.75, ALPHA = 0.6, -- a deeper glow on the dark panel, in a vivid version of the tint
    LOGO_SIZE = 24,
    LOGO_X = -18, LOGO_Y = -14, -- from the panel's top-right, level with its first heading
}

local immInner -- the panel's inside, for the glow to cover
local function RefreshImmersion()
    local frame = _G.ImmersionFrame
    local panel = frame and frame.TalkBox and frame.TalkBox.Elements
    if not panel then return end
    local show = frame:IsVisible() and panel:IsVisible() and IMM.EVENTS[frame.lastEvent] and IsMarked(GetQuestID())
    if show and ns.cfg.showTint then
        if not immInner then
            immInner = CreateFrame("Frame", nil, panel)
            immInner:SetPoint("TOPLEFT", IMM.INSET, -IMM.INSET)
            immInner:SetPoint("BOTTOMRIGHT", -IMM.INSET, IMM.INSET)
        end
        ApplyFlat("immersion", panel, immInner, IMM.SCALE, IMM.ALPHA, IMM.CORNER, "BORDER", true)
    else
        HideFlat("immersion")
    end
    ApplyBadge("immersion", panel, show and ns.cfg.showLogo, "TOPRIGHT", "TOPRIGHT", IMM.LOGO_X, IMM.LOGO_Y, IMM.LOGO_SIZE)
end

-- Immersion switches between gossip and quest text without hiding its window, so refresh after each of its
-- events (and once more on the next frame, once it has laid out the panel).
local immHooked = false
local function HookImmersion()
    local frame = _G.ImmersionFrame
    local panel = frame and frame.TalkBox and frame.TalkBox.Elements
    if immHooked or not panel or not frame.HookScript then return end
    immHooked = true
    local function refreshSoon()
        RefreshImmersion()
        C_Timer.After(0, RefreshImmersion)
    end
    frame:HookScript("OnEvent", refreshSoon)
    frame:HookScript("OnShow", refreshSoon)
    frame:HookScript("OnHide", RefreshImmersion)
    panel:HookScript("OnShow", refreshSoon)
    panel:HookScript("OnHide", RefreshImmersion)
    panel:HookScript("OnSizeChanged", RefreshImmersion) -- it grows to fit the objectives and rewards
    RefreshImmersion()
end

-- Lorewalker (addon), Classic mode: quest text in LWDialogFrame, on a page drawn by ContentFrame.BackgroundTexture
-- (a frame holding the real, sliced texture in __Texture, on ARTWORK). Its QuestFrame part is shown only for
-- quests, not gossip. The glow has the page's shape, its corners cut off at 45 degrees like the page's, inset from
-- the page's torn edges, above the page texture.
-- Lorewalker gives quests it considers new to Forever a page of its own; the tint and logo follow this addon's list.
-- Its Immersive and Story modes have no page, so they are left alone.
--
-- Like Dialogue UI's divider, Lorewalker draws a fade in the page's colour above the text over the buttons
-- (EdgeFade.EdgeFadeGradientTexture, tinted with its BackgroundColor), so text fades out as it scrolls under them.
-- It has to stay above the text, so instead of moving it, it is recoloured to the glowing page's colour at its
-- height (the page colour blended with the glow, as the glow blends it), and given back its own colour after.
local LW = {
    INSET = 10,                          -- the glow's outer edge, inside the page's torn edges
    CORNER = 22,                         -- chamfered corner piece size: a cut of ~12 along each side
                                         -- (parallel to the page's own 45 degree corners), rim ~3.5
    SCALE = 1, ALPHA = 0.55,             -- light pages: a vivid tint, a little over half strength
    DARK_SCALE = 0.75, DARK_ALPHA = 0.6, -- Dark theme: a deeper glow
    LOGO_SIZE = 24,
    LOGO_X = -62, -- from the right end of the title bar, clear of its settings and close buttons
}

local function LorewalkerDark(texture)
    local file = texture and texture:GetTexture()
    if type(file) == "string" then return file:lower():find("questbackgrounddark", 1, true) ~= nil end
    return type(LorewalkerDB_Global) == "table" and LorewalkerDB_Global.Theme == 2 -- Lorewalker's Theme: 2 = Dark
end

-- The edge fade's texture, and its own colour: whatever it has when it isn't the colour this addon last gave it.
local function LorewalkerEdgeFade(frame)
    local edge = frame.EdgeFade and frame.EdgeFade.EdgeFadeGradientTexture
    local tex = edge and edge.__Texture
    if not tex or not tex.GetVertexColor then return nil end
    local r, g, b, a = tex:GetVertexColor()
    local mine = tex.fqtGiven
    if not (mine and math.abs(r - mine[1]) < 0.002 and math.abs(g - mine[2]) < 0.002 and math.abs(b - mine[3]) < 0.002) then
        tex.fqtOwn = { r, g, b, a or 1 }
    end
    return tex, edge
end

local function TintLorewalkerEdgeFade(frame, on)
    local tex, edge = LorewalkerEdgeFade(frame)
    if not tex then return end
    local own = tex.fqtOwn
    local r, g, b, a
    if on then
        local top, bottom = edge:GetTop(), edge:GetBottom()
        r, g, b, a = FlatColourAt("lorewalker", top and bottom and (top + bottom) / 2)
    end
    if r then
        local mix = { own[1] + (r - own[1]) * a, own[2] + (g - own[2]) * a, own[3] + (b - own[3]) * a }
        tex.fqtGiven = mix
        tex:SetVertexColor(mix[1], mix[2], mix[3], own[4])
    elseif tex.fqtGiven then
        tex.fqtGiven = nil
        tex:SetVertexColor(own[1], own[2], own[3], own[4])
    end
end

local lwInner -- the page's inside, for the glow to cover
local function RefreshLorewalker()
    local frame = _G.LWDialogFrame
    local content = frame and frame.ContentFrame
    local page = content and content.BackgroundTexture
    if not page or not frame.QuestFrame then return end
    local show = frame:IsVisible() and frame.QuestFrame:IsShown() and IsMarked(GetQuestID())
    if show and ns.cfg.showTint then
        if not lwInner then
            lwInner = CreateFrame("Frame", nil, page)
            lwInner:SetPoint("TOPLEFT", LW.INSET, -LW.INSET)
            lwInner:SetPoint("BOTTOMRIGHT", -LW.INSET, LW.INSET)
        end
        local dark = LorewalkerDark(page.__Texture)
        ApplyFlat("lorewalker", page, lwInner, dark and LW.DARK_SCALE or LW.SCALE, dark and LW.DARK_ALPHA or LW.ALPHA,
            LW.CORNER, "ARTWORK", true, GLOW_CHAMFER)
        TintLorewalkerEdgeFade(frame, true)
    else
        HideFlat("lorewalker")
        TintLorewalkerEdgeFade(frame, false)
    end
    ApplyBadge("lorewalker", frame.TitleContainer, show and ns.cfg.showLogo, "RIGHT", "RIGHT", LW.LOGO_X, 0, LW.LOGO_SIZE)
end

-- Questie (addon): its quest icons on the world map and minimap. Each is a pooled frame named QuestieFrame<n>,
-- holding its quest in data.Id. Questie colours an icon's texture through SetVertexColor, a wrapper of its own that
-- remembers the colour it asked for in texture.r/g/b/a and reuses it when it fades icons. For a marked quest the
-- yellow ! (available) and ? (ready to turn in) get a gradient like the quest window's: over Questie's own icon, a
-- desaturated copy of it in the vivid tint, solid over the lower part and fading out quickly above it, so the icon is
-- teal below and its own clean yellow above (a long, even blend left a muddy olive middle, yellow and teal mixing). Questie's icon itself is never changed; the copy follows its alpha (minimap
-- fading) and hides while Questie shows anything but plain white (its hover highlight). Questie's grey, blue, event
-- and PvP icons are left alone. Questie's frames and modules are its internals, so each is checked before use.
local QUESTIE_ICON_TYPES = { "ICON_TYPE_AVAILABLE", "ICON_TYPE_COMPLETE" }
local QUESTIE_BRIGHTNESS = 1.15 -- the desaturated yellow is darker than the icon; lift the tint a little
local QUESTIE_SOLID = 0.45      -- the copy is solid over the bottom 45% of the icon...
local QUESTIE_FADE = 0.75       -- ...fading out by 75% of the way up; Questie's own yellow above
local questieFrames = {}

local function QuestieTintable(frame)
    local path = frame.fqtIcon
    if not path or type(Questie) ~= "table" or type(Questie.usedIcons) ~= "table" then return false end
    for _, key in ipairs(QUESTIE_ICON_TYPES) do
        if Questie[key] and Questie.usedIcons[Questie[key]] == path then return true end
    end
    return false
end

-- The icon gradient, shared by Questie's icons and the game's map pins: over `tex` (the icon), a desaturated copy of
-- its art (`file` and the art's texture coordinates l, r, t, b) in the vivid tint, solid over the bottom
-- QUESTIE_SOLID of the icon at strength `alpha`, fading out by QUESTIE_FADE; drawn on `owner` in `layer`/`sublevel`.
-- `height` is the icon's height. The two copy textures live on `owner`; show = false hides them.
local function ApplyIconGradient(owner, tex, show, file, l, r, t, b, height, alpha, layer, sublevel)
    local solid, fade = owner.fqtSolid, owner.fqtFade
    if not (show and file and height and height > 0) then
        if solid then
            solid:Hide()
            fade:Hide()
        end
        return
    end
    if not solid then
        solid = owner:CreateTexture(nil, layer, nil, sublevel)
        fade = owner:CreateTexture(nil, layer, nil, sublevel)
        owner.fqtSolid, owner.fqtFade = solid, fade
    end
    -- The vivid tint: the plain one, desaturated, came out a pale grey-cyan close to the map's own colours.
    local c = VividTint(ns.cfg.tint)
    local cr, cg, cb = math.min(1, c[1] * QUESTIE_BRIGHTNESS), math.min(1, c[2] * QUESTIE_BRIGHTNESS),
        math.min(1, c[3] * QUESTIE_BRIGHTNESS)
    -- A horizontal slice of the icon, from `from` to `to` of the way up, with its matching texture coordinates.
    local function slice(piece, from, to, alphaLow, alphaHigh)
        piece:SetDrawLayer(layer, sublevel)
        piece:ClearAllPoints()
        piece:SetPoint("BOTTOMLEFT", tex, "BOTTOMLEFT", 0, height * from)
        piece:SetPoint("BOTTOMRIGHT", tex, "BOTTOMRIGHT", 0, height * from)
        piece:SetHeight(height * (to - from))
        piece:SetTexture(file)
        piece:SetTexCoord(l, r, b + (t - b) * to, b + (t - b) * from)
        piece:SetDesaturated(true)
        piece:SetGradient("VERTICAL", CreateColor(cr, cg, cb, alphaLow), CreateColor(cr, cg, cb, alphaHigh))
        piece:Show()
    end
    slice(solid, 0, QUESTIE_SOLID, alpha, alpha)
    slice(fade, QUESTIE_SOLID, QUESTIE_FADE, alpha, 0)
end

local function ApplyQuestieTint(frame)
    local tex = frame.texture
    if not tex or not tex.OLDSetVertexColor then return end
    local plain = (tex.r or 1) == 1 and (tex.g or 1) == 1 and (tex.b or 1) == 1
    local data = frame.data
    local show = ns.cfg.questieTint and plain and data and IsMarked(data.Id) and QuestieTintable(frame)
    local ulx, uly, _, _, _, _, lrx, lry = tex:GetTexCoord()
    -- The frame's own size (Questie sets it with SetSize): the texture takes its size from the frame's position, which
    -- isn't known yet when Questie colours an icon before placing it on the map. Above Questie's icon (OVERLAY 0),
    -- level with its starter overlay, which is drawn outside the icon's shape.
    ApplyIconGradient(frame, tex, show, frame.fqtIcon, ulx, lrx, uly, lry, frame:GetHeight(), tex.a or 1, "OVERLAY", 1)
end

local function HookQuestieFrame(frame)
    if not frame or frame.fqtQuestieHooked or not frame.texture or type(frame.texture.SetVertexColor) ~= "function"
        or type(frame.UpdateTexture) ~= "function" then return end
    frame.fqtQuestieHooked = true
    questieFrames[#questieFrames + 1] = frame
    -- After Questie's own colouring, whether from a redraw, a fade or the end of a hover highlight.
    hooksecurefunc(frame.texture, "SetVertexColor", function() ApplyQuestieTint(frame) end)
    -- The icon file says which kind of icon it is; Questie can swap it (grey ! to yellow on a level up).
    hooksecurefunc(frame, "UpdateTexture", function(_, path)
        frame.fqtIcon = path
        ApplyQuestieTint(frame)
    end)
    -- Questie sizes the icon after colouring it, and again when its scale options change.
    if frame.HookScript then frame:HookScript("OnSizeChanged", function() ApplyQuestieTint(frame) end) end
    frame.fqtIcon = frame.texture:GetTexture()
    ApplyQuestieTint(frame)
end

local questieHooked = false
local function HookQuestie()
    if questieHooked or type(QuestieLoader) ~= "table" or type(QuestieLoader._modules) ~= "table" then return end
    local module = QuestieLoader._modules.QuestieFrame
    if type(module) ~= "table" or type(module.CreateIconFrame) ~= "function" then return end
    questieHooked = true
    -- Questie's pool makes icon frames as it needs them: catch each new one, then any it already made.
    hooksecurefunc(module, "CreateIconFrame", function(frameId)
        HookQuestieFrame(_G["QuestieFrame" .. tostring(frameId)])
    end)
    local i = 1
    while _G["QuestieFrame" .. i] do
        HookQuestieFrame(_G["QuestieFrame" .. i])
        i = i + 1
    end
end

local function RefreshQuestie()
    for _, frame in ipairs(questieFrames) do ApplyQuestieTint(frame) end
end

-- The game's own world map pins (Forever's map, like retail's), for players without Questie: quest givers
-- (QuestOfferPinTemplate: pin.Texture, the yellow ! is the QuestNormal atlas, quest in pin.questID; trivial quests
-- are drawn at half alpha and left alone, like Questie's grey !) and quests (QuestPinTemplate, a POI button:
-- pin.Display.Icon, the plain turn-in ? is UI-QuestIcon-TurnIn-Normal, quest from pin:GetQuestID()). The same
-- gradient as Questie's icons, on the plain yellow icons only; campaign, daily, legendary and other special icons are
-- left alone. Pins are pooled, so each is hooked to look again whenever the map reuses it.
-- Kept in one table: the file is near Lua's limit of 200 locals in one scope.
local MapPins = { seen = setmetatable({}, { __mode = "k" }), hooked = false }
MapPins.icons = {
    QuestOfferPinTemplate = {
        atlas = "QuestNormal",
        texture = function(pin) return pin.Texture end,
        questID = function(pin) return pin.questID end,
        wanted = function(pin) return (pin.pinAlpha or 1) >= 1 end,
    },
    QuestPinTemplate = {
        atlas = "UI-QuestIcon-TurnIn-Normal",
        texture = function(pin) return pin.Display and pin.Display.Icon end,
        questID = function(pin) return pin.GetQuestID and pin:GetQuestID() end,
    },
}

function MapPins.Apply(pin, kind)
    local tex = kind.texture(pin)
    if not (tex and tex.GetAtlas) then return end
    local owner = tex:GetParent()
    local atlas = tex:GetAtlas()
    local show = ns.cfg.questieTint and atlas == kind.atlas and (not kind.wanted or kind.wanted(pin))
        and IsMarked(kind.questID(pin))
    local info = show and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    if not info then
        ApplyIconGradient(owner, tex, false)
        return
    end
    local layer, sublevel = tex:GetDrawLayer()
    local height = tex:GetHeight()
    if not height or height <= 0 then height = owner:GetHeight() end
    ApplyIconGradient(owner, tex, true, info.file or info.filename, info.leftTexCoord, info.rightTexCoord,
        info.topTexCoord, info.bottomTexCoord, height, 1, layer, math.min((sublevel or 0) + 1, 7))
end

function MapPins.Refresh()
    local map = _G.WorldMapFrame
    if not (map and map.EnumeratePinsByTemplate) then return end
    for template, kind in pairs(MapPins.icons) do
        for pin in map:EnumeratePinsByTemplate(template) do
            if not MapPins.seen[pin] then
                MapPins.seen[pin] = true
                if type(pin.OnAcquired) == "function" then
                    hooksecurefunc(pin, "OnAcquired", function(self) MapPins.Apply(self, kind) end)
                end
            end
            MapPins.Apply(pin, kind)
        end
    end
end

-- The map lays out its pins as it opens, changes map or refreshes; look over them just after.
function MapPins.Hook()
    local map = _G.WorldMapFrame
    if MapPins.hooked or not (map and map.EnumeratePinsByTemplate and map.HookScript) then return end
    MapPins.hooked = true
    local function soon() C_Timer.After(0, MapPins.Refresh) end
    map:HookScript("OnShow", soon)
    for _, method in ipairs({ "OnMapChanged", "RefreshAllDataProviders" }) do
        if type(map[method]) == "function" then hooksecurefunc(map, method, soon) end
    end
    MapPins.Refresh()
end

local lwHooked = false
local function HookLorewalker()
    local frame = _G.LWDialogFrame
    if lwHooked or not frame or not frame.QuestFrame or not frame.HookScript then return end
    lwHooked = true
    local function refreshSoon()
        RefreshLorewalker()
        C_Timer.After(0, RefreshLorewalker)
    end
    frame:HookScript("OnShow", refreshSoon)
    frame:HookScript("OnHide", RefreshLorewalker)
    frame.QuestFrame:HookScript("OnShow", refreshSoon)
    frame.QuestFrame:HookScript("OnHide", RefreshLorewalker)
    -- The window can be resized, and the page swaps its texture with the theme and the quest.
    local page = frame.ContentFrame and frame.ContentFrame.BackgroundTexture
    if page and page.HookScript then page:HookScript("OnSizeChanged", RefreshLorewalker) end
    if page and page.__Texture then hooksecurefunc(page.__Texture, "SetTexture", refreshSoon) end
    -- One quest can follow another without the window closing in between.
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING", "QUEST_FINISHED", "GOSSIP_SHOW" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", refreshSoon)
    RefreshLorewalker()
end

-- Storyline (addon): quest text in a speech bubble (Storyline_NPCFrameChat) along the bottom of its scene, a dark
-- chat-bubble backdrop whose dark body reaches almost to its thin border line. The glow fills that body, with its
-- bottom corners rounded to the bubble's, drawn above the backdrop's dark edge pieces so it reaches the rim; the
-- scene above is zone art and is left alone. Storyline_NPCFrameChat.event is what the bubble is showing.
local SL = {
    EVENTS = { QUEST_DETAIL = true, QUEST_PROGRESS = true, QUEST_COMPLETE = true },
    INSET = 2,                 -- the glow's outer edge, just inside the bubble's border line
    CORNER = 6,                -- corner piece size: radius ~4 (the bubble's tight corners), rim ~2
    SCALE = 0.75, ALPHA = 0.6, -- a deeper glow on the dark bubble, in a vivid version of the tint
    LOGO_SIZE = 24,
    LOGO_X = -16, LOGO_Y = -10, -- from the bubble's top-right, in the margin beside the NPC's name
}

local slInner -- the bubble's inside, for the wash to cover
local function RefreshStoryline()
    local frame, chat = _G.Storyline_NPCFrame, _G.Storyline_NPCFrameChat
    if not frame or not chat then return end
    local show = frame:IsVisible() and chat:IsVisible() and SL.EVENTS[chat.event] and IsMarked(GetQuestID())
    if show and ns.cfg.showTint then
        if not slInner then
            slInner = CreateFrame("Frame", nil, chat)
            slInner:SetPoint("TOPLEFT", SL.INSET, -SL.INSET)
            slInner:SetPoint("BOTTOMRIGHT", -SL.INSET, SL.INSET)
        end
        ApplyFlat("storyline", chat, slInner, SL.SCALE, SL.ALPHA, SL.CORNER, "BORDER", true)
    else
        HideFlat("storyline")
    end
    ApplyBadge("storyline", chat, show and ns.cfg.showLogo, "TOPRIGHT", "TOPRIGHT", SL.LOGO_X, SL.LOGO_Y, SL.LOGO_SIZE)
end

local slHooked = false
local function HookStoryline()
    local frame, chat = _G.Storyline_NPCFrame, _G.Storyline_NPCFrameChat
    if slHooked or not frame or not chat or not frame.HookScript then return end
    slHooked = true
    local function refreshSoon()
        RefreshStoryline()
        C_Timer.After(0, RefreshStoryline)
    end
    frame:HookScript("OnShow", refreshSoon)
    frame:HookScript("OnHide", RefreshStoryline)
    -- The bubble grows and shrinks with each page of text.
    chat:HookScript("OnSizeChanged", RefreshStoryline)
    -- Each new dialogue (and so each quest event) starts here.
    local api = _G.Storyline_API
    if type(api) == "table" and type(api.startDialog) == "function" then
        hooksecurefunc(api, "startDialog", refreshSoon)
    end
    RefreshStoryline()
end

local ICON_PATH = "Interface\\AddOns\\ForeverQuestTint\\Media\\Infinity.tga"
-- The visible infinity sign inside Infinity.tga (a 64x64 image), in pixels.
local ICON_L, ICON_R, ICON_T, ICON_B = 1, 63, 12, 51
local ICON_ASPECT = (ICON_R - ICON_L) / (ICON_B - ICON_T)
-- The icon is drawn this many pixels lower than centred so it sits on the text baseline. The
-- "Icon vertical position" option is relative to this.
local ICON_BASELINE = -2

local function MarkerGlyph()
    local cfg = ns.cfg
    local c = cfg.markerUseTint and cfg.tint or cfg.markerColor
    local r, g, b = math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)
    if cfg.markerIcon then
        -- |T path : height : width : offX : offY : texW : texH : left : right : top : bottom : red : green : blue |t
        -- The texture is cropped to the infinity sign itself, so "height" is the visible height.
        local h = cfg.markerHeight
        local w = math.floor(h * ICON_ASPECT + 0.5)
        -- The x offset moves the drawn image without changing the text layout, so a positive gap
        -- pushes an icon after the name away from it (and a negative one, for an icon before it).
        local offX = cfg.markerAtStart and -cfg.markerGap or cfg.markerGap
        return ("|T%s:%d:%d:%d:%d:64:64:%d:%d:%d:%d:%d:%d:%d|t"):format(
            ICON_PATH, h, w, offX, cfg.markerOffset + ICON_BASELINE, ICON_L, ICON_R, ICON_T, ICON_B, r, g, b)
    end
    return ("|cff%02x%02x%02x%s|r"):format(r, g, b, cfg.markerSymbol)
end

local titleMap, BuildTitleMap, StripPrefixes -- defined further down; the SetText hook needs them

-- Sets fs's text to the marked (or original) version. Remembers the original so this can be
-- re-run safely, including after Blizzard rewrites the text. With padBlock, an entry whose
-- marker adds a wrapped line also gets its block made taller by that line, because the tracker
-- measured the block before the marker was added. With keep, the marker is put back whenever
-- the text is rewritten (tracker headers, and the flat lists of other addons' quest watches).
-- The logo beside a marked quest in the objective tracker: a small badge at the top-right of its block, level with
-- the quest name. Blocks are pooled, so a reused block hides it again until its new quest is marked.
local TRACKER_LOGO_SIZE = 14
local TRACKER_LOGO_X, TRACKER_LOGO_Y = 0, 1 -- from the block's top-right corner (negative x = further in)

local function UpdateTrackerLogo(block, wanted)
    if not block or not block.CreateTexture then return end
    local badge = block.fqtLogo
    if not (wanted and ns.cfg.trackerLogo) then
        if badge then badge:Hide() end
        return
    end
    if not badge then
        badge = block:CreateTexture(nil, "OVERLAY")
        badge:SetTexture(LOGO_PATH)
        badge:SetSize(TRACKER_LOGO_SIZE, TRACKER_LOGO_SIZE)
        badge:SetPoint("TOPRIGHT", block, "TOPRIGHT", TRACKER_LOGO_X, TRACKER_LOGO_Y)
        block.fqtLogo = badge
    end
    badge:Show()
end

local function ApplyMarker(fs, wanted, padBlock, keep)
    local cur = fs:GetText()
    if not cur then return end
    local base = cur
    if fs.fqtMarked and cur == fs.fqtMarked then
        base = fs.fqtBase
    end
    local new = base
    local useMarker = wanted and ns.cfg.marker and (ns.cfg.markerIcon or ns.cfg.markerSymbol ~= "")
    if useMarker then
        if ns.cfg.markerAtStart then
            new = MarkerGlyph() .. " " .. base
        else
            new = base .. " " .. MarkerGlyph()
        end
    end
    fs.fqtBase = base
    if new ~= cur then
        fs.fqtPad = 0
        if padBlock and useMarker and fs.GetStringHeight then
            fs:SetText(base)
            local baseHeight = fs:GetStringHeight()
            fs:SetText(new)
            fs.fqtPad = math.max(0, fs:GetStringHeight() - baseHeight)
        else
            fs:SetText(new)
        end
    end
    fs.fqtMarked = new

    -- Blizzard rewrites tracker headers on every re-layout (moving an item, tracking a recipe);
    -- a deferred scan would only restore the marker a frame later, which shows as a blink. Re-mark
    -- the moment the text is set instead.
    if (padBlock or keep) and not fs.fqtHooked and fs.SetText then
        fs.fqtHooked = true
        fs.fqtPadBlock = padBlock
        hooksecurefunc(fs, "SetText", function(self)
            if self.fqtRemarking then return end
            local text = self:GetText()
            if not text or text == "" or text == self.fqtMarked then return end
            if not titleMap then BuildTitleMap() end
            -- Unmarked text too, so a reused tracker block drops its logo at once.
            local isMarked = titleMap[text] or titleMap[StripPrefixes(text)]
            self.fqtRemarking = true
            ApplyMarker(self, isMarked, self.fqtPadBlock)
            self.fqtRemarking = nil
        end)
    end

    if padBlock then
        local block = fs.GetParent and fs:GetParent()
        UpdateTrackerLogo(block, wanted)
        local pad = useMarker and fs.fqtPad or 0
        if block and block.SetHeight then
            local h = block:GetHeight()
            if pad > 0 then
                -- Blizzard resets the block's height whenever it lays out the tracker, so
                -- re-add the padding whenever the height is not the padded one.
                if not block.fqtPaddedHeight or math.abs(h - block.fqtPaddedHeight) > 0.5 then
                    block:SetHeight(h + pad)
                    block.fqtPaddedHeight = h + pad
                end
            elseif block.fqtPaddedHeight then
                if math.abs(h - block.fqtPaddedHeight) <= 0.5 then
                    block:SetHeight(h - (fs.fqtLastPad or 0))
                end
                block.fqtPaddedHeight = nil
            end
            fs.fqtLastPad = pad
        end
    end
end

-- Objective lines ("- 0/5 Darkhound Blood"): optionally recoloured for non-vanilla quests. Only
-- lines that are the default white/grey are touched, so completed (green) or failed (red)
-- objectives keep their colour.
local function ObjectiveRGB()
    local cfg = ns.cfg
    local c = cfg.objectiveUseTint and cfg.tint or cfg.objectiveColor
    return c[1], c[2], c[3]
end

local function IsDefaultTextColour(r, g, b)
    return math.max(r, g, b) > 0.6 and math.max(r, g, b) - math.min(r, g, b) < 0.12
end

local function Near(a, b)
    return math.abs(a - b) < 0.01
end

local function SetObjectiveColour(fs, on)
    if not fs.GetTextColor then return end
    local cr, cg, cb, ca = fs:GetTextColor()
    if not cr then return end
    if on then
        local r, g, b = ObjectiveRGB()
        if Near(cr, r) and Near(cg, g) and Near(cb, b) then return end
        if IsDefaultTextColour(cr, cg, cb) or fs.fqtOrigColour then
            -- Remember the colour Blizzard chose, once, so it can be put back.
            if not fs.fqtOrigColour or IsDefaultTextColour(cr, cg, cb) then
                fs.fqtOrigColour = { cr, cg, cb, ca or 1 }
            end
            fs:SetTextColor(r, g, b)
        end
    elseif fs.fqtOrigColour then
        local o = fs.fqtOrigColour
        fs.fqtOrigColour = nil
        local r, g, b = ObjectiveRGB()
        if Near(cr, r) and Near(cg, g) and Near(cb, b) then
            fs:SetTextColor(o[1], o[2], o[3], o[4])
        end
    end
end

local function ColourLogObjectives()
    local pool = QuestScrollFrame and QuestScrollFrame.objectiveFramePool
    if not pool then return end
    for frame in pool:EnumerateActive() do
        if frame.Text then
            SetObjectiveColour(frame.Text, ns.cfg.objectiveTint and IsMarked(frame.questID) and true or false)
        end
    end
end

local function RefreshLogList()
    if not QuestScrollFrame or not QuestScrollFrame.titleFramePool then return end
    for button in QuestScrollFrame.titleFramePool:EnumerateActive() do
        if button.Text then
            ApplyMarker(button.Text, IsMarked(button.questID))
        end
    end
    ColourLogObjectives()
end

-- Quest log access differs between clients: prefer C_QuestLog, fall back to the old globals.
local function NumLogEntries()
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        return (C_QuestLog.GetNumQuestLogEntries())
    end
    return GetNumQuestLogEntries and (GetNumQuestLogEntries()) or 0
end

local function LogEntry(i)
    if C_QuestLog and C_QuestLog.GetInfo then
        local info = C_QuestLog.GetInfo(i)
        if info then return info.title, info.isHeader, info.questID end
        return
    end
    if GetQuestLogTitle then
        local title, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(i)
        return title, isHeader, questID
    end
end

function BuildTitleMap()
    titleMap = {}
    for i = 1, NumLogEntries() do
        local title, isHeader, questID = LogEntry(i)
        if title and not isHeader then
            -- A title shared with a vanilla quest counts as vanilla.
            if titleMap[title] == nil then
                titleMap[title] = IsMarked(questID) and true or false
            elseif not IsMarked(questID) then
                titleMap[title] = false
            end
        end
    end
end

-- Tracker headers can carry a quest ID ("123 - Title") and/or a level ("[8] Title").
function StripPrefixes(text)
    -- The tracker wraps names in colour codes ("|cffffd100[6] Title|r") and may add icons.
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")
    text = text:gsub("^%s+", "")
    text = text:gsub("^%d+ %- ", "")
    text = text:gsub("^%[[^%]]*%]%s*", "")
    return text
end

local function TrackerSetLine(line, _, _, isHeader, text)
    if not isHeader or type(text) ~= "string" then return end
    if not titleMap then BuildTitleMap() end
    local wanted = titleMap[text] or titleMap[StripPrefixes(text)]
    ApplyMarker(line.text, wanted)
end

-- The objective tracker differs between clients, so as well as hooking the older WatchFrame
-- function, look through the tracker's text lines whenever it updates and mark quest names.
-- Scans can be frequent, so it walks regions and children with select() over the
-- varargs instead of packing them into a new table per frame, and tracks visited frames in a
-- reusable table rather than a fresh one per scan.
local ColourBlockObjectives

local function ColourRegions(headerFs, on, ...)
    for i = 1, select("#", ...) do
        local region = select(i, ...)
        if region ~= headerFs and region.GetObjectType and region:GetObjectType() == "FontString" then
            SetObjectiveColour(region, on)
        end
    end
end

local function ColourChildren(headerFs, on, ...)
    for i = 1, select("#", ...) do
        ColourBlockObjectives((select(i, ...)), headerFs, on)
    end
end

function ColourBlockObjectives(block, headerFs, on)
    ColourRegions(headerFs, on, block:GetRegions())
    ColourChildren(headerFs, on, block:GetChildren())
end

local scanGen = 0
local scanSeen = setmetatable({}, { __mode = "k" })
local scanFlat = false -- scanning a flat list of lines (another addon's quest watch), not the tracker's blocks
local ScanTracker

local function ScanRegion(region)
    if not (region.GetObjectType and region:GetObjectType() == "FontString") then return end
    local text = region:GetText()
    if not text or text == "" then return end
    local base = (region.fqtMarked and text == region.fqtMarked) and region.fqtBase or text
    local wanted = titleMap[base] or titleMap[StripPrefixes(base)]
    if wanted or region.fqtMarked then
        -- A flat list's lines all share one parent, so there is no block to pad (or to recolour below).
        ApplyMarker(region, wanted, not scanFlat, true)
    end
    if scanFlat then return end
    local colourOn = wanted and ns.cfg.objectiveTint
    if colourOn or region.fqtColouredBlock then
        local block = region.GetParent and region:GetParent()
        if colourOn and block then
            ColourBlockObjectives(block, region, true)
            region.fqtColouredBlock = block
        elseif region.fqtColouredBlock then
            ColourBlockObjectives(region.fqtColouredBlock, region, false)
            region.fqtColouredBlock = nil
        end
    end
end

local function ScanRegions(...)
    for i = 1, select("#", ...) do ScanRegion((select(i, ...))) end
end

local function ScanChildren(...)
    for i = 1, select("#", ...) do ScanTracker((select(i, ...))) end
end

function ScanTracker(frame)
    if scanSeen[frame] == scanGen then return end
    scanSeen[frame] = scanGen
    ScanRegions(frame:GetRegions())
    ScanChildren(frame:GetChildren())
end

-- Lists of quest names to mark besides the tracker: ClassicUI Forever's quest watch and quest log list.
-- Filled in by HookCUIF.
local flatRoots = {}

local function AnyRootVisible()
    local root = ObjectiveTrackerFrame or WatchFrame
    if root and root:IsVisible() then return true end
    for _, flat in ipairs(flatRoots) do
        if flat:IsVisible() then return true end
    end
    return false
end

local pollFailed = false
local function ScanOnce()
    if not AnyRootVisible() then return end
    if not titleMap then BuildTitleMap() end
    scanGen = scanGen + 1
    local root = ObjectiveTrackerFrame or WatchFrame
    if root and root:IsVisible() then ScanTracker(root) end
    scanFlat = true
    for _, flat in ipairs(flatRoots) do
        if flat:IsVisible() then ScanTracker(flat) end
    end
    scanFlat = false
end

local function ScanOnceWrapper()
    ScanOnce()
    if ns.cfg.objectiveTint and QuestMapFrame and QuestMapFrame:IsVisible() then
        ColourLogObjectives()
    end
end

-- Any number of triggers in a frame collapse into one scan on the next frame.
local scanPending = false
local function RunScan()
    scanPending = false
    if pollFailed then return end
    -- If this ever errors, report it once and stop rather than erroring on every update.
    local ok, err = pcall(ScanOnceWrapper)
    if not ok then
        pollFailed = true
        print("|cffff5555Forever Quest Tint:|r tracker markers disabled after an error: " .. tostring(err))
    end
end

local function QueueScan()
    if scanPending or pollFailed then return end
    if not AnyRootVisible() then return end -- skipped while hidden; OnShow queues one
    scanPending = true
    C_Timer.After(0, RunScan)
end

local function RefreshTracker()
    if WatchFrame_Update and WatchFrame and not InCombatLockdown() then
        titleMap = nil
        WatchFrame_Update()
    end
end

-- ClassicUI Forever (addon): its 1.x quest log window and its Era quest watch, both built on first use and found
-- through its public API (ClassicUIForeverAPI.GetFrame). The parts used below (the log's detail pane and list area)
-- are its internals, so each is checked before use. Its quest-giver window is the game's and its map pane's parchment
-- is handled in TintLogFrame, so the tint above covers those already.
-- Its quest log page is part of the window's art (two textures side by side in the double pane, four in the single),
-- so, as with the game's own parchment, the tint is a desaturated, tinted copy of that art: of the part of each art
-- texture under the bottom of the page: the detail pane, widened to the page's burnt edges (measured from its art,
-- per layout). It follows the paper right to its burnt, torn edges, in the plain tint, matching the game's own
-- quest window and log on the same parchment. A page one of its dark themes has inked gets the soft glow instead,
-- since a copy of a dark page stays dark.
local CUIF_DARK_SCALE, CUIF_DARK_ALPHA = 0.75, 0.6 -- the glow on a dark page
local CUIF_INSET = 8                              -- the glow's outer edge, inside the page's burnt edges
local CUIF_CORNER = 16                            -- glow corner piece size: radius ~11, rim ~5
-- How far the page's burnt edges reach past the detail pane, in the window's units (from its art): its double pane
-- (frame.dual, UI-QuestLogDualPane-*) and its single pane (UI-QuestLog-*).
local CUIF_PAGE_PAD = {
    dual = { left = 2, right = 5, bottom = 3 },
    single = { left = 4, right = 0, bottom = 1 },
}
local cuifCopies = {} -- copy textures, in use order
local cuifOwn = {}    -- this addon's textures on the window, never copied themselves

local function HideCUIFCopies()
    for _, copy in ipairs(cuifCopies) do copy:Hide() end
end

-- Returns false when there was nothing to copy, or the page is dark.
local function ApplyCUIFCopies(frame, detail)
    local left, right, bottom, top = detail:GetLeft(), detail:GetRight(), detail:GetBottom(), detail:GetTop()
    if not (left and right and bottom and top) or right <= left or top <= bottom then
        HideCUIFCopies()
        return false
    end
    local pad = frame.dual and CUIF_PAGE_PAD.dual or CUIF_PAGE_PAD.single
    left, right, bottom = left - pad.left, right + pad.right, bottom - pad.bottom
    local cfg = ns.cfg
    local fadeTop = bottom + (top - bottom) * cfg.height
    if fadeTop <= bottom then
        HideCUIFCopies()
        return false
    end
    local c = cfg.tint
    local function alphaAt(y)
        return cfg.topAlpha + (cfg.alpha - cfg.topAlpha) * (1 - (y - bottom) / (fadeTop - bottom))
    end
    local used, dark = 0, false
    for _, art in ipairs({ frame:GetRegions() }) do
        if not cuifOwn[art] and art.GetTexture and art:IsShown() and art:GetDrawLayer() == "BACKGROUND" then
            local file = art:GetTexture()
            local L, R, B, T = art:GetLeft(), art:GetRight(), art:GetBottom(), art:GetTop()
            local x0, x1 = L and math.max(L, left), R and math.min(R, right)
            local y0, y1 = B and math.max(B, bottom), T and math.min(T, fadeTop)
            if file and L and R > L and T > B and x1 > x0 and y1 > y0 then
                if IsInkedDark(art) then dark = true end
                used = used + 1
                local copy = cuifCopies[used]
                if not copy then
                    copy = frame:CreateTexture(nil, "BACKGROUND", nil, 7)
                    cuifCopies[used] = copy
                    cuifOwn[copy] = true
                end
                -- The matching slice of the art's own texture coordinates.
                local ulx, uly, _, _, _, _, lrx, lry = art:GetTexCoord()
                local function u(x) return ulx + (lrx - ulx) * (x - L) / (R - L) end
                local function v(y) return uly + (lry - uly) * (T - y) / (T - B) end
                copy:ClearAllPoints()
                copy:SetPoint("BOTTOMLEFT", art, "BOTTOMLEFT", x0 - L, y0 - B)
                copy:SetSize(x1 - x0, y1 - y0)
                copy:SetTexture(file)
                copy:SetTexCoord(u(x0), u(x1), v(y1), v(y0))
                copy:SetDesaturated(true)
                copy:SetGradient("VERTICAL", CreateColor(c[1], c[2], c[3], alphaAt(y0)),
                    CreateColor(c[1], c[2], c[3], alphaAt(y1)))
                copy:Show()
            end
        end
    end
    for i = used + 1, #cuifCopies do cuifCopies[i]:Hide() end
    if dark then
        HideCUIFCopies()
        return false
    end
    return used > 0
end

local function CUIFFrame(name)
    local api = _G.ClassicUIForeverAPI
    if not (api and api.GetFrame) then return nil end
    local ok, frame = pcall(api.GetFrame, name)
    return ok and frame or nil
end

-- The log shows the quest it last selected through C_QuestLog.SetSelectedQuest. (When nothing is selected it may
-- show its first quest without selecting it; that page stays plain until a quest is picked.)
local function RefreshCUIFLog()
    local frame = CUIFFrame("questLog")
    local detail = frame and frame.detail
    if not detail then return end
    local id = C_QuestLog and C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest()
    if ns.cfg.showTint and frame:IsVisible() and detail:IsShown() and IsMarked(id) then
        if ApplyCUIFCopies(frame, detail) then
            HideFlat("cuifLog")
            return
        end
        if not frame.fqtInner then
            frame.fqtInner = CreateFrame("Frame", nil, frame)
            frame.fqtInner:SetPoint("TOPLEFT", detail, "TOPLEFT", CUIF_INSET, -CUIF_INSET)
            frame.fqtInner:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -CUIF_INSET, CUIF_INSET)
        end
        ApplyFlat("cuifLog", frame, frame.fqtInner, CUIF_DARK_SCALE, CUIF_DARK_ALPHA, CUIF_CORNER, "BACKGROUND", true)
        for _, tex in ipairs(flats.cuifLog.fqtPieces) do cuifOwn[tex] = true end
        cuifOwn[flats.cuifLog] = true
    else
        HideCUIFCopies()
        HideFlat("cuifLog")
    end
end

local cuifHooked = {}
local function AddFlatRoot(root)
    if not root or not root.HookScript then return end
    for _, flat in ipairs(flatRoots) do
        if flat == root then return end
    end
    table.insert(flatRoots, root)
    root:HookScript("OnShow", QueueScan)
    QueueScan()
end

local function HookCUIF()
    if not _G.ClassicUIForeverAPI then return end
    if not cuifHooked.select and C_QuestLog and C_QuestLog.SetSelectedQuest then
        cuifHooked.select = true
        hooksecurefunc(C_QuestLog, "SetSelectedQuest", function()
            RefreshCUIFLog()
            C_Timer.After(0, RefreshCUIFLog)
        end)
    end
    local watch = CUIFFrame("questWatch")
    if watch then
        cuifHooked.watch = true
        AddFlatRoot(watch)
    end
    local log = CUIFFrame("questLog")
    if log and not cuifHooked.log and log.detail then
        cuifHooked.log = true
        log:HookScript("OnShow", RefreshCUIFLog)
        log:HookScript("OnHide", RefreshCUIFLog)
        log.detail:HookScript("OnShow", RefreshCUIFLog)
        log.detail:HookScript("OnHide", RefreshCUIFLog)
        log.detail:HookScript("OnSizeChanged", RefreshCUIFLog) -- single and double pane layouts
        AddFlatRoot(log.listArea)
    end
    RefreshCUIFLog()
end

-- Questie's own quest tracker (in place of the game's): a pool of lines, linePool1..250, each with a label and, on
-- a quest title line, mode "quest" and its quest in line.Quest, set before the title is written. The marker goes on
-- as Questie writes the title, so its measuring right after already includes it. Objective lines and zone headers
-- are left alone. The lines are Questie's internals, so each is checked before use.
local questieLines = {}

local function MarkQuestieLine(line)
    local quest = line.mode == "quest" and type(line.Quest) == "table" and line.Quest
    local label = line.label
    if not label then return end
    label.fqtRemarking = true
    ApplyMarker(label, quest and IsMarked(quest.Id) or false)
    label.fqtRemarking = nil
end

local function RefreshQuestieTracker()
    for _, line in ipairs(questieLines) do
        if line:IsShown() then MarkQuestieLine(line) end
    end
end

-- Questie builds its tracker once it is ready, a moment after login, and writes the titles straight away: so once
-- hooked, the titles already showing are marked too (otherwise they stayed plain until Questie next rewrote them).
local questieReadyHooked = false
local function HookQuestieTracker()
    if type(QuestieLoader) ~= "table" then return end
    local api = type(Questie) == "table" and Questie.API
    if not questieReadyHooked and type(api) == "table" and type(api.RegisterOnReady) == "function" then
        questieReadyHooked = true
        -- Its tracker draws its first titles just after: look again a moment later as well.
        local function catchUp()
            HookQuestieTracker()
            RefreshQuestieTracker()
        end
        pcall(api.RegisterOnReady, function()
            C_Timer.After(0, catchUp)
            C_Timer.After(2, catchUp)
        end)
    end
    if #questieLines > 0 then return end
    local i = 1
    while true do
        local line = _G["linePool" .. i]
        if not (line and line.label and type(line.SetQuest) == "function" and line.expandQuest) then break end
        questieLines[i] = line
        hooksecurefunc(line.label, "SetText", function(label)
            if not label.fqtRemarking then MarkQuestieLine(line) end
        end)
        i = i + 1
    end
    RefreshQuestieTracker()
end

local listHooked, trackerHooked, eventsHooked = false, false, false
local function HookMarkers()
    -- Each hook installs independently, so a missing function in one doesn't block the other.
    if not listHooked and QuestLogQuests_Update then
        listHooked = true
        hooksecurefunc("QuestLogQuests_Update", RefreshLogList)
    end
    if not trackerHooked and WatchFrame_SetLine then
        trackerHooked = true
        hooksecurefunc("WatchFrame_SetLine", TrackerSetLine)
    end
    if not eventsHooked then
        eventsHooked = true
        -- Redraws of the tracker and its containers, plus its OnShow, trigger a scan.
        for _, name in ipairs({ "ObjectiveTracker_Update", "WatchFrame_Update", "QuestObjectiveTracker_Update" }) do
            if type(_G[name]) == "function" then hooksecurefunc(name, QueueScan) end
        end
        local root = ObjectiveTrackerFrame or WatchFrame
        if root then
            if root.HookScript then root:HookScript("OnShow", QueueScan) end
            if type(root.Update) == "function" then hooksecurefunc(root, "Update", QueueScan) end
            -- Older clients list the modules in MODULES; Midnight's container keeps them in modules.
            for _, module in pairs(root.MODULES or root.modules or {}) do
                if type(module) == "table" then
                    for _, fn in ipairs({ "Update", "MarkDirty", "LayoutContents" }) do
                        if type(module[fn]) == "function" then hooksecurefunc(module, fn, QueueScan) end
                    end
                end
            end
        end
        local ev = CreateFrame("Frame")
        for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN",
                "QUEST_WATCH_UPDATE", "QUEST_WATCH_LIST_CHANGED", "SUPER_TRACKING_CHANGED", "PLAYER_ENTERING_WORLD" }) do
            pcall(ev.RegisterEvent, ev, e) -- not every event exists on every client
        end
        ev:SetScript("OnEvent", function(_, event)
            if event ~= "PLAYER_ENTERING_WORLD" then titleMap = nil end
            HookCUIF() -- its windows are built on first use
            HookQuestieTracker() -- built once Questie is ready
            QueueScan()
        end)
        QueueScan()
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        local db = ForeverQuestTintDB or {}
        -- Earlier builds stored the absolute vertical nudge; it is now relative to ICON_BASELINE.
        if db.markerOffset ~= nil and not db.markerOffsetRelative then
            db.markerOffset = db.markerOffset - ICON_BASELINE
        end
        db.markerOffsetRelative = true
        -- 0.5.5 briefly changed the default tint for everyone; put anyone still on that colour back.
        local t = db.tint
        if db.vividTint and t and math.abs(t[1] - 0.30) < 0.01 and math.abs(t[2] - 0.95) < 0.01 and math.abs(t[3] - 1.00) < 0.01 then
            db.tint = { 0.60, 0.90, 0.95 }
        end
        db.vividTint = nil
        ForeverQuestTintDB = CopyDefaults(db, ns.defaults)
        ns.cfg = ForeverQuestTintDB
    end
    if event == "PLAYER_LOGIN" and ns.cfg.preview ~= "auto" then
        -- The preview is saved between sessions, so make sure it is never left on by accident.
        print(("|cff99e6f2Forever Quest Tint:|r preview is forcing the tint %s for every quest. Type /fqt preview auto to go back to normal.")
            :format(ns.cfg.preview == "on" and "ON" or "OFF"))
    end
    HookLog()
    HookMarkers()
    HookDUI()
    HookImmersion()
    HookLorewalker()
    HookCUIF()
    HookQuestie()
    HookQuestieTracker()
    HookStoryline()
    MapPins.Hook()
end)
HookLog()
HookMarkers()
HookDUI()
HookImmersion()
HookLorewalker()
HookCUIF()
HookQuestie()
HookStoryline()
MapPins.Hook()

-- Called by the options panel after any setting changes.
function ns.Reapply()
    ns.rev = ns.rev + 1
    titleMap = nil -- which quests are marked may have changed (preview)
    Refresh()
    HookDUI()
    RefreshDUI()
    HookImmersion()
    RefreshImmersion()
    HookLorewalker()
    RefreshLorewalker()
    HookCUIF()
    HookQuestie()
    RefreshQuestie()
    MapPins.Hook()
    MapPins.Refresh()
    HookQuestieTracker()
    RefreshQuestieTracker()
    HookStoryline()
    RefreshStoryline()
    RefreshLog()
    RefreshLogList()
    RefreshTracker()
    QueueScan()
end

local PREVIEW_MODES = { "auto", "on", "off" }
local PREVIEW_TEXT = {
    auto = "auto (non-vanilla quests only)",
    on = "ON for every quest",
    off = "OFF for every quest",
}
ns.PREVIEW_MODES, ns.PREVIEW_TEXT = PREVIEW_MODES, PREVIEW_TEXT

-- Testing aid: force the tint, logo and marker on (or off) for every quest, or go back to auto.
-- With no mode it cycles auto -> on -> off.
function ns.SetPreview(mode)
    if mode and mode ~= "" and not PREVIEW_TEXT[mode] then
        print("|cff99e6f2Forever Quest Tint:|r usage: /fqt preview [on | off | auto]")
        return
    end
    if not PREVIEW_TEXT[mode] then
        local cur = ns.cfg.preview
        for i, m in ipairs(PREVIEW_MODES) do
            if m == cur then mode = PREVIEW_MODES[i % #PREVIEW_MODES + 1] end
        end
        mode = mode or "auto"
    end
    ns.cfg.preview = mode
    ns.Reapply()
    if ns.SyncOptions then ns.SyncOptions() end
    print("|cff99e6f2Forever Quest Tint:|r preview " .. PREVIEW_TEXT[mode])
end

local function Status()
    local function loaded(name)
        local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
        return isLoaded and isLoaded(name) and "loaded" or "not loaded"
    end
    local _, build, _, interface = GetBuildInfo()
    print(("|cff99e6f2Forever Quest Tint|r %s on interface %s (build %s), preview %s"):format(
        tostring(C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")
            or GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version")),
        tostring(interface), tostring(build), PREVIEW_TEXT[ns.cfg.preview] or tostring(ns.cfg.preview)))
    print(("  Dialogue UI: %s (hooked %s)  Immersion: %s (hooked %s)  Lorewalker: %s (hooked %s)"):format(
        loaded("DialogueUI"), tostring(duiWatcher ~= nil), loaded("Immersion"), tostring(immHooked),
        loaded("Lorewalker"), tostring(lwHooked)))
    print(("  ClassicUI Forever: %s (quest log %s, quest watch %s)  EllesmereUI Quest Tracker: %s"):format(
        loaded("ClassicUIForever"), cuifHooked.log and "hooked" or "not built yet",
        cuifHooked.watch and "hooked" or "not built yet", loaded("EllesmereUIQuestTracker")))
    print(("  Questie: %s (map icons %s, %d hooked)  Storyline: %s (hooked %s)"):format(loaded("Questie"),
        questieHooked and "hooked" or "not hooked", #questieFrames, loaded("Storyline"), tostring(slHooked)))
    print(("  Questie tracker: %s"):format(#questieLines > 0 and (#questieLines .. " lines hooked") or "not hooked"))
end

SLASH_FQT1 = "/fqt"
SlashCmdList.FQT = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, arg = msg:match("^(%S+)%s*(.*)$")
    if cmd == "preview" or cmd == "glow" then
        ns.SetPreview(arg)
        return
    end
    if msg == "status" then
        Status()
        return
    end
    if msg == "logo" then
        local h = logBg and logos[logBg]
        if not h then print("Forever Quest Tint: no log logo frame yet (tick 'Add logo', open a non-vanilla quest in the log)"); return end
        local pt, rel, relPt, x, y = h:GetPoint()
        print(("Forever Quest Tint logo: shown=%s visible=%s parent=%s level=%s strata=%s size=%dx%d alpha=%s point=%s to %s %s (%s,%s) left=%s bottom=%s tex=%s"):format(
            tostring(h:IsShown()), tostring(h:IsVisible()), tostring(h:GetParent():GetName() or h:GetParent():GetDebugName()),
            tostring(h:GetFrameLevel()), tostring(h:GetFrameStrata()), h:GetWidth(), h:GetHeight(), tostring(h:GetEffectiveAlpha()),
            tostring(pt), tostring(rel and (rel.GetDebugName and rel:GetDebugName())), tostring(relPt), tostring(x), tostring(y),
            tostring(h:GetLeft()), tostring(h:GetBottom()), tostring(h.texture:GetTexture())))
        return
    end
    if msg == "hooks" then
        print(("Forever Quest Tint hooks: quest log list=%s (QuestLogQuests_Update %s), tracker=%s (WatchFrame_SetLine %s), marker=%s")
            :format(tostring(listHooked), tostring(QuestLogQuests_Update ~= nil), tostring(trackerHooked),
                tostring(WatchFrame_SetLine ~= nil), tostring(ns.cfg.marker)))
        return
    end
    if msg == "id" then
        -- Handy for reporting a vanilla quest that is wrongly tinted.
        local id = GetQuestID()
        local details = QuestMapFrame and QuestMapFrame.DetailsFrame
        local logID = details and details.questID
        local bg = QuestMapFrame and QuestMapFrame.DetailsFrame and QuestMapFrame.DetailsFrame.Bg
        print("Forever Quest Tint: log parchment atlas = " .. tostring(bg and bg:GetAtlas()) .. ", file = " .. tostring(bg and bg:GetTexture()))
        print(("Forever Quest Tint: dialog quest id %s (vanilla=%s), log quest id %s (vanilla=%s)"):format(
            tostring(id), tostring(id and IsVanilla(id) or false), tostring(logID), tostring(logID and IsVanilla(logID) or false)))
        return
    end
    if ns.OpenOptions then ns.OpenOptions() end
end
