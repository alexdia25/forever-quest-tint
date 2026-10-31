-- Minimal WoW API stubs for testing the addon outside the game. Run from the repo root: lua5.1 tests/harness.lua .
local Object = {}
Object.__index = function(t, k)
    local v = rawget(Object, k)
    if v ~= nil then return v end
    if type(k) == "string" and k:match("^%u") then return function() return nil end end -- other API calls: no-op
end
local function new(kind, parent)
    local o = setmetatable({ kind = kind, parent = parent, scripts = {}, hooks = {}, shown = true,
        w = 100, h = 100, points = {}, children = {}, regions = {} }, Object)
    if parent then
        if kind == "Texture" or kind == "MaskTexture" or kind == "FontString" then
            table.insert(parent.regions, o)
        else
            table.insert(parent.children, o)
        end
    end
    return o
end
function Object:CreateTexture(_, layer, _, sublevel) local t = new("Texture", self); t.layer, t.sublevel = layer, sublevel; return t end
function Object:CreateMaskTexture() return new("MaskTexture", self) end
function Object:CreateFontString() local f = new("FontString", self); f.text = ""; return f end
function Object:SetText(t) self.text = t end
function Object:GetText() return self.text end
function Object:Show() self.shown = true end
function Object:Hide() self.shown = false end
function Object:SetShown(s) self.shown = s and true or false end
function Object:IsShown() return self.shown end
function Object:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Object:GetParent() return self.parent end
function Object:GetHeight() return self.h end
function Object:GetWidth() return self.w end
function Object:SetHeight(h) self.h = h end
function Object:SetSize(w, h) self.w, self.h = w, h end
function Object:GetFrameLevel() return 1 end
function Object:GetFrameStrata() return "MEDIUM" end
function Object:GetChildren() return unpack(self.children) end
function Object:GetRegions() return unpack(self.regions) end
function Object:SetAtlas(a) self.atlas = a end
function Object:GetAtlas() return self.atlas end
function Object:SetScript(name, fn) self.scripts[name] = fn end
function Object:HookScript(name, fn) self.hooks[name] = self.hooks[name] or {}; table.insert(self.hooks[name], fn) end
function Object:GetThumbTexture() return new("Texture", self) end
function Object:AddMaskTexture(m) self.mask = m end
function Object:SetTexture(f) self.file = f end
function Object:SetColorTexture() self.file = nil end
function Object:SetTexCoord(...) self.coords = { ... } end
function Object:GetTexture() return self.file end
function Object:SetVertexColor(r, g, b) self.vc = { r, g, b } end
function Object:GetVertexColor() local v = self.vc or { 1, 1, 1 }; return v[1], v[2], v[3], 1 end
function Object:SetDrawLayer(l, s) self.layer, self.sublevel = l, s end
function Object:GetDrawLayer() return self.layer or "ARTWORK", self.sublevel or 0 end
function Object:SetBlendMode(m) self.blend = m end
function Object:SetDesaturated(d) self.desat = d end
function Object:SetAlpha(a) self.alpha = a end
function Object:GetAlpha() return self.alpha or 1 end
function Object:GetStringHeight() return 12 end
function Object:GetName() return self.name end
function Object:GetObjectType() return self.kind end
-- Screen rectangle: explicit l/r/b/t when a test sets them, else 0..w by 0..h.
function Object:GetLeft() return self.l or 0 end
function Object:GetRight() return self.r or self.w end
function Object:GetTop() return self.t or self.h end
function Object:GetBottom() return self.b or 0 end
function Object:GetTexCoord()
    local c = self.coords
    if c and #c == 4 then return c[1], c[3], c[1], c[4], c[2], c[3], c[2], c[4] end
    return 0, 0, 0, 1, 1, 0, 1, 1
end
function Object:IsObjectType(t) return self.kind == t end
function Object:SetGradient(o, lo, hi) self.gradient = { lo, hi }; self.orient = o end
function Object:SetPoint(...) table.insert(self.points, { ... }) end
function Object:ClearAllPoints() self.points = {} end
function Object:RegisterEvent(e) self.events = self.events or {}; self.events[e] = true end
function Object:Fire(script, ...)
    if self.scripts[script] then self.scripts[script](self, ...) end
    for _, fn in ipairs(self.hooks[script] or {}) do fn(self, ...) end
end

UIParent = new("Frame")
local allFrames = {}
function CreateFrame(kind, _, parent) local f = new(kind, parent); allFrames[#allFrames + 1] = f; return f end
-- Deliver a game event to every frame that registered it.
local function FireGameEvent(event, ...)
    for _, f in ipairs(allFrames) do
        if f.events and f.events[event] then f:Fire("OnEvent", event, ...) end
    end
end
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
local timers = {}
C_Timer = { After = function(_, fn) table.insert(timers, fn) end }
local function RunTimers() local t = timers; timers = {}; for _, fn in ipairs(t) do fn() end end
function hooksecurefunc(a, b, c)
    local tbl, name, fn = a, b, c
    if type(a) == "string" then tbl, name, fn = _G, a, b end
    local orig = tbl[name]
    if type(orig) ~= "function" then return end
    rawset(tbl, name, function(...) local r = { orig(...) }; fn(...); return unpack(r) end)
end
local questID = 0
local selected = 0
local LOG = { { title = "Vanilla Quest", questID = 7 }, { title = "Forever Quest", questID = 999999 } }
C_QuestLog = {
    GetSelectedQuest = function() return selected end,
    SetSelectedQuest = function(id) selected = id end,
    GetNumQuestLogEntries = function() return #LOG end,
    GetInfo = function(i) return LOG[i] end,
}
function GetQuestID() return questID end
function GetCVar() return "0" end
function InCombatLockdown() return false end
function GetBuildInfo() return "12.1.5", "70575", "", 120105 end
local skinLoaded = false
C_AddOns = { IsAddOnLoaded = function(n) return n == "Immersion" or (skinLoaded and n == "EllesmereUIBlizzardSkin") end,
    GetAddOnMetadata = function() return "0.7.0" end }
SlashCmdList = {}
local printed = {}
function print(...) local t = {}; for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end; local s = table.concat(t, " "); table.insert(printed, s); io.write("  [print] ", s, "\n") end
Settings = { RegisterCanvasLayoutCategory = function() return { GetID = function() return 1 end } end,
    RegisterAddOnCategory = function() end }

-- Immersion's frame, as its Frame.xml builds it.
ImmersionFrame = new("Frame", UIParent)
ImmersionFrame.TalkBox = new("Button", ImmersionFrame)
-- Its objectives and rewards panel (TalkBox.Elements), a backdrop it sizes to its contents.
local panel = new("Frame", ImmersionFrame.TalkBox); panel.h = 180
ImmersionFrame.TalkBox.Elements = panel

-- Lorewalker's Classic mode window (Code/Dialog/DialogFrame/DialogFrame_UI.lua).
LWDialogFrame = new("Frame", UIParent)
LWDialogFrame.QuestFrame = new("Frame", LWDialogFrame)
LWDialogFrame.TitleContainer = new("Frame", LWDialogFrame)
LWDialogFrame.ContentFrame = new("Frame", LWDialogFrame)
local lwPage = new("Frame", LWDialogFrame.ContentFrame); lwPage.h = 400
lwPage.__Texture = lwPage:CreateTexture(); lwPage.__Texture.h = 400
lwPage.__Texture:SetTexture("Interface\\AddOns\\Lorewalker\\Art\\Dialog\\DialogFrame\\QuestBackgroundClassic")
LWDialogFrame.ContentFrame.BackgroundTexture = lwPage
-- Its edge fade over the buttons: a page-coloured fade above the text (EdgeFade.EdgeFadeGradientTexture).
LWDialogFrame.EdgeFade = new("Frame", LWDialogFrame.ContentFrame)
local lwEdge = new("Frame", LWDialogFrame.EdgeFade); lwEdge.h = 50
lwEdge.__Texture = lwEdge:CreateTexture(); lwEdge.__Texture:SetVertexColor(214 / 255, 168 / 255, 114 / 255)
LWDialogFrame.EdgeFade.EdgeFadeGradientTexture = lwEdge

-- ClassicUI Forever: its API, quest log window and quest watch (built later, as it does on first use).
local cuif = {}
ClassicUIForeverAPI = { GetFrame = function(name) return cuif[name] end }

-- Questie's icon frames, as Modules/FramePool/QuestieFrame.lua builds and colours them.
Questie = { ICON_TYPE_AVAILABLE = 6, ICON_TYPE_AVAILABLE_GRAY = 7, ICON_TYPE_COMPLETE = 8, ICON_TYPE_REPEATABLE = 10,
    usedIcons = { [6] = "Interface\\Addons\\Questie\\Icons\\available.blp", [7] = "Interface\\Addons\\Questie\\Icons\\available_gray.blp",
        [8] = "Interface\\Addons\\Questie\\Icons\\complete.blp", [10] = "Interface\\Addons\\Questie\\Icons\\repeatable.blp" } }
local function QSetVertexColor(self, r, g, b, a)
    self:OLDSetVertexColor(r, g, b, a)
    self.r, self.g, self.b, self.a = r or 1, g or 1, b or 1, a or 1
end
local QuestieFrameModule = {}
function QuestieFrameModule.CreateIconFrame(frameId)
    local f = new("Button", UIParent); f.name = "QuestieFrame" .. frameId; _G[f.name] = f
    local t = f:CreateTexture()
    -- As in game: the texture takes its size from the frame's position, unknown until the pin is placed; the frame
    -- itself has the size Questie gives it.
    t.h = 0; f.h = 16
    t.OLDSetVertexColor = function(self, r, g, b, a) self.vc = { r, g, b, a } end
    t.SetVertexColor = QSetVertexColor
    t:SetVertexColor(1, 1, 1, 1)
    f.texture = t
    f.UpdateTexture = function(self, path) self.texture:SetTexture(path); self.texture:SetVertexColor(1, 1, 1, self.mini and 0 or 1) end
    return f
end
QuestieLoader = { _modules = { QuestieFrame = QuestieFrameModule } }
local earlyIcon = QuestieFrameModule.CreateIconFrame(1) -- made before this addon hooks in
earlyIcon.data = { Id = 999999 }; earlyIcon:UpdateTexture(Questie.usedIcons[6])

-- Storyline's window (ui.xml) and its API's startDialog (logic.lua).
Storyline_NPCFrame = new("Frame", UIParent)
Storyline_NPCFrameChat = new("Frame", Storyline_NPCFrame); Storyline_NPCFrameChat.h = 150
Storyline_API = { startDialog = function(_, _, event) Storyline_NPCFrameChat.event = event end }

local ns = {}
local function load(file)
    local chunk = assert(loadfile(arg[1] .. "/" .. file))
    chunk("ForeverQuestTint", ns)
end
load("VanillaQuests.lua"); load("ForeverQuestTint.lua"); load("Options.lua")

ColorPickerFrame = new("Frame")
ForeverQuestTintDB = nil

local function check(cond, msg) if not cond then error("FAIL: " .. msg, 2) end; print("ok - " .. msg) end
-- The shown pieces of a glow on `frame`.
local function glowParts(frame)
    local p = { all = {} }
    for _, r in ipairs(frame.regions) do
        if r.gradient and r.shown then p.all[#p.all + 1] = r end
    end
    p.inner = p.all[1] and p.all[1].points[1][2]
    return p
end
local function glowShown(frame) return #glowParts(frame).all > 0 end
-- The rounded glow: two mirrored corners from the art, a bottom edge and two sides from its straight parts, a plain
-- centre; the fade unbroken from piece to piece and reaching the fade's end; all on BORDER, in the vivid tint.
local function checkRoundedGlow(frame, size, label, layer, scale, strength, artName)
    layer, scale, strength, artName = layer or "BORDER", scale or 0.75, strength or 0.6, artName or "GlowCorner"
    local p = glowParts(frame)
    local fade = p.inner.h * ns.cfg.height
    local function find(test) for _, r in ipairs(p.all) do if test(r) then return r end end end
    local art = function(r) return r.file and r.file:find(artName) end
    local bl = find(function(r) return art(r) and r.coords[1] == 0 and r.coords[3] == 0.5 and r.points[1][5] == 0 and r.h == size end)
    local br = find(function(r) return art(r) and r.coords[1] == 0.5 and r.coords[2] == 0 and r.points[1][5] == 0 end)
    local bottom = find(function(r) return art(r) and r.coords[1] == 0.74 end)
    local left = find(function(r) return art(r) and r.coords[3] == 0.23 and r.coords[1] == 0 end)
    local right = find(function(r) return art(r) and r.coords[3] == 0.23 and r.coords[1] == 0.5 end)
    local centre = find(function(r) return not r.file end)
    check(#p.all == 6 and bl and br and bottom and left and right and centre,
        label .. ": six pieces, corners and edges from the " .. artName .. " art")
    check(bl.points[1][4] == 0 and br.points[1][4] == p.inner.w - size and bottom.points[1][4] == size
        and left.points[1][5] == size and math.abs(left.points[1][5] + left.h - fade) < 0.001
        and centre.points[1][4] == size and centre.points[1][5] == size,
        label .. ": pieces laid edge to edge up to the fade's end")
    local function near(x, y) return math.abs(x - y) < 0.0001 end
    check(near(bl.gradient[2].a, left.gradient[1].a) and near(bottom.gradient[2].a, centre.gradient[1].a)
        and near(bl.gradient[1].a, ns.cfg.alpha * strength),
        label .. ": the fade runs on unbroken across the pieces")
    local border = true
    for _, r in ipairs(p.all) do border = border and r.layer == layer end
    check(border, label .. ": drawn on " .. layer .. ", above the page or panel art")
    local v = bl.gradient[1]
    check(math.abs(v.g - 0.98 * scale) < 0.01 and v.r < ns.cfg.tint[1] * scale - 0.1,
        label .. ": vivid tint, more saturated than the plain one")
    return p, left
end
local glow = function() return glowParts(panel).all[1] end

-- Event frames created at load have no parent: reach them through the slash/handlers instead.
-- 1) Immersion showing an old (vanilla) quest in auto mode: no glow.
ns.cfg.preview = "auto"
questID = 7   -- a vanilla quest id
ImmersionFrame.lastEvent = "QUEST_DETAIL"
ImmersionFrame:Fire("OnEvent", "QUEST_DETAIL"); RunTimers()
check(not glow() or not glow().shown, "auto: vanilla quest gets no Immersion glow")

-- 2) Non-vanilla quest: glow appears in the objectives panel, inside its edges, covering the fade height.
questID = 999999
ImmersionFrame:Fire("OnEvent", "QUEST_DETAIL"); RunTimers()
check(glowShown(panel), "auto: non-vanilla quest shows the Immersion glow")
local immParts = glowParts(panel)
local immInnerFrame = immParts.inner
check(immInnerFrame.parent == panel and immInnerFrame.points[1][2] == 4 and immInnerFrame.points[2][2] == -4,
    "glow fills the objectives panel's dark body")
checkRoundedGlow(panel, 12, "Immersion")
local talkHeadOverlay = false
for _, r in ipairs(ImmersionFrame.TalkBox.regions) do if r.gradient then talkHeadOverlay = true end end
check(not talkHeadOverlay, "the talking head itself is left untinted")

-- 3) Gossip in the same box (Immersion hides the panel): glow hidden.
ImmersionFrame.lastEvent = "GOSSIP_SHOW"
panel:Hide(); panel:Fire("OnHide")
ImmersionFrame:Fire("OnEvent", "GOSSIP_SHOW"); RunTimers()
check(not glowShown(panel), "gossip hides the glow")

-- 4) Preview on via slash: vanilla quest now glows; preview off: non-vanilla hides.
ImmersionFrame.lastEvent = "QUEST_PROGRESS"; questID = 7
panel:Show()
SlashCmdList.FQT("preview on")
check(ns.cfg.preview == "on" and glowShown(panel), "/fqt preview on forces the glow on a vanilla quest")
questID = 999999
SlashCmdList.FQT("preview off")
check(ns.cfg.preview == "off" and not glowShown(panel), "/fqt preview off hides it on a non-vanilla quest")
SlashCmdList.FQT("preview")
check(ns.cfg.preview == "auto" and glowShown(panel), "/fqt preview cycles off -> auto")
SlashCmdList.FQT("Glow ON")
check(ns.cfg.preview == "on", "/fqt glow on alias, case-insensitive")
SlashCmdList.FQT("preview bogus")
check(ns.cfg.preview == "on" and printed[#printed]:find("usage"), "unknown mode prints usage and changes nothing")

-- 5) The panel grows to fit its contents; the logo sits in its corner.
ns.cfg.preview = "auto"; ns.cfg.showLogo = true
immInnerFrame.h = 260; panel:Fire("OnSizeChanged")
local _, side = checkRoundedGlow(panel, 12, "Immersion (grown)")
check(math.abs(side.points[1][5] + side.h - 260 * ns.cfg.height) < 0.01, "glow follows the panel's new size")
local logo
for _, c in ipairs(panel.children) do if c.texture then logo = c end end
check(logo and logo.shown and logo.points[1][1] == "TOPRIGHT", "logo in the objectives panel's top-right corner")
ImmersionFrame:Hide(); ImmersionFrame:Fire("OnHide")
local anyShown = false
for _, r in ipairs(panel.regions) do if r.gradient and r.shown then anyShown = true end end
check(not anyShown and not logo.shown, "closing Immersion hides the glow, its corners and the logo")

-- 6) Tint off: no glow even for a marked quest.
ImmersionFrame:Show(); ns.cfg.showTint = false; ns.Reapply()
check(not glowShown(panel) and logo.shown, "tint off keeps the logo, hides the glow")


-- 7) Lorewalker: tint and logo only for a marked quest, only while its quest part shows.
ns.cfg.showTint = true; ns.cfg.showLogo = true; ns.cfg.preview = "auto"
questID = 999999
LWDialogFrame.QuestFrame:Fire("OnShow"); RunTimers()
check(glowShown(lwPage), "Lorewalker: marked quest gets the wash")
local lwInnerFrame = glowParts(lwPage).inner
check(lwInnerFrame.parent == lwPage and lwInnerFrame.points[1][2] == 10 and lwInnerFrame.points[2][2] == -10,
    "Lorewalker: wash inset from the page's torn edges, no mask")
checkRoundedGlow(lwPage, 22, "Lorewalker (light)", "ARTWORK", 1, 0.55, "GlowChamfer")
-- The edge fade takes the glowing page's colour at its height: page colour blended with the glow.
local paper = { 214 / 255, 168 / 255, 114 / 255 }
local function edgeMatches()
    local p = glowParts(lwPage)
    local bl
    for _, r in ipairs(p.all) do if r.coords and r.coords[1] == 0 and r.coords[3] == 0.5 then bl = r end end
    local wash = bl.gradient[1]
    local fade = lwInnerFrame.h * ns.cfg.height
    local a = (ns.cfg.topAlpha + (ns.cfg.alpha - ns.cfg.topAlpha) * (1 - 25 / fade)) * (wash.a / ns.cfg.alpha)
    local v = lwEdge.__Texture.vc
    return math.abs(v[1] - (paper[1] + (wash.r - paper[1]) * a)) < 0.002 and math.abs(v[3] - (paper[3] + (wash.b - paper[3]) * a)) < 0.002
end
check(edgeMatches(), "Lorewalker: edge fade recoloured to the glowing page's colour at its height")
local lwLogo
for _, c in ipairs(LWDialogFrame.TitleContainer.children) do if c.texture then lwLogo = c end end
check(lwLogo and lwLogo.shown, "Lorewalker: logo on the title bar")
lwPage.__Texture:SetTexture("Interface\\AddOns\\Lorewalker\\Art\\Dialog\\DialogFrame\\QuestBackgroundDark"); RunTimers()
checkRoundedGlow(lwPage, 22, "Lorewalker (dark)", "ARTWORK", 0.75, 0.6, "GlowChamfer")
questID = 7
LWDialogFrame.QuestFrame:Fire("OnShow"); RunTimers()
check(not glowShown(lwPage) and not lwLogo.shown, "Lorewalker: vanilla quest is left plain")
local ev = lwEdge.__Texture.vc
check(math.abs(ev[1] - paper[1]) < 0.002 and math.abs(ev[3] - paper[3]) < 0.002, "Lorewalker: edge fade gets its own colour back")
questID = 999999; LWDialogFrame.QuestFrame:Fire("OnShow"); RunTimers()
LWDialogFrame.QuestFrame:Hide(); LWDialogFrame.QuestFrame:Fire("OnHide")
check(not glowShown(lwPage) and not lwLogo.shown, "Lorewalker: gossip (quest part hidden) is left plain")

-- 8) ClassicUI Forever builds its windows later; the next quest log event finds them.
local log = new("Frame", UIParent); log.detail = new("ScrollFrame", log); log.detail.h = 260
log.listArea = new("Frame", log)
local row = new("Button", log.listArea); row.text = row:CreateFontString()
local watch = new("Frame", UIParent)
local watchTitle = watch:CreateFontString(); local watchGoal = watch:CreateFontString()
cuif.questLog, cuif.questWatch = log, watch
-- Its watch writes a title and an objective line; the tracker events then trigger a scan.
watchTitle:SetText("Forever Quest"); watchGoal:SetText("- 0/5 Darkhound Blood")
row.text:SetText("  [12] Forever Quest")
SlashCmdList.FQT("preview auto"); RunTimers()   -- Reapply hooks it and queues a scan
check(watchTitle.text:find("|T") and watchTitle.text:find("^Forever Quest"), "CUIF watch: marked quest's title gets the marker")
check(watchGoal.text == "- 0/5 Darkhound Blood", "CUIF watch: objective line untouched")
check(watch.h == 100, "CUIF watch: flat list is not resized like a tracker block")
check(row.text.text:find("|T") ~= nil, "CUIF quest log: list row gets the marker")
-- It rewrites the line on its next update: the marker comes straight back.
watchTitle:SetText("Forever Quest")
check(watchTitle.text:find("|T") ~= nil, "CUIF watch: marker survives a rewrite")
watchTitle:SetText("Vanilla Quest")
check(watchTitle.text == "Vanilla Quest", "CUIF watch: a reused line with a vanilla title stays plain")

-- 9) ClassicUI Forever quest log page, double pane: its window art as in Quest/QuestLogWindow.lua (a 512 and a 256
-- wide sheet from the window's top-left, 680x440 window), the detail pane at 352, -80, 292x328.
local function artSheet(file, l, r)
    local t = log:CreateTexture(); t:SetTexture(file); t.layer = "BACKGROUND"; t.sublevel = 0
    t.l, t.r, t.t, t.b = l, r, 440, 440 - 512
    return t
end
local sheetL = artSheet("Interface\\AddOns\\ClassicUIForever\\media\\UI-QuestLogDualPane-Left", 0, 512)
local sheetR = artSheet("Interface\\AddOns\\ClassicUIForever\\media\\UI-QuestLogDualPane-Right", 512, 768)
log.detail.l, log.detail.r, log.detail.t, log.detail.b = 352, 644, 360, 32
log.dual = true
-- The soft glow's own pieces (the corner art, or its plain centre), as opposed to the copies.
local function glowArt()
    for _, r in ipairs(log.regions) do
        if r.shown and r.gradient and (not r.file or r.file:find("GlowCorner")) then return true end
    end
    return false
end
local function copies()
    local list = {}
    for _, r in ipairs(log.regions) do
        if r.shown and r.desat and r.file and r.file:find("DualPane") and r ~= sheetL and r ~= sheetR then list[#list + 1] = r end
    end
    table.sort(list, function(x, y) return x.points[1][2].l + x.points[1][4] < y.points[1][2].l + y.points[1][4] end)
    return list
end
C_QuestLog.SetSelectedQuest(999999); RunTimers()
local cp = copies()
-- The page reaches past the detail pane to its burnt edges: 2 left, 5 right, 3 below in the double pane.
local pageL, pageR, pageB = 350, 649, 29
local fadeTop = pageB + (360 - pageB) * ns.cfg.height
check(#cp == 2 and cp[1].file == sheetL.file and cp[2].file == sheetR.file and not glowArt(),
    "CUIF quest log: tinted copies of both art sheets under the page, no glow")
check(cp[1].points[1][2] == sheetL and cp[1].points[1][4] == pageL and cp[1].points[1][5] == pageB + 72 and cp[1].w == 512 - pageL
    and cp[2].points[1][2] == sheetR and cp[2].points[1][4] == 0 and cp[2].w == pageR - 512
    and math.abs(cp[1].h - (fadeTop - pageB)) < 0.001,
    "CUIF quest log: copies cover the page to its burnt edges, to the fade's end")
local function near(x, y) return math.abs(x - y) < 0.0001 end
check(near(cp[1].coords[1], pageL / 512) and near(cp[1].coords[2], 1) and near(cp[2].coords[1], 0)
    and near(cp[2].coords[2], (pageR - 512) / 256)
    and near(cp[1].coords[4], (440 - pageB) / 512) and near(cp[1].coords[3], (440 - fadeTop) / 512),
    "CUIF quest log: each copy shows the matching slice of its sheet")
local g0 = cp[1].gradient[1]
check(near(g0.a, ns.cfg.alpha) and near(cp[1].gradient[2].a, ns.cfg.topAlpha)
    and near(g0.r, ns.cfg.tint[1]) and near(g0.g, ns.cfg.tint[2]) and near(g0.b, ns.cfg.tint[3]),
    "CUIF quest log: plain tint like the game's quest window, full strength at the bottom fading to the top")
C_QuestLog.SetSelectedQuest(7); RunTimers()
check(#copies() == 0 and not glowArt(), "CUIF quest log: vanilla quest left plain")
-- A dark theme inks the art: the copy would stay dark, so the soft glow takes over.
sheetL:SetVertexColor(0.15, 0.13, 0.1); sheetR:SetVertexColor(0.15, 0.13, 0.1)
C_QuestLog.SetSelectedQuest(999999); RunTimers()
check(#copies() == 0 and glowArt(), "CUIF quest log: dark theme gets the glow instead of a copy")
local cuifInner = glowParts(log).inner
check(cuifInner.points[1][2] == log.detail and cuifInner.points[1][4] == 8 and cuifInner.points[2][4] == -8,
    "CUIF quest log: dark-page glow inset inside the page's burnt edges")
checkRoundedGlow(log, 16, "CUIF quest log (dark)", "BACKGROUND", 0.75, 0.6)
sheetL:SetVertexColor(1, 1, 1); sheetR:SetVertexColor(1, 1, 1)
C_QuestLog.SetSelectedQuest(999999); RunTimers()
check(#copies() == 2 and not glowArt(), "CUIF quest log: light again, back to the copy")
-- The single pane's page reaches 4 left, 0 right and 1 below past its detail pane.
log.dual = false; log.detail:Fire("OnSizeChanged")
local single = copies()
check(single[1].points[1][4] == 352 - 4 and single[2].w == 644 - 512 and single[1].points[1][5] == 32 - 1 + 72,
    "CUIF quest log: single pane uses its own page edges")
log.dual = true
selected = 0; log:Fire("OnShow")
check(#copies() == 0 and not glowArt(), "CUIF quest log: no selection, no tint")

-- 10) Map details: ClassicUI Forever's own parchment takes over from the game's Bg, and back.
QuestMapFrame = new("Frame", UIParent)
local details = new("Frame", QuestMapFrame); QuestMapFrame.DetailsFrame = details
details.BackButton, QuestMapFrame.BackButton, details.RewardsFrameContainer = false, false, false
details.Bg = details:CreateTexture(); details.Bg:SetAtlas("QuestDetailsBackgrounds")
C_Texture = { GetAtlasInfo = function() return nil end }
details.questID = 999999
local function detailOverlays()
    local list = {}
    for _, r in ipairs(details.regions) do if r ~= details.Bg and r ~= details.fcui_p and r.kind == "Texture" then list[#list + 1] = r end end
    return list
end
ns.Reapply()
check(#detailOverlays() == 1 and detailOverlays()[1].shown, "map: game parchment tinted without ClassicUI Forever")
local own = details:CreateTexture(); own:SetTexture(12345); details.fcui = { parchment = own }; details.fcui_p = own
own:SetVertexColor(0.15, 0.12, 0.1) -- a dark theme
ns.Reapply()
local ovs = detailOverlays()
check(#ovs == 2 and not ovs[1].shown and ovs[2].shown, "map: overlay moves to ClassicUI Forever's parchment")
check(ovs[2].file == nil, "map: its dark-themed parchment gets the flat glow, not a copy")
own:Hide(); ns.Reapply()
ovs = detailOverlays()
check(ovs[1].shown and not ovs[2].shown, "map: back on the game's parchment when its pane is off")


-- 11) Questie: a teal gradient over the yellow ! and ? of marked quests; Questie's own icon is never changed.
ns.cfg.questieTint = true; ns.cfg.preview = "auto"; ns.Reapply()
local function vc(f) return f.texture.vc end
-- Questie's icon as Questie left it: not desaturated, its own colour.
local function original(f) return not f.texture.desat and vc(f)[1] == f.texture.r and vc(f)[4] == f.texture.a end
local function tinted(f) return f.fqtSolid and f.fqtSolid.shown end
local function isTint(f, alpha)
    -- Two slices of a desaturated copy in the vivid tint (VividTint, factor 2, lifted by 1.15): solid over the bottom
    -- 45% at Questie's alpha, then fading to nothing by 75%; Questie's own icon untouched underneath.
    local t = ns.cfg.tint
    local avg = (t[1] + t[2] + t[3]) / 3
    local function vivid(x) return math.min(1, math.max(0, math.min(1, avg + (x - avg) * 2)) * 1.15) end
    local sp, fp, h = f.fqtSolid, f.fqtFade, f.h
    local function ok(p) return p and p.shown and p.desat and p.file == f.fqtIcon and p.layer == "OVERLAY" and p.sublevel == 1 end
    if not (ok(sp) and ok(fp)) then return false end
    local lo = sp.gradient[1]
    local function near(x, y) return math.abs(x - y) < 0.001 end
    return near(lo.r, vivid(t[1])) and near(lo.g, vivid(t[2])) and near(lo.b, vivid(t[3]))
        and near(sp.gradient[1].a, alpha) and near(sp.gradient[2].a, alpha)
        and near(fp.gradient[1].a, alpha) and near(fp.gradient[2].a, 0)
        and near(sp.points[1][5], 0) and near(sp.h, h * 0.45) and near(fp.points[1][5], h * 0.45) and near(fp.h, h * 0.30)
        and near(sp.coords[3], 0.55) and near(sp.coords[4], 1) and near(fp.coords[3], 0.25) and near(fp.coords[4], 0.55)
        and original(f)
end
check(isTint(earlyIcon, 1), "Questie: an icon made before hooking gets the gradient")
local function icon(id, iconType, mini)
    local f = QuestieFrameModule.CreateIconFrame(#questieMade + 2)
    f.mini = mini
    f.data = { Id = id }
    f:UpdateTexture(Questie.usedIcons[iconType])
    return f
end
questieMade = {}
local avail = icon(999999, 6)
local done = icon(999999, 8)
local vanilla = icon(7, 6)
local gray = icon(999999, 7)
local repeatable = icon(999999, 10)
check(isTint(avail, 1), "Questie: gradient over a marked quest's yellow !, the original untouched")
check(isTint(done, 1), "Questie: gradient over a marked quest's yellow ?")
check(not tinted(vanilla) and original(vanilla), "Questie: vanilla quest's ! untouched")
check(not tinted(gray) and not tinted(repeatable), "Questie: grey and blue icons keep their meaning")
-- Minimap fade: Questie re-sets its remembered colour with a new alpha; the gradient follows it.
local mini = icon(999999, 6, true)
check(isTint(mini, 0), "Questie: minimap icon's gradient at Questie's starting alpha")
mini.texture:SetVertexColor(mini.texture.r, mini.texture.g, mini.texture.b, 0.4)
check(isTint(mini, 0.4), "Questie: fading takes the gradient with it")
-- Hover highlight: Questie's colour shows, then the gradient comes back.
avail.texture:SetVertexColor(0.6, 1, 1, 1)
check(not tinted(avail) and vc(avail)[1] == 0.6, "Questie: hover highlight shows Questie's colour")
avail.texture:SetVertexColor(1, 1, 1, 1)
check(isTint(avail, 1), "Questie: gradient returns after the highlight")
-- Pool reuse: a frame handed to a vanilla quest.
avail.data = { Id = 7 }; avail:UpdateTexture(Questie.usedIcons[6])
check(not tinted(avail) and original(avail), "Questie: reused frame for a vanilla quest is plain again")
-- Option and preview.
ns.cfg.questieTint = false; ns.Reapply()
check(not tinted(done) and original(done), "Questie: option off leaves Questie's icons as they are")
ns.cfg.questieTint = true; SlashCmdList.FQT("preview on")
check(isTint(vanilla, 1), "Questie: preview on puts the gradient on a vanilla quest's !")
SlashCmdList.FQT("preview auto")
check(not tinted(vanilla), "Questie: preview auto takes it off again")

-- 12) Tracker logo: a badge at the top-right of a marked quest's block, hidden when the block is reused.
ObjectiveTrackerFrame = new("Frame", UIParent)
local block = new("Frame", ObjectiveTrackerFrame)
local header = block:CreateFontString()
header:SetText("Forever Quest")
local function badge() return block.fqtLogo end
ns.cfg.trackerLogo = false; ns.Reapply(); RunTimers()
check(header.text:find("|T") and not (badge() and badge().shown), "tracker: marker on, logo off by default")
ns.cfg.trackerLogo = true; ns.Reapply(); RunTimers()
check(badge() and badge().shown and badge().file:find("ForeverLogo"), "tracker: logo beside a marked quest")
check(badge().points[1][1] == "TOPRIGHT" and badge().points[1][2] == block, "tracker: logo at the block's top-right")
header:SetText("Vanilla Quest") -- the block is reused for another quest
check(not badge().shown, "tracker: reused block for a vanilla quest hides the logo")
header:SetText("Forever Quest")
check(badge().shown, "tracker: logo back when the block shows a marked quest again")
ns.cfg.marker = false; ns.Reapply(); RunTimers()
check(badge().shown and not header.text:find("|T"), "tracker: logo works with the marker turned off")
ns.cfg.marker = true; ns.cfg.trackerLogo = false; ns.Reapply(); RunTimers()
check(not badge().shown, "tracker: option off hides the logo")


-- 13) Storyline: wash inside the speech bubble and the logo in its corner, for marked quests only.
ns.cfg.showTint = true; ns.cfg.showLogo = true; ns.cfg.preview = "auto"
local chat = Storyline_NPCFrameChat
local function slLogo() for _, c in ipairs(chat.children) do if c.texture then return c end end end
questID = 999999
Storyline_API.startDialog("npc", "text", "QUEST_DETAIL", {}); RunTimers()
check(glowShown(chat), "Storyline: marked quest gets the wash")
local inner = glowParts(chat).inner
check(inner ~= chat and inner.parent == chat and inner.points[1][1] == "TOPLEFT" and inner.points[1][2] == 2 and inner.points[2][2] == -2,
    "Storyline: wash fills the bubble's dark body")
checkRoundedGlow(chat, 6, "Storyline")
check(slLogo() and slLogo().shown, "Storyline: logo in the bubble's corner")
Storyline_API.startDialog("npc", "text", "GOSSIP_SHOW", {}); RunTimers()
check(not glowShown(chat) and not slLogo().shown, "Storyline: gossip left plain")
questID = 7
Storyline_API.startDialog("npc", "text", "QUEST_PROGRESS", {}); RunTimers()
check(not glowShown(chat), "Storyline: vanilla quest left plain")
questID = 999999
Storyline_API.startDialog("npc", "text", "QUEST_COMPLETE", {}); RunTimers()
inner.h = 200; chat:Fire("OnSizeChanged")
local _, slSide = checkRoundedGlow(chat, 6, "Storyline (grown)")
check(math.abs(slSide.points[1][5] + slSide.h - 200 * ns.cfg.height) < 0.01, "Storyline: wash follows the bubble's new height")
Storyline_NPCFrame:Hide(); Storyline_NPCFrame:Fire("OnHide")
local slAny = false
for _, r in ipairs(chat.regions) do if r.gradient and r.shown then slAny = true end end
check(not slAny and not slLogo().shown, "Storyline: closing the window hides the wash, its corners and the logo")
Storyline_NPCFrame:Show()


-- 14) A skinned quest window (EllesmereUI): flat glow across the window's text area instead of a parchment copy.
C_Texture = C_Texture or { GetAtlasInfo = function() return nil end }
QuestFrame = new("Frame", UIParent); QuestFrame.l, QuestFrame.r, QuestFrame.b, QuestFrame.t = 20, 430, 0, 640
local qPanel = new("Frame", QuestFrame); qPanel.name = "QuestFrameDetailPanel"; _G.QuestFrameDetailPanel = qPanel
qPanel.RewardsFrameContainer = false
local qBg = qPanel:CreateTexture(); _G.QuestFrameDetailPanelBg = qBg
qBg:SetAtlas("QuestBG-Parchment"); qBg:SetTexture("parchment"); qBg.l, qBg.r, qBg.b, qBg.t, qBg.w, qBg.h = 30, 385, 60, 600, 355, 540
local qScroll = new("ScrollFrame", qPanel); _G.QuestDetailScrollFrame = qScroll
qScroll.l, qScroll.r, qScroll.b, qScroll.t, qScroll.h = 36, 400, 70, 600, 530
ns.cfg.showTint, ns.cfg.preview = true, "auto"
local function questCopy()
    for _, r in ipairs(qPanel.regions) do if r ~= qBg and r.desat and r.shown then return r end end
end
local function questFlat()
    for _, r in ipairs(qPanel.regions) do if r.shown and r.gradient and not r.file and r.layer == "BORDER" then return r end end
end
questID = 999999
FireGameEvent("QUEST_DETAIL"); RunTimers()
check(questCopy() and not questFlat(), "skin: plain quest window gets the parchment copy")
skinLoaded = true; ns.Reapply(); RunTimers()
local qf = questFlat()
check(qf and not questCopy(), "skin: EllesmereUI's skin loaded, flat glow instead of the parchment copy")
local reg = qf.points[1][2]
check(reg.points[1][2] == qScroll and reg.points[1][4] == 20 + 4 - 36 and reg.points[2][4] == 430 - 4 - 400,
    "skin: glow spans the window from side to side over the text area")
local v = qf.gradient[1]
check(math.abs(v.g - 0.98 * 0.75) < 0.01 and math.abs(v.a - ns.cfg.alpha * 0.6) < 0.001, "skin: vivid tint at dark-panel strength")
skinLoaded = false; qBg:SetAlpha(0); ns.Reapply(); RunTimers()
check(questFlat() and not questCopy(), "skin: a see-through parchment counts as skinned too")
qBg:SetAlpha(1); ns.Reapply(); RunTimers()
check(questCopy() and not questFlat(), "skin: back to the copy once the parchment shows")
questID = 7; FireGameEvent("QUEST_DETAIL"); RunTimers(); skinLoaded = true; ns.Reapply(); RunTimers()
check(not questFlat() and not questCopy(), "skin: vanilla quest left plain")
-- The skinned quest log: the glow ends at the Rewards panel's top, so nothing runs underneath it.
local det = QuestMapFrame.DetailsFrame
det.fcui = nil
det.Bg:Show(); det.Bg.l, det.Bg.r, det.Bg.b, det.Bg.t, det.Bg.h = 0, 380, 0, 600, 600
local rw = new("Frame", det); rw.t = 160; rw.r = 379; det.RewardsFrameContainer = rw
det.questID = 999999; skinLoaded = true
ns.Reapply()
local logFlat
for _, r in ipairs(det.regions) do if r.shown and r.gradient and not r.file and r.layer == "BORDER" then logFlat = r end end
local lreg = logFlat and logFlat.points[1][2]
check(logFlat and lreg.points[1][2] == det.Bg and lreg.points[2][1] == "BOTTOMRIGHT" and lreg.points[2][5] == 160,
    "skin: quest log glow stops at the Rewards panel's top")
check(lreg.points[2][4] == -1, "skin: quest log glow's right edge lines up with the Rewards panel's")
rw:Hide(); ns.Reapply()
check(lreg.points[2][4] == -1 and lreg.points[2][5] == 0, "skin: still lined up with the panel when it's hidden, full height")
skinLoaded = false


-- 15) Questie's tracker. First load: Questie builds its lines and writes their titles once it is ready, before this
-- addon has hooked them; when Questie reports ready, the titles already showing are marked too.
local readyCallbacks = {}
Questie.API = { RegisterOnReady = function(fn) readyCallbacks[#readyCallbacks + 1] = fn end }
ns.Reapply() -- no tracker yet: registers for Questie's ready callback
for i = 1, 3 do
    local line = new("Button", UIParent); _G["linePool" .. i] = line
    line.label = line:CreateFontString(); line.expandQuest = new("Button", line)
    line.SetQuest = function(self, q) self.Quest = q end
    line.SetMode = function(self, m) self.mode = m end
end
_G.linePool1:SetMode("quest"); _G.linePool1:SetQuest({ Id = 999999 }); _G.linePool1.label:SetText("[11] Coming of Age")
check(_G.linePool1.label.text == "[11] Coming of Age", "Questie tracker: title written before the hook is plain at first")
for _, fn in ipairs(readyCallbacks) do fn() end
RunTimers()
check(_G.linePool1.label.text:find("|T") ~= nil, "Questie tracker: once Questie is ready, titles already showing are marked")

-- Then, as Questie rewrites lines: the marker on quest titles; objectives and zones untouched.
local function questieWrite(i, mode, quest, text)
    local line = _G["linePool" .. i]
    line:SetMode(mode); line.Quest = nil
    if quest then line:SetQuest(quest) end
    line.label:SetText(text)
    return line.label.text
end
check(questieWrite(1, "quest", { Id = 999999 }, "[11] Coming of Age"):find("|T") ~= nil, "Questie tracker: marker on a non-vanilla quest's title")
check(questieWrite(2, "quest", { Id = 7 }, "[5] Old Quest") == "[5] Old Quest", "Questie tracker: vanilla quest's title left plain")
check(questieWrite(3, "objective", { Id = 999999 }, "Quest Complete!") == "Quest Complete!", "Questie tracker: objective lines left alone")
check(questieWrite(1, "zone", nil, "Azuremyst Isle") == "Azuremyst Isle", "Questie tracker: a reused line as a zone header is plain")
questieWrite(1, "quest", { Id = 999999 }, "[11] Coming of Age")
SlashCmdList.FQT("preview off")
check(_G.linePool1.label.text == "[11] Coming of Age", "Questie tracker: preview off removes the marker")
SlashCmdList.FQT("preview auto")
check(_G.linePool1.label.text:find("|T") ~= nil, "Questie tracker: and preview auto puts it back")

-- 16) The game's own map pins, for players without Questie (Forever's map, like retail's).
C_Texture = { GetAtlasInfo = function(atlas)
    return { file = "atlas:" .. atlas, leftTexCoord = 0.1, rightTexCoord = 0.2, topTexCoord = 0.3, bottomTexCoord = 0.4 }
end }
local pins = { QuestOfferPinTemplate = {}, QuestPinTemplate = {} }
WorldMapFrame = new("Frame", UIParent)
function WorldMapFrame:EnumeratePinsByTemplate(template)
    local i, list = 0, pins[template]
    return function() i = i + 1; return list[i] end
end
function WorldMapFrame:OnMapChanged() end
local function offerPin(questID, atlas, alpha)
    local pin = new("Frame", WorldMapFrame); pin.h = 20
    pin.Texture = pin:CreateTexture(nil, "ARTWORK", nil, 0); pin.Texture.h = 20
    pin.OnAcquired = function(self, offer) self.questID = offer.questID; self.pinAlpha = offer.pinAlpha; self.Texture:SetAtlas(offer.questIcon) end
    pin:OnAcquired({ questID = questID, pinAlpha = alpha or 1, questIcon = atlas or "QuestNormal" })
    table.insert(pins.QuestOfferPinTemplate, pin)
    return pin
end
local function questPin(questID, atlas)
    local pin = new("Frame", WorldMapFrame)
    pin.Display = new("Frame", pin); pin.Display.h = 24
    pin.Display.Icon = pin.Display:CreateTexture(nil, "ARTWORK", nil, 0); pin.Display.Icon.h = 24
    pin.GetQuestID = function(self) return self.qid end
    pin.OnAcquired = function(self, id, a) self.qid = id; self.Display.Icon:SetAtlas(a) end
    pin:OnAcquired(questID, atlas or "UI-QuestIcon-TurnIn-Normal")
    table.insert(pins.QuestPinTemplate, pin)
    return pin
end
local giver = offerPin(999999)
local oldGiver = offerPin(7)
local trivial = offerPin(999999, nil, 0.5)
local campaign = offerPin(999999, "Quest-Campaign-Available")
local turnin = questPin(999999)
local inProgress = questPin(999999, "UI-QuestPoi-Number")
ns.cfg.questieTint, ns.cfg.preview = true, "auto"
ns.Reapply()
local function pinTinted(owner) return owner.fqtSolid and owner.fqtSolid.shown end
check(pinTinted(giver) and giver.fqtSolid.file == "atlas:QuestNormal" and giver.fqtSolid.layer == "ARTWORK"
    and giver.fqtSolid.sublevel == 1 and math.abs(giver.fqtSolid.h - 20 * 0.45) < 0.001,
    "map pins: a marked quest giver's ! gets the gradient, from its atlas, just above it")
check(math.abs(giver.fqtSolid.coords[1] - 0.1) < 1e-9 and math.abs(giver.fqtSolid.coords[2] - 0.2) < 1e-9
    and math.abs(giver.fqtSolid.coords[4] - 0.4) < 1e-9, "map pins: the copy uses the atlas's part of its file")
check(pinTinted(turnin.Display), "map pins: a marked quest's turn-in ? gets the gradient")
check(not pinTinted(oldGiver) and not pinTinted(trivial) and not pinTinted(campaign) and not pinTinted(inProgress.Display),
    "map pins: vanilla, trivial, campaign and in-progress pins are left alone")
-- The map reuses a pin for another quest.
giver:OnAcquired({ questID = 7, pinAlpha = 1, questIcon = "QuestNormal" })
check(not pinTinted(giver), "map pins: a pin reused for a vanilla quest is plain again")
giver:OnAcquired({ questID = 999999, pinAlpha = 1, questIcon = "QuestNormal" })
check(pinTinted(giver), "map pins: and tinted again for a marked quest")
ns.cfg.questieTint = false; ns.Reapply()
check(not pinTinted(giver) and not pinTinted(turnin.Display), "map pins: the option turns them off")
ns.cfg.questieTint = true; ns.Reapply()

SlashCmdList.FQT("status")
print("ALL PASSED")
