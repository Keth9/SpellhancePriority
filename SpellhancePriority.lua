-- Spellhance Priority HUD v1.2.0
-- WotLK 3.3.5a / Interface 30300
-- HUD avanzado de prioridad para Enhancement Spellhance.

local ADDON = ...
local SPR = CreateFrame("Frame", "SpellhancePriorityFrame", UIParent)

local SPELL = {
    STORMSTRIKE      = 17364,
    LIGHTNING_BOLT   = 49238,
    CHAIN_LIGHTNING  = 49271,
    FLAME_SHOCK      = 49233,
    EARTH_SHOCK      = 49231,
    MAGMA_TOTEM      = 58734,
    FIRE_NOVA        = 61657,
    LAVA_LASH        = 60103,
    LIGHTNING_SHIELD = 49281,
    FIRE_ELEMENTAL   = 2894,
    MAELSTROM_BUFF   = 53817,
    WIND_SHEAR       = 57994,
    FERAL_SPIRIT     = 52120,
    SHAMANISTIC_RAGE = 30823,
    HEROISM          = 32182,
    BLOODLUST        = 2825,
    BLOOD_FURY       = 33697,
    BERSERKING       = 26297,
    GCD              = 61304,
}

-- CDs esperados usados SOLO para proyectar los iconos 2-5.
-- El primer icono siempre usa los CDs/auras reales del cliente.
local BASE_CD = {
    [SPELL.STORMSTRIKE]     = 8.0,
    [SPELL.CHAIN_LIGHTNING] = 6.0,
    [SPELL.FLAME_SHOCK]     = 6.0,
    [SPELL.EARTH_SHOCK]     = 6.0,
    [SPELL.FIRE_NOVA]       = 7.0, -- build de la guia con Glyph of Fire Nova
    [SPELL.LAVA_LASH]       = 6.0,
    [SPELL.FIRE_ELEMENTAL]  = 600.0,
}

local SHORT = {
    [SPELL.STORMSTRIKE]      = "SS",
    [SPELL.LIGHTNING_BOLT]   = "LB x5",
    [SPELL.CHAIN_LIGHTNING]  = "CL x5",
    [SPELL.FLAME_SHOCK]      = "FS",
    [SPELL.EARTH_SHOCK]      = "ES",
    [SPELL.MAGMA_TOTEM]      = "MAGMA",
    [SPELL.FIRE_NOVA]        = "NOVA",
    [SPELL.LAVA_LASH]        = "LL",
    [SPELL.LIGHTNING_SHIELD] = "LS",
    [SPELL.FIRE_ELEMENTAL]   = "FE",
    [SPELL.WIND_SHEAR]       = "CORTE",
}

local DEFAULTS = {
    locked = false,
    size = 72,
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = -120,
    mode = "auto", -- auto | st | aoe
    aoe = false, -- compatibilidad con v1.1
    useFireElemental = false,
    smartFireElemental = true,
    showStatus = true,
    sound = true,
    bigAlert = true,
    animation = true,
    interrupt = true,
    trainer = true,
    mwWasteAlert = true,
    mwWasteThreshold = 1.20,
    burstHints = true,
    suppressNova = false,
    autoAoeTargets = 2,
    autoAoeWindow = 2.5,
    profilesEnabled = true,
    profiles = {},
}

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99SpellhancePriority:|r " .. tostring(msg))
end

local function CopyDefaults()
    if not SpellhancePriorityDB then SpellhancePriorityDB = {} end
    local legacyMode = nil
    if SpellhancePriorityDB.mode == nil and SpellhancePriorityDB.aoe ~= nil then
        legacyMode = SpellhancePriorityDB.aoe and "aoe" or "st"
    end
    for k, v in pairs(DEFAULTS) do
        if SpellhancePriorityDB[k] == nil then
            if type(v) == "table" then SpellhancePriorityDB[k] = {} else SpellhancePriorityDB[k] = v end
        end
    end
    if legacyMode then SpellhancePriorityDB.mode = legacyMode end
    if not SpellhancePriorityDB.profiles then SpellhancePriorityDB.profiles = {} end
end

local function SpellName(id)
    local name = GetSpellInfo(id)
    return name
end

local function SpellIcon(id)
    local _, _, icon = GetSpellInfo(id)
    return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function CooldownLeft(id)
    local name = SpellName(id)
    if not name then return 999 end
    local start, duration, enabled = GetSpellCooldown(name)
    if enabled == 0 then return 999 end
    if not start or not duration or start == 0 or duration == 0 then return 0 end
    local left = start + duration - GetTime()
    if left < 0 then left = 0 end
    return left
end

local lastKnownSpellGCD = 1.5
local function GCDLeft()
    local start, duration = GetSpellCooldown(SPELL.GCD)
    if duration and duration >= 1.0 and duration <= 1.5 then lastKnownSpellGCD = duration end
    if not start or not duration or start == 0 or duration == 0 then return 0 end
    local left = start + duration - GetTime()
    if left < 0 then left = 0 end
    return left
end

local function Ready(id)
    local name = SpellName(id)
    if not name then return false end

    local usable = IsUsableSpell(name)
    if usable == nil or usable == false or usable == 0 then return false end

    return CooldownLeft(id) <= (GCDLeft() + 0.12)
end

local function InRange(id, unit)
    local name = SpellName(id)
    if not name then return false end
    local r = IsSpellInRange(name, unit or "target")
    return r == nil or r == 1
end

local function FindAura(unit, helpful, wantedID, onlyMine)
    local wantedName = SpellName(wantedID)
    if not wantedName then return nil end

    for i = 1, 40 do
        local name, rank, icon, count, debuffType, duration, expirationTime, source, isStealable, shouldConsolidate, spellId
        if helpful then
            name, rank, icon, count, debuffType, duration, expirationTime, source, isStealable, shouldConsolidate, spellId = UnitBuff(unit, i)
        else
            name, rank, icon, count, debuffType, duration, expirationTime, source, isStealable, shouldConsolidate, spellId = UnitDebuff(unit, i)
        end
        if not name then break end
        if (spellId == wantedID or name == wantedName) and (not onlyMine or source == "player") then
            local left = 0
            if expirationTime and expirationTime > 0 then
                left = expirationTime - GetTime()
                if left < 0 then left = 0 end
            end
            return {
                name = name,
                count = count or 0,
                duration = duration or 0,
                expiration = expirationTime or 0,
                left = left,
                source = source,
                spellId = spellId,
            }
        end
    end
    return nil
end

local function FireTotemInfo()
    -- Slot 1 = Fuego en WotLK 3.3.5a.
    -- No dependemos del nombre exacto porque algunos clientes/servidores
    -- devuelven el rango en el nombre (ej. "Tótem de magma VII").
    local haveTotem, name, startTime, duration, icon = GetTotemInfo(1)
    local active = haveTotem and name and name ~= "" and duration and duration > 0
    local left = 0

    if active then
        if GetTotemTimeLeft then
            left = GetTotemTimeLeft(1) or 0
        elseif startTime then
            left = startTime + duration - GetTime()
        end
        if left < 0 then left = 0 end
    end

    return name or "", left, icon, duration or 0, active and true or false
end

local function SameTexture(a, b)
    if not a or not b then return false end
    return string.lower(tostring(a)) == string.lower(tostring(b))
end

local function NameContains(fullName, baseName)
    if not fullName or fullName == "" or not baseName or baseName == "" then return false end
    return string.find(string.lower(fullName), string.lower(baseName), 1, true) ~= nil
end

local function FireTotemType(name, icon, duration, active)
    if not active then return "none" end

    local feName = SpellName(SPELL.FIRE_ELEMENTAL)
    local magmaName = SpellName(SPELL.MAGMA_TOTEM)
    local feIcon = SpellIcon(SPELL.FIRE_ELEMENTAL)
    local magmaIcon = SpellIcon(SPELL.MAGMA_TOTEM)

    -- Señales fuertes e independientes del idioma: textura del hechizo.
    if SameTexture(icon, feIcon) then return "fe" end
    if SameTexture(icon, magmaIcon) then return "magma" end

    -- Fallback localizado: admite sufijos de rango en GetTotemInfo().
    if NameContains(name, feName) then return "fe" end
    if NameContains(name, magmaName) then return "magma" end

    -- Último fallback para 3.3.5: Magma dura ~20 s; evita falsos
    -- "poner Magma" cuando el servidor cambia el texto/icono devuelto.
    if duration > 0 and duration <= 25 then return "magma" end

    return "other"
end

local function ValidTarget()
    return UnitExists("target")
        and not UnitIsDeadOrGhost("target")
        and UnitCanAttack("player", "target")
end

local function SpellGCD()
    local _, duration = GetSpellCooldown(SPELL.GCD)
    if duration and duration >= 1.0 and duration <= 1.5 then
        lastKnownSpellGCD = duration
        return duration
    end
    if lastKnownSpellGCD and lastKnownSpellGCD >= 1.0 and lastKnownSpellGCD <= 1.5 then
        return lastKnownSpellGCD
    end
    local haste = 0
    if GetCombatRatingBonus then haste = GetCombatRatingBonus(CR_HASTE_SPELL or 20) or 0 end
    local gcd = 1.5 / (1 + haste / 100)
    if gcd < 1.0 then gcd = 1.0 end
    if gcd > 1.5 then gcd = 1.5 end
    return gcd
end

local function ActionGCD(id)
    if id == SPELL.STORMSTRIKE or id == SPELL.LAVA_LASH then
        return 1.5
    end
    if id == SPELL.MAGMA_TOTEM or id == SPELL.FIRE_ELEMENTAL then
        return 1.0
    end
    return SpellGCD()
end

-- ESTADO DE COMBATE / AUTO-AOE / ENTRENAMIENTO ---------------------------------
local recentTargets = {}
local lastShock = nil
local lastShockTime = 0
local lastPrimaryID = nil
local combatStart = 0
local mw5Since = nil
local mwWasteWarned = false
local activeProfileName = nil
local trainer = {
    active = false, casts = 0, correct = 0, mw5 = 0, mwWaste = 0,
    magmaDown = 0, fsDown = 0, interrupts = 0, duration = 0,
}

local ROTATION_SPELL = {}
for _, id in ipairs({SPELL.STORMSTRIKE,SPELL.LIGHTNING_BOLT,SPELL.CHAIN_LIGHTNING,SPELL.FLAME_SHOCK,SPELL.EARTH_SHOCK,SPELL.MAGMA_TOTEM,SPELL.FIRE_NOVA,SPELL.LAVA_LASH,SPELL.LIGHTNING_SHIELD,SPELL.FIRE_ELEMENTAL}) do
    ROTATION_SPELL[id] = true
end

local function PruneRecentTargets()
    local now = GetTime()
    local win = (SpellhancePriorityDB and SpellhancePriorityDB.autoAoeWindow) or 2.5
    for guid, t in pairs(recentTargets) do
        if now - t > win then recentTargets[guid] = nil end
    end
end

local function RecentTargetCount()
    PruneRecentTargets()
    local n = 0
    for _ in pairs(recentTargets) do n = n + 1 end
    return n
end

local function IsAOE()
    local db = SpellhancePriorityDB
    if not db then return false end
    if db.mode == "aoe" then return true end
    if db.mode == "st" then return false end
    return RecentTargetCount() >= (db.autoAoeTargets or 2)
end

local function ModeText()
    local db = SpellhancePriorityDB
    if not db then return "ST" end
    if db.mode == "auto" then
        local n = RecentTargetCount()
        return IsAOE() and ("AUTO AOE:"..n) or ("AUTO ST:"..math.max(1,n))
    end
    return db.mode == "aoe" and "AOE" or "ST"
end

local function FindAnyPlayerBuff(ids)
    for _, id in ipairs(ids) do
        local a = FindAura("player", true, id, false)
        if a then return a, id end
    end
    return nil, nil
end

local function BurstScore()
    local score, labels = 0, {}
    local sets = {
        {SPELL.HEROISM, "Hero"}, {SPELL.BLOODLUST, "BL"}, {SPELL.SHAMANISTIC_RAGE, "SR"},
        {SPELL.BLOOD_FURY, "Furia"}, {SPELL.BERSERKING, "Berserk"},
    }
    for _, x in ipairs(sets) do
        if FindAura("player", true, x[1], false) then
            score = score + 1
            labels[#labels+1] = x[2]
        end
    end
    return score, table.concat(labels, "+")
end

local function TargetIsBoss()
    local c = UnitClassification and UnitClassification("target")
    return c == "worldboss" or c == "rareelite"
end

local function SpellIDByName(name)
    if not name then return nil end
    for id in pairs(ROTATION_SPELL) do
        if SpellName(id) == name then return id end
    end
    if SpellName(SPELL.WIND_SHEAR) == name then return SPELL.WIND_SHEAR end
    return nil
end

local function ResetTrainer()
    trainer.active = true
    trainer.casts, trainer.correct, trainer.mw5, trainer.mwWaste = 0,0,0,0
    trainer.magmaDown, trainer.fsDown, trainer.interrupts, trainer.duration = 0,0,0,0
    combatStart = GetTime()
    mw5Since, mwWasteWarned = nil, false
end

local function FinishTrainer()
    if not trainer.active then return end
    trainer.duration = math.max(0, GetTime() - combatStart)
    if SpellhancePriorityDB and SpellhancePriorityDB.trainer and trainer.duration > 3 then
        local pct = trainer.casts > 0 and math.floor((trainer.correct / trainer.casts) * 100 + 0.5) or 0
        Print(string.format("Resumen: %ds | prioridad seguida %d%% (%d/%d) | MWx5 %d | cap MW %.1fs | Magma caído %.1fs | FS caído %.1fs | cortes %d",
            trainer.duration, pct, trainer.correct, trainer.casts, trainer.mw5, trainer.mwWaste, trainer.magmaDown, trainer.fsDown, trainer.interrupts))
    end
    trainer.active = false
end

local function GetInterruptInfo()
    if not SpellhancePriorityDB or not SpellhancePriorityDB.interrupt or not ValidTarget() then return nil end
    local name, _, _, _, startMS, endMS, _, _, notInterruptible = UnitCastingInfo("target")
    if not name and UnitChannelInfo then
        name, _, _, _, startMS, endMS, _, notInterruptible = UnitChannelInfo("target")
    end
    if not name then return nil end
    if notInterruptible == true then return nil end
    if not Ready(SPELL.WIND_SHEAR) or not InRange(SPELL.WIND_SHEAR, "target") then return nil end
    local left = endMS and math.max(0, endMS / 1000 - GetTime()) or 0
    return name, left
end

local function ApplyProfileForTarget()
    if not SpellhancePriorityDB or not SpellhancePriorityDB.profilesEnabled then return end
    local name = UnitName("target")
    if not name then activeProfileName = nil return end
    if name == activeProfileName then return end
    activeProfileName = name
    local p = SpellhancePriorityDB.profiles and SpellhancePriorityDB.profiles[name]
    if p then
        if p.mode then SpellhancePriorityDB.mode = p.mode end
        if p.useFireElemental ~= nil then SpellhancePriorityDB.useFireElemental = p.useFireElemental end
        if p.interrupt ~= nil then SpellhancePriorityDB.interrupt = p.interrupt end
        if p.suppressNova ~= nil then SpellhancePriorityDB.suppressNova = p.suppressNova end
        Print("perfil cargado para " .. name .. ".")
    end
end

-- UI -------------------------------------------------------------------------
SPR:SetFrameStrata("HIGH")
SPR:SetClampedToScreen(true)
SPR:SetMovable(true)
SPR:RegisterForDrag("LeftButton")
SPR:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
SPR:SetBackdropColor(0.02, 0.02, 0.025, 0.88)
SPR:SetBackdropBorderColor(0.28, 0.28, 0.32, 0.95)

SPR.header = SPR:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
SPR.header:SetPoint("TOPLEFT", SPR, "TOPLEFT", 10, -8)
SPR.header:SetText("SPELLHANCE  |cffbbbbbbPRIORITY|r")

SPR.mode = SPR:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
SPR.mode:SetPoint("TOPRIGHT", SPR, "TOPRIGHT", -10, -8)
SPR.mode:SetText("ST")

SPR.slots = {}
for i = 1, 5 do
    local f = CreateFrame("Frame", nil, SPR)
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Buttons\\UI-Quickslot2",
        tile = false,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    f:SetBackdropColor(0, 0, 0, 0.92)
    f:SetBackdropBorderColor(0.55, 0.55, 0.58, 1)

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetPoint("TOPLEFT", 4, -4)
    f.icon:SetPoint("BOTTOMRIGHT", -4, 4)
    f.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    f.glow = f:CreateTexture(nil, "OVERLAY")
    f.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    f.glow:SetBlendMode("ADD")
    f.glow:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.glow:SetAlpha(i == 1 and 0.75 or 0.12)

    f.step = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    f.step:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -4)
    f.step:SetText(i == 1 and "AHORA" or tostring(i))

    f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.label:SetPoint("BOTTOM", f, "BOTTOM", 0, 5)
    f.label:SetText("-")

    f.cd = f:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    f.cd:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.cd:SetText("")

    f.eta = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.eta:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    f.eta:SetText("")

    f.badge = f:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    f.badge:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -5, 5)
    f.badge:SetText("")

    SPR.slots[i] = f
end

SPR.reason = SPR:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
SPR.reason:SetJustifyH("LEFT")
SPR.reason:SetText("")

SPR.status = SPR:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
SPR.status:SetJustifyH("LEFT")
SPR.status:SetText("")

SPR.tip = SPR:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
SPR.tip:SetJustifyH("RIGHT")
SPR.tip:SetText("/spr")

SPR.mwBar = CreateFrame("StatusBar", nil, SPR)
SPR.mwBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
SPR.mwBar:SetStatusBarColor(0.25, 0.65, 1.0, 1)
SPR.mwBar:SetMinMaxValues(0, 5)
SPR.mwBar:SetValue(0)
SPR.mwBar:SetHeight(6)
SPR.mwBar.bg = SPR.mwBar:CreateTexture(nil, "BACKGROUND")
SPR.mwBar.bg:SetAllPoints(true)
SPR.mwBar.bg:SetTexture(0.08,0.08,0.08,0.9)

SPR.fireBar = CreateFrame("StatusBar", nil, SPR)
SPR.fireBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
SPR.fireBar:SetStatusBarColor(1.0, 0.35, 0.08, 1)
SPR.fireBar:SetMinMaxValues(0, 20)
SPR.fireBar:SetValue(0)
SPR.fireBar:SetHeight(5)
SPR.fireBar.bg = SPR.fireBar:CreateTexture(nil, "BACKGROUND")
SPR.fireBar.bg:SetAllPoints(true)
SPR.fireBar.bg:SetTexture(0.08,0.08,0.08,0.9)

SPR.interruptBanner = CreateFrame("Frame", nil, SPR)
SPR.interruptBanner:SetHeight(28)
SPR.interruptBanner:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", tile=true, tileSize=8, edgeSize=8, insets={left=2,right=2,top=2,bottom=2}})
SPR.interruptBanner:SetBackdropColor(0.18,0.02,0.02,0.96)
SPR.interruptBanner:SetBackdropBorderColor(1,0.15,0.12,1)
SPR.interruptBanner.icon = SPR.interruptBanner:CreateTexture(nil,"ARTWORK")
SPR.interruptBanner.icon:SetWidth(22); SPR.interruptBanner.icon:SetHeight(22)
SPR.interruptBanner.icon:SetPoint("LEFT",4,0); SPR.interruptBanner.icon:SetTexture(SpellIcon(SPELL.WIND_SHEAR))
SPR.interruptBanner.text = SPR.interruptBanner:CreateFontString(nil,"OVERLAY","GameFontNormal")
SPR.interruptBanner.text:SetPoint("LEFT",SPR.interruptBanner.icon,"RIGHT",6,0)
SPR.interruptBanner.text:SetText("CORTE DE VIENTO")
SPR.interruptBanner:Hide()

-- Alerta grande MW x5
SPR.alert = CreateFrame("Frame", "SpellhancePriorityMWAlert", UIParent)
SPR.alert:SetFrameStrata("DIALOG")
SPR.alert:SetWidth(340)
SPR.alert:SetHeight(126)
SPR.alert:SetPoint("CENTER", UIParent, "CENTER", 0, 115)
SPR.alert:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
SPR.alert:SetBackdropColor(0.03, 0.03, 0.03, 0.93)
SPR.alert:SetBackdropBorderColor(1, 0.72, 0.12, 1)
SPR.alert.icon = SPR.alert:CreateTexture(nil, "ARTWORK")
SPR.alert.icon:SetWidth(84)
SPR.alert.icon:SetHeight(84)
SPR.alert.icon:SetPoint("LEFT", SPR.alert, "LEFT", 18, 0)
SPR.alert.icon:SetTexture(SpellIcon(SPELL.LIGHTNING_BOLT))
SPR.alert.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
SPR.alert.glow = SPR.alert:CreateTexture(nil, "OVERLAY")
SPR.alert.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
SPR.alert.glow:SetBlendMode("ADD")
SPR.alert.glow:SetWidth(142)
SPR.alert.glow:SetHeight(142)
SPR.alert.glow:SetPoint("CENTER", SPR.alert.icon, "CENTER", 0, 0)
SPR.alert.title = SPR.alert:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
SPR.alert.title:SetPoint("TOPLEFT", SPR.alert.icon, "TOPRIGHT", 18, -7)
SPR.alert.title:SetText("VORÁGINE x5")
SPR.alert.sub = SPR.alert:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
SPR.alert.sub:SetPoint("TOPLEFT", SPR.alert.title, "BOTTOMLEFT", 0, -9)
SPR.alert.sub:SetText("¡LANZA DESCARGA!")
SPR.alert:Hide()
SPR.alert.timer = 0

SPR:SetScript("OnDragStart", function(self)
    if not SpellhancePriorityDB.locked then
        self:StartMoving()
    end
end)

SPR:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint(1)
    SpellhancePriorityDB.point = point or "CENTER"
    SpellhancePriorityDB.relativePoint = relativePoint or "CENTER"
    SpellhancePriorityDB.x = x or 0
    SpellhancePriorityDB.y = y or 0
end)

local function ApplySettings()
    local db = SpellhancePriorityDB
    local main = db.size
    local small = math.floor(main * 0.72)
    local gap = 6
    local pad = 10
    local top = 27
    local bottom = db.showStatus and 78 or 56
    local width = pad * 2 + main + small * 4 + gap * 4
    local height = top + main + bottom

    SPR:SetWidth(width)
    SPR:SetHeight(height)
    SPR:ClearAllPoints()
    SPR:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
    SPR:EnableMouse(not db.locked)

    for i = 1, 5 do
        local f = SPR.slots[i]
        local s = (i == 1) and main or small
        f:SetWidth(s)
        f:SetHeight(s)
        f.glow:SetWidth(s * (i == 1 and 1.65 or 1.45))
        f.glow:SetHeight(s * (i == 1 and 1.65 or 1.45))
        f:ClearAllPoints()
        if i == 1 then
            f:SetPoint("TOPLEFT", SPR, "TOPLEFT", pad, -top)
        else
            f:SetPoint("LEFT", SPR.slots[i - 1], "RIGHT", gap, 0)
        end
        if i == 1 then
            f.step:SetFontObject("GameFontNormalSmall")
        else
            f.step:SetFontObject("NumberFontNormalSmall")
        end
    end

    SPR.reason:ClearAllPoints()
    SPR.reason:SetPoint("TOPLEFT", SPR.slots[1], "BOTTOMLEFT", 0, -8)
    SPR.reason:SetPoint("RIGHT", SPR, "RIGHT", -10, 0)

    SPR.status:ClearAllPoints()
    SPR.status:SetPoint("TOPLEFT", SPR.reason, "BOTTOMLEFT", 0, -4)
    SPR.status:SetPoint("RIGHT", SPR, "RIGHT", -10, 0)

    SPR.mwBar:ClearAllPoints()
    SPR.mwBar:SetPoint("LEFT", SPR, "LEFT", 10, 0)
    SPR.mwBar:SetPoint("RIGHT", SPR, "RIGHT", -10, 0)
    SPR.mwBar:SetPoint("BOTTOM", SPR, "BOTTOM", 0, 18)
    SPR.fireBar:ClearAllPoints()
    SPR.fireBar:SetPoint("LEFT", SPR, "LEFT", 10, 0)
    SPR.fireBar:SetPoint("RIGHT", SPR, "RIGHT", -10, 0)
    SPR.fireBar:SetPoint("BOTTOM", SPR, "BOTTOM", 0, 10)
    SPR.interruptBanner:ClearAllPoints()
    SPR.interruptBanner:SetPoint("BOTTOMLEFT", SPR, "TOPLEFT", 0, 5)
    SPR.interruptBanner:SetPoint("BOTTOMRIGHT", SPR, "TOPRIGHT", 0, 5)

    SPR.tip:ClearAllPoints()
    SPR.tip:SetPoint("BOTTOMRIGHT", SPR, "BOTTOMRIGHT", -8, 1)

    if db.showStatus then SPR.status:Show() else SPR.status:Hide() end
end

local function FormatLeft(aura)
    if not aura then return "-" end
    if aura.left <= 0 then return "0" end
    return string.format("%.1f", aura.left)
end

local lastQueueKey = ""
local bounceTimer = 0
local lastMW = 0

local function SetSlot(i, id, label, eta, mw)
    local f = SPR.slots[i]
    if not id then
        f.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        f.label:SetText("-")
        f.eta:SetText("")
        f.badge:SetText("")
        f.cd:SetText("")
        f:SetBackdropBorderColor(0.35,0.35,0.38,1)
        f:SetAlpha(i == 1 and 0.75 or 0.38)
        return
    end
    f.icon:SetTexture(SpellIcon(id))
    f.label:SetText(label or SHORT[id] or (SpellName(id) or "?"))
    f.eta:SetText((eta and eta > 0.05) and string.format("+%.1f", eta) or "")
    if (id == SPELL.LIGHTNING_BOLT or id == SPELL.CHAIN_LIGHTNING) and mw and mw > 0 then
        f.badge:SetText(tostring(mw))
    else
        f.badge:SetText("")
    end
    f.cd:SetText("")
    if i == 1 then
        local cd = CooldownLeft(id)
        if cd > 0.12 then f.cd:SetText(string.format("%.1f", cd)) end
        if not InRange(id, "target") and id ~= SPELL.MAGMA_TOTEM and id ~= SPELL.FIRE_ELEMENTAL and id ~= SPELL.LIGHTNING_SHIELD then
            f:SetBackdropBorderColor(1,0.18,0.15,1)
        else
            f:SetBackdropBorderColor(1,0.72,0.12,1)
        end
    else
        f:SetBackdropBorderColor(0.38,0.58,0.78,0.95)
    end
    f:SetAlpha(i == 1 and 1 or (0.90 - (i - 2) * 0.09))
end

local function SetQueue(queue, reason, mw)
    local parts = {}
    for i = 1, 5 do
        local a = queue[i]
        SetSlot(i, a and a.id, a and a.label, a and a.eta, mw)
        parts[#parts + 1] = tostring(a and a.id or 0)
    end
    local key = table.concat(parts, ":")
    if key ~= lastQueueKey then
        bounceTimer = 0.20
        lastQueueKey = key
    end
    lastPrimaryID = queue[1] and queue[1].id or nil
    SPR.reason:SetText(reason or "")
    SPR:Show()
end

local function SetIdle(text)
    for i = 1, 5 do SetSlot(i, nil, nil) end
    SPR.reason:SetText(text or "Sin objetivo")
    SPR.status:SetText("")
    SPR:Show()
end

local function UpdateStatus(mw, ss, fs, fireName, fireLeft, fireType, burstLabel)
    local mt = ModeText()
    if string.find(mt,"AOE",1,true) then
        SPR.mode:SetText("|cffff9d00"..mt.."|r")
    else
        SPR.mode:SetText("|cff66ccff"..mt.."|r")
    end
    SPR.mwBar:SetValue(math.min(5, mw or 0))
    if fireType == "magma" then
        SPR.fireBar:SetMinMaxValues(0,20); SPR.fireBar:SetValue(math.min(20,fireLeft or 0))
        SPR.fireBar:Show()
    elseif fireType == "fe" then
        SPR.fireBar:SetMinMaxValues(0,120); SPR.fireBar:SetValue(math.min(120,fireLeft or 0))
        SPR.fireBar:Show()
    else
        SPR.fireBar:SetValue(0)
    end
    if not SpellhancePriorityDB.showStatus then return end
    local fireText = "sin fuego"
    if fireName ~= "" then fireText = fireName .. " " .. string.format("%.1f", fireLeft) end
    local shockText = lastShock == SPELL.FLAME_SHOCK and "FS" or (lastShock == SPELL.EARTH_SHOCK and "ES" or "-")
    local burst = (SpellhancePriorityDB.burstHints and burstLabel and burstLabel ~= "") and ("   |cffffc44dBURST:"..burstLabel.."|r") or ""
    local wolves = ""
    if SpellhancePriorityDB.burstHints and UnitAffectingCombat("player") and Ready(SPELL.FERAL_SPIRIT) then
        local early = combatStart > 0 and (GetTime() - combatStart) <= 10
        if early or (burstLabel and burstLabel ~= "") then wolves = "   |cffb084ffLOBOS READY|r" end
    end
    SPR.status:SetText(string.format("MW |cffffffff%d|r   SS %s   FS %s   shock:%s   |cffbbbbbb%s|r%s%s",
        mw, FormatLeft(ss), FormatLeft(fs), shockText, fireText, burst, wolves))
end

-- SIMULACION DE COLA ---------------------------------------------------------
local function SnapshotState(ss, fs, mw, lsCount, fireName, fireLeft, fireIcon, fireDuration, fireActive)
    local s = {
        ssLeft = ss and ss.left or 0,
        fsLeft = fs and fs.left or 0,
        mw = mw,
        lsCount = lsCount,
        fireType = FireTotemType(fireName, fireIcon, fireDuration, fireActive),
        fireLeft = fireLeft or 0,
        cds = {},
        firstWindow = GCDLeft() + 0.12,
        lastShock = lastShock,
        burstScore = BurstScore(),
    }
    local ids = {
        SPELL.STORMSTRIKE, SPELL.LIGHTNING_BOLT, SPELL.CHAIN_LIGHTNING,
        SPELL.FLAME_SHOCK, SPELL.EARTH_SHOCK, SPELL.MAGMA_TOTEM,
        SPELL.FIRE_NOVA, SPELL.LAVA_LASH, SPELL.LIGHTNING_SHIELD,
        SPELL.FIRE_ELEMENTAL,
    }
    for _, id in ipairs(ids) do s.cds[id] = CooldownLeft(id) end
    return s
end

local function SimReady(s, id, window)
    return (s.cds[id] or 0) <= (window or 0.12)
end

local function PickFromState(s, first)
    local w = first and s.firstWindow or 0.12
    local function CanUse(id)
        if first then return Ready(id) end
        return SimReady(s, id, w)
    end

    if s.ssLeft <= 0 and CanUse(SPELL.STORMSTRIKE) and (not first or InRange(SPELL.STORMSTRIKE, "target")) then
        return SPELL.STORMSTRIKE, "Falta debuff de Stormstrike"
    end

    if s.mw >= 5 then
        local id = IsAOE() and SPELL.CHAIN_LIGHTNING or SPELL.LIGHTNING_BOLT
        if CanUse(id) and (not first or InRange(id, "target")) then
            return id, IsAOE() and "Maelstrom x5 + AOE" or "Maelstrom x5"
        end
    end

    -- Shocks: alternancia real FS -> ES, sin dejar caer FS.
    if CanUse(SPELL.FLAME_SHOCK) then
        if s.fsLeft <= 0 then
            if not first or InRange(SPELL.FLAME_SHOCK,"target") then return SPELL.FLAME_SHOCK, "Aplicar Flame Shock" end
        elseif s.lastShock == SPELL.FLAME_SHOCK and s.fsLeft > 0 then
            if not first or InRange(SPELL.EARTH_SHOCK,"target") then return SPELL.EARTH_SHOCK, "Alternar a Earth Shock" end
        elseif s.lastShock == SPELL.EARTH_SHOCK and s.fsLeft <= 7.0 then
            if not first or InRange(SPELL.FLAME_SHOCK,"target") then return SPELL.FLAME_SHOCK, "Alternar a Flame Shock" end
        elseif not s.lastShock then
            if s.fsLeft <= 7.0 then
                if not first or InRange(SPELL.FLAME_SHOCK,"target") then return SPELL.FLAME_SHOCK, "Refrescar Flame Shock" end
            else
                if not first or InRange(SPELL.EARTH_SHOCK,"target") then return SPELL.EARTH_SHOCK, "Earth Shock" end
            end
        end
    end

    if SpellhancePriorityDB.useFireElemental and s.fireType == "none" and CanUse(SPELL.FIRE_ELEMENTAL) then
        local smartOK = not SpellhancePriorityDB.smartFireElemental or (s.burstScore and s.burstScore > 0) or (TargetIsBoss() and combatStart > 0 and GetTime()-combatStart < 12)
        if smartOK then return SPELL.FIRE_ELEMENTAL, "Fire Elemental: ventana de burst" end
    end

    if s.fireType ~= "fe" then
        local needMagma = (s.fireType ~= "magma") or s.fireLeft <= 2.0
        if needMagma and CanUse(SPELL.MAGMA_TOTEM) then
            return SPELL.MAGMA_TOTEM, s.fireType == "magma" and "Refrescar Magma" or "Mantener Magma"
        end
    end

    if not SpellhancePriorityDB.suppressNova and s.fireType ~= "none" and CanUse(SPELL.FIRE_NOVA) then
        return SPELL.FIRE_NOVA, IsAOE() and "Fire Nova (AOE)" or "Fire Nova"
    end

    if CanUse(SPELL.STORMSTRIKE) and (not first or InRange(SPELL.STORMSTRIKE, "target")) then
        return SPELL.STORMSTRIKE, "Stormstrike"
    end

    if CanUse(SPELL.LAVA_LASH) and (not first or InRange(SPELL.LAVA_LASH, "target")) then
        return SPELL.LAVA_LASH, "Lava Lash"
    end

    if s.lsCount < 3 and CanUse(SPELL.LIGHTNING_SHIELD) then
        return SPELL.LIGHTNING_SHIELD, "Lightning Shield <3"
    end

    return nil, nil
end

local function AdvanceState(s, dt)
    if dt <= 0 then return end
    for id, left in pairs(s.cds) do
        left = left - dt
        if left < 0 then left = 0 end
        s.cds[id] = left
    end
    s.ssLeft = math.max(0, s.ssLeft - dt)
    s.fsLeft = math.max(0, s.fsLeft - dt)
    s.fireLeft = math.max(0, s.fireLeft - dt)
    if s.fireLeft <= 0 then s.fireType = "none" end
end

local function ApplyProjectedAction(s, id)
    if id == SPELL.STORMSTRIKE then
        s.cds[id] = BASE_CD[id]
        s.ssLeft = 12.0
    elseif id == SPELL.LIGHTNING_BOLT then
        s.mw = 0
    elseif id == SPELL.CHAIN_LIGHTNING then
        s.mw = 0
        s.cds[id] = BASE_CD[id]
    elseif id == SPELL.FLAME_SHOCK then
        s.cds[SPELL.FLAME_SHOCK] = BASE_CD[SPELL.FLAME_SHOCK]
        s.cds[SPELL.EARTH_SHOCK] = BASE_CD[SPELL.EARTH_SHOCK]
        s.fsLeft = 18.0
        s.lastShock = SPELL.FLAME_SHOCK
    elseif id == SPELL.EARTH_SHOCK then
        s.cds[SPELL.FLAME_SHOCK] = BASE_CD[SPELL.FLAME_SHOCK]
        s.cds[SPELL.EARTH_SHOCK] = BASE_CD[SPELL.EARTH_SHOCK]
        s.lastShock = SPELL.EARTH_SHOCK
    elseif id == SPELL.MAGMA_TOTEM then
        s.fireType = "magma"
        s.fireLeft = 20.0
    elseif id == SPELL.FIRE_ELEMENTAL then
        s.fireType = "fe"
        s.fireLeft = 120.0
        s.cds[id] = BASE_CD[id]
    elseif id == SPELL.FIRE_NOVA then
        s.cds[id] = BASE_CD[id]
    elseif id == SPELL.LAVA_LASH then
        s.cds[id] = BASE_CD[id]
    elseif id == SPELL.LIGHTNING_SHIELD then
        s.lsCount = 3
    end
    AdvanceState(s, ActionGCD(id))
    s.firstWindow = 0
end

local function NextWait(s)
    local best = 9.0
    local consider = {
        SPELL.STORMSTRIKE, SPELL.CHAIN_LIGHTNING, SPELL.FLAME_SHOCK,
        SPELL.EARTH_SHOCK, SPELL.FIRE_NOVA, SPELL.LAVA_LASH,
        SPELL.LIGHTNING_SHIELD, SPELL.MAGMA_TOTEM, SPELL.FIRE_ELEMENTAL,
    }
    for _, id in ipairs(consider) do
        local v = s.cds[id] or 0
        if v > 0.12 and v < best then best = v end
    end
    if s.ssLeft > 0 and s.ssLeft < best then best = s.ssLeft end
    if s.fireType == "magma" and s.fireLeft > 2 and (s.fireLeft - 2) < best then best = s.fireLeft - 2 end
    if best == 9.0 then best = 0.25 end
    if best < 0.05 then best = 0.05 end
    return best
end

local function BuildQueue(state)
    local queue = {}
    local reason = ""
    local eta = 0
    for i = 1, 5 do
        local id, why = PickFromState(state, i == 1)
        local tries = 0
        while not id and tries < 10 do
            local wait = NextWait(state)
            AdvanceState(state, wait)
            eta = eta + wait
            id, why = PickFromState(state, false)
            tries = tries + 1
        end
        if not id then break end
        queue[i] = { id = id, label = SHORT[id] or SpellName(id), eta = eta }
        if i == 1 then reason = why or "" end
        local dt = ActionGCD(id)
        ApplyProjectedAction(state, id)
        eta = eta + dt
    end
    return queue, reason
end

-- RECOMENDACION --------------------------------------------------------------
local function SetInterruptBanner()
    local castName, left = GetInterruptInfo()
    if castName then
        SPR.interruptBanner.text:SetText(string.format("|cffff5045CORTE|r  %s  |cffffffff%.1fs|r", castName, left or 0))
        SPR.interruptBanner:Show()
    else
        SPR.interruptBanner:Hide()
    end
end

local function WarnWeaponImbues()
    if not GetWeaponEnchantInfo then return "" end
    local mh, _, _, oh = GetWeaponEnchantInfo()
    if mh and oh then return "" end
    if not mh and not oh then return "  |cffff6666IMBUE MH+OH|r" end
    if not mh then return "  |cffff6666IMBUE MH|r" end
    return "  |cffff6666IMBUE OH|r"
end

local function TriggerMWWasteAlert(seconds)
    if not SpellhancePriorityDB.bigAlert or not SpellhancePriorityDB.mwWasteAlert then return end
    SPR.alert.icon:SetTexture(SpellIcon(IsAOE() and SPELL.CHAIN_LIGHTNING or SPELL.LIGHTNING_BOLT))
    SPR.alert.title:SetText("¡GASTA VORÁGINE!")
    SPR.alert.sub:SetText(string.format("x5 desde hace %.1fs", seconds or 0))
    SPR.alert:SetBackdropBorderColor(1, 0.16, 0.10, 1)
    SPR.alert.timer = 1.0
    SPR.alert:SetAlpha(1)
    SPR.alert:Show()
    if SpellhancePriorityDB.sound and PlaySound then pcall(PlaySound, "RaidWarning") end
end

local function TriggerMWAlert()
    if not SpellhancePriorityDB.bigAlert then return end
    SPR.alert.icon:SetTexture(SpellIcon(IsAOE() and SPELL.CHAIN_LIGHTNING or SPELL.LIGHTNING_BOLT))
    SPR.alert.title:SetText("VORÁGINE x5")
    SPR.alert.sub:SetText(IsAOE() and "¡LANZA CADENA!" or "¡LANZA DESCARGA!")
    SPR.alert:SetBackdropBorderColor(1, 0.72, 0.12, 1)
    SPR.alert.timer = 1.35
    SPR.alert:SetAlpha(1)
    SPR.alert:Show()
    if SpellhancePriorityDB.sound then
        if PlaySound then
            pcall(PlaySound, "RaidWarning")
        elseif PlaySoundFile then
            pcall(PlaySoundFile, "Sound\\Interface\\RaidWarning.wav")
        end
    end
end

local function Recommend()
    local _, class = UnitClass("player")
    if class ~= "SHAMAN" then
        SetIdle("Solo para Chamán")
        return
    end

    local mwAura = FindAura("player", true, SPELL.MAELSTROM_BUFF, false)
    local mw = mwAura and mwAura.count or 0
    if mw >= 5 and lastMW < 5 then
        TriggerMWAlert()
        if trainer.active then trainer.mw5 = trainer.mw5 + 1 end
    end
    lastMW = mw

    SetInterruptBanner()

    if not ValidTarget() then
        if SpellhancePriorityDB.locked and UnitAffectingCombat("player") then
            SPR:Hide()
        else
            SetIdle("Selecciona un enemigo")
            SPR.mode:SetText(SpellhancePriorityDB.mode == "aoe" and "|cffff9d00AOE|r" or "|cff66ccffST|r")
        end
        return
    end

    local ss = FindAura("target", false, SPELL.STORMSTRIKE, true)
    local fs = FindAura("target", false, SPELL.FLAME_SHOCK, true)
    local ls = FindAura("player", true, SPELL.LIGHTNING_SHIELD, false)
    local lsCount = ls and ls.count or 0
    local fireName, fireLeft, fireIcon, fireDuration, fireActive = FireTotemInfo()
    local fireType = FireTotemType(fireName, fireIcon, fireDuration, fireActive)
    local _, burstLabel = BurstScore()

    UpdateStatus(mw, ss, fs, fireName, fireLeft, fireType, burstLabel)

    local state = SnapshotState(ss, fs, mw, lsCount, fireName, fireLeft, fireIcon, fireDuration, fireActive)
    local queue, reason = BuildQueue(state)
    reason = (reason or "") .. WarnWeaponImbues()
    SetQueue(queue, reason, mw)
end

-- ENTRENAMIENTO / TELEMETRIA -------------------------------------------------
local metricsElapsed = 0
local function UpdateTrainerMetrics(elapsed)
    if not UnitAffectingCombat("player") or not ValidTarget() then return end

    local mwAura = FindAura("player", true, SPELL.MAELSTROM_BUFF, false)
    local mw = mwAura and mwAura.count or 0
    if mw >= 5 then
        if trainer.active then trainer.mwWaste = trainer.mwWaste + elapsed end
        if not mw5Since then mw5Since = GetTime() end
        local held = GetTime() - mw5Since
        if SpellhancePriorityDB.mwWasteAlert and not mwWasteWarned and held >= (SpellhancePriorityDB.mwWasteThreshold or 1.2) then
            mwWasteWarned = true
            TriggerMWWasteAlert(held)
        end
    else
        mw5Since = nil
        mwWasteWarned = false
    end

    if not trainer.active or not SpellhancePriorityDB.trainer then return end
    local fs = FindAura("target", false, SPELL.FLAME_SHOCK, true)
    if not fs then trainer.fsDown = trainer.fsDown + elapsed end

    local fireName, fireLeft, fireIcon, fireDuration, fireActive = FireTotemInfo()
    local fireType = FireTotemType(fireName, fireIcon, fireDuration, fireActive)
    if fireType ~= "magma" and fireType ~= "fe" then
        trainer.magmaDown = trainer.magmaDown + elapsed
    end
end

local function RecordSuccessfulCast(unit, spellName)
    if unit ~= "player" or not spellName then return end
    local id = SpellIDByName(spellName)
    if not id then return end

    if id == SPELL.FLAME_SHOCK or id == SPELL.EARTH_SHOCK then
        lastShock = id
        lastShockTime = GetTime()
    end

    if trainer.active and ROTATION_SPELL[id] then
        trainer.casts = trainer.casts + 1
        if lastPrimaryID == id then trainer.correct = trainer.correct + 1 end
    end
end

local function RecordCombatLog(...)
    local timestamp, subevent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName = ...
    local playerGUID = UnitGUID("player")
    if not sourceGUID or sourceGUID ~= playerGUID then return end

    if destGUID and (subevent == "SWING_DAMAGE" or subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "RANGE_DAMAGE") then
        recentTargets[destGUID] = GetTime()
    end

    if subevent == "SPELL_INTERRUPT" and trainer.active then
        trainer.interrupts = trainer.interrupts + 1
    end
end

-- PERFILES -------------------------------------------------------------------
local function SaveProfileForTarget()
    if not ValidTarget() then Print("selecciona un boss/objetivo primero.") return end
    local name = UnitName("target")
    if not name then return end
    SpellhancePriorityDB.profiles[name] = {
        mode = SpellhancePriorityDB.mode,
        useFireElemental = SpellhancePriorityDB.useFireElemental,
        interrupt = SpellhancePriorityDB.interrupt,
        suppressNova = SpellhancePriorityDB.suppressNova,
    }
    Print("perfil guardado para " .. name .. ".")
end

local function DeleteProfileForTarget()
    if not UnitExists("target") then Print("selecciona el objetivo cuyo perfil quieres borrar.") return end
    local name = UnitName("target")
    if name and SpellhancePriorityDB.profiles[name] then
        SpellhancePriorityDB.profiles[name] = nil
        Print("perfil borrado para " .. name .. ".")
    else
        Print("ese objetivo no tiene perfil guardado.")
    end
end

local function ListProfiles()
    local n = 0
    for name, p in pairs(SpellhancePriorityDB.profiles or {}) do
        n = n + 1
        Print(string.format("perfil: %s | %s | FE:%s | corte:%s | nova:%s", name, p.mode or "auto", p.useFireElemental and "on" or "off", p.interrupt and "on" or "off", p.suppressNova and "off" or "on"))
    end
    if n == 0 then Print("no hay perfiles guardados.") end
end

local function DebugState()
    local fireName, fireLeft, fireIcon, fireDuration, fireActive = FireTotemInfo()
    local fireType = FireTotemType(fireName, fireIcon, fireDuration, fireActive)
    local mwAura = FindAura("player", true, SPELL.MAELSTROM_BUFF, false)
    local ss = ValidTarget() and FindAura("target", false, SPELL.STORMSTRIKE, true) or nil
    local fs = ValidTarget() and FindAura("target", false, SPELL.FLAME_SHOCK, true) or nil
    Print(string.format("DEBUG mode=%s autoTargets=%d MW=%d SS=%s FS=%s fuego='%s' type=%s left=%.1f dur=%.1f active=%s",
        SpellhancePriorityDB.mode or "?", RecentTargetCount(), mwAura and mwAura.count or 0,
        FormatLeft(ss), FormatLeft(fs), tostring(fireName), tostring(fireType), fireLeft or 0, fireDuration or 0, tostring(fireActive)))
end

-- SLASH COMMANDS -------------------------------------------------------------
SLASH_SPELLHANCEPRIORITY1 = "/spr"
SLASH_SPELLHANCEPRIORITY2 = "/spellhance"
SlashCmdList["SPELLHANCEPRIORITY"] = function(msg)
    msg = string.lower(msg or "")
    local cmd, arg = string.match(msg, "^(%S*)%s*(.-)$")

    if cmd == "lock" then
        SpellhancePriorityDB.locked = true
        ApplySettings(); Print("bloqueado.")
    elseif cmd == "unlock" then
        SpellhancePriorityDB.locked = false
        ApplySettings(); SPR:Show(); Print("desbloqueado; arrastra el HUD con clic izquierdo.")
    elseif cmd == "auto" then
        SpellhancePriorityDB.mode = "auto"; Print("modo AUTO ST/AOE.")
    elseif cmd == "aoe" then
        SpellhancePriorityDB.mode = "aoe"; SpellhancePriorityDB.aoe = true; Print("modo AOE forzado.")
    elseif cmd == "st" or cmd == "single" then
        SpellhancePriorityDB.mode = "st"; SpellhancePriorityDB.aoe = false; Print("modo ST forzado.")
    elseif cmd == "fe" then
        if arg == "on" then SpellhancePriorityDB.useFireElemental = true
        elseif arg == "off" then SpellhancePriorityDB.useFireElemental = false
        else Print("uso: /spr fe on | off") return end
        Print("Fire Elemental en prioridad: " .. (SpellhancePriorityDB.useFireElemental and "ON" or "OFF"))
    elseif cmd == "smartfe" then
        if arg == "on" then SpellhancePriorityDB.smartFireElemental = true
        elseif arg == "off" then SpellhancePriorityDB.smartFireElemental = false
        else SpellhancePriorityDB.smartFireElemental = not SpellhancePriorityDB.smartFireElemental end
        Print("Fire Elemental inteligente: " .. (SpellhancePriorityDB.smartFireElemental and "ON" or "OFF"))
    elseif cmd == "interrupt" or cmd == "corte" then
        if arg == "on" then SpellhancePriorityDB.interrupt = true
        elseif arg == "off" then SpellhancePriorityDB.interrupt = false
        else SpellhancePriorityDB.interrupt = not SpellhancePriorityDB.interrupt end
        Print("aviso de Corte de viento: " .. (SpellhancePriorityDB.interrupt and "ON" or "OFF"))
    elseif cmd == "trainer" then
        if arg == "on" then SpellhancePriorityDB.trainer = true
        elseif arg == "off" then SpellhancePriorityDB.trainer = false
        else SpellhancePriorityDB.trainer = not SpellhancePriorityDB.trainer end
        Print("modo entrenamiento: " .. (SpellhancePriorityDB.trainer and "ON" or "OFF"))
    elseif cmd == "waste" then
        if arg == "on" then SpellhancePriorityDB.mwWasteAlert = true
        elseif arg == "off" then SpellhancePriorityDB.mwWasteAlert = false
        else SpellhancePriorityDB.mwWasteAlert = not SpellhancePriorityDB.mwWasteAlert end
        Print("aviso MWx5 retenido: " .. (SpellhancePriorityDB.mwWasteAlert and "ON" or "OFF"))
    elseif cmd == "threshold" then
        local n = tonumber(arg)
        if n and n >= 0.4 and n <= 5 then SpellhancePriorityDB.mwWasteThreshold = n; Print("umbral MWx5: "..n.."s")
        else Print("uso: /spr threshold 0.4-5") end
    elseif cmd == "nova" then
        if arg == "on" then SpellhancePriorityDB.suppressNova = false
        elseif arg == "off" then SpellhancePriorityDB.suppressNova = true
        else SpellhancePriorityDB.suppressNova = not SpellhancePriorityDB.suppressNova end
        Print("Fire Nova: " .. (SpellhancePriorityDB.suppressNova and "OFF" or "ON"))
    elseif cmd == "burst" then
        if arg == "on" then SpellhancePriorityDB.burstHints = true
        elseif arg == "off" then SpellhancePriorityDB.burstHints = false
        else SpellhancePriorityDB.burstHints = not SpellhancePriorityDB.burstHints end
        Print("avisos de burst: " .. (SpellhancePriorityDB.burstHints and "ON" or "OFF"))
    elseif cmd == "autotargets" then
        local n = tonumber(arg)
        if n and n >= 2 and n <= 5 then SpellhancePriorityDB.autoAoeTargets = math.floor(n); Print("AUTO AOE desde "..math.floor(n).." objetivos.")
        else Print("uso: /spr autotargets 2-5") end
    elseif cmd == "autowindow" then
        local n = tonumber(arg)
        if n and n >= 1 and n <= 6 then SpellhancePriorityDB.autoAoeWindow = n; Print("ventana AUTO AOE: "..n.."s")
        else Print("uso: /spr autowindow 1-6") end
    elseif cmd == "sound" then
        if arg == "on" then SpellhancePriorityDB.sound = true
        elseif arg == "off" then SpellhancePriorityDB.sound = false
        else SpellhancePriorityDB.sound = not SpellhancePriorityDB.sound end
        Print("sonido MWx5: " .. (SpellhancePriorityDB.sound and "ON" or "OFF"))
    elseif cmd == "alert" then
        if arg == "on" then SpellhancePriorityDB.bigAlert = true
        elseif arg == "off" then SpellhancePriorityDB.bigAlert = false
        else SpellhancePriorityDB.bigAlert = not SpellhancePriorityDB.bigAlert end
        Print("alerta grande MWx5: " .. (SpellhancePriorityDB.bigAlert and "ON" or "OFF"))
    elseif cmd == "anim" then
        if arg == "on" then SpellhancePriorityDB.animation = true
        elseif arg == "off" then SpellhancePriorityDB.animation = false
        else SpellhancePriorityDB.animation = not SpellhancePriorityDB.animation end
        Print("animaciones: " .. (SpellhancePriorityDB.animation and "ON" or "OFF"))
    elseif cmd == "status" then
        if arg == "on" then SpellhancePriorityDB.showStatus = true
        elseif arg == "off" then SpellhancePriorityDB.showStatus = false
        else SpellhancePriorityDB.showStatus = not SpellhancePriorityDB.showStatus end
        ApplySettings(); Print("estado visible: " .. (SpellhancePriorityDB.showStatus and "ON" or "OFF"))
    elseif cmd == "size" then
        local n = tonumber(arg)
        if n and n >= 48 and n <= 120 then SpellhancePriorityDB.size = n; ApplySettings(); Print("tamaño principal: " .. n)
        else Print("uso: /spr size 48-120") end
    elseif cmd == "profile" then
        if arg == "save" then SaveProfileForTarget()
        elseif arg == "delete" or arg == "del" then DeleteProfileForTarget()
        elseif arg == "list" then ListProfiles()
        elseif arg == "on" then SpellhancePriorityDB.profilesEnabled = true; Print("perfiles: ON")
        elseif arg == "off" then SpellhancePriorityDB.profilesEnabled = false; Print("perfiles: OFF")
        else Print("uso: /spr profile save|delete|list|on|off") end
    elseif cmd == "debug" then
        DebugState()
    elseif cmd == "reset" then
        SpellhancePriorityDB = {}; CopyDefaults(); ApplySettings(); Print("configuración reiniciada.")
    else
        Print("v1.2: /spr auto|st|aoe, lock|unlock, fe on|off, smartfe on|off, corte on|off, trainer on|off, waste on|off, threshold N, nova on|off, burst on|off, autotargets 2-5, autowindow 1-6, sound on|off, alert on|off, anim on|off, status on|off, size 48-120, profile save|delete|list, debug, reset")
    end
    Recommend()
end

-- EVENTOS / ACTUALIZACION ----------------------------------------------------
SPR:RegisterEvent("PLAYER_LOGIN")
SPR:RegisterEvent("PLAYER_ENTERING_WORLD")
SPR:RegisterEvent("PLAYER_TARGET_CHANGED")
SPR:RegisterEvent("UNIT_AURA")
SPR:RegisterEvent("SPELL_UPDATE_COOLDOWN")
SPR:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
SPR:RegisterEvent("PLAYER_REGEN_DISABLED")
SPR:RegisterEvent("PLAYER_REGEN_ENABLED")
SPR:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
SPR:RegisterEvent("PLAYER_TOTEM_UPDATE")
SPR:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
SPR:RegisterEvent("UNIT_SPELLCAST_START")
SPR:RegisterEvent("UNIT_SPELLCAST_STOP")
SPR:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
SPR:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
SPR:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
SPR:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")

SPR:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        CopyDefaults()
        ApplySettings()
        Recommend()
        return
    end
    if not SpellhancePriorityDB then return end

    local arg1, arg2 = ...
    if event == "UNIT_AURA" and arg1 ~= "player" and arg1 ~= "target" then return end

    if event == "PLAYER_TARGET_CHANGED" then
        ApplyProfileForTarget()
    elseif event == "PLAYER_REGEN_DISABLED" then
        recentTargets = {}
        combatStart = GetTime()
        if SpellhancePriorityDB.trainer then ResetTrainer() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        FinishTrainer()
        recentTargets = {}
        combatStart = 0
        mw5Since, mwWasteWarned = nil, false
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        RecordSuccessfulCast(arg1, arg2)
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        RecordCombatLog(...)
    end

    Recommend()
end)

local elapsedSinceUpdate = 0
SPR:SetScript("OnUpdate", function(self, elapsed)
    if not SpellhancePriorityDB then return end

    elapsedSinceUpdate = elapsedSinceUpdate + elapsed
    metricsElapsed = metricsElapsed + elapsed
    if elapsedSinceUpdate >= 0.04 then
        elapsedSinceUpdate = 0
        Recommend()
    end
    if metricsElapsed >= 0.10 then
        local e = metricsElapsed
        metricsElapsed = 0
        UpdateTrainerMetrics(e)
    end

    local now = GetTime()
    local anim = SpellhancePriorityDB.animation
    local primary = SPR.slots[1]
    if primary and primary:IsShown() then
        local pulse = anim and (0.60 + 0.30 * math.sin(now * 5.5)) or 0.70
        primary.glow:SetAlpha(pulse)
        if bounceTimer > 0 and anim then
            bounceTimer = math.max(0, bounceTimer - elapsed)
            local p = bounceTimer / 0.20
            local extra = math.sin((1 - p) * math.pi) * 0.10
            primary:SetScale(1 + extra)
        else
            primary:SetScale(1)
        end
    end

    for i = 2, 5 do
        local slot = SPR.slots[i]
        if slot then
            slot.glow:SetAlpha(anim and (0.08 + 0.05 * math.sin(now * 3 + i)) or 0.08)
        end
    end

    if SPR.alert:IsShown() then
        SPR.alert.timer = SPR.alert.timer - elapsed
        if SPR.alert.timer <= 0 then
            SPR.alert:Hide()
        else
            local a = SPR.alert.timer < 0.30 and (SPR.alert.timer / 0.30) or 1
            SPR.alert:SetAlpha(a)
            local pulse = 0.55 + 0.45 * math.abs(math.sin(now * 9))
            SPR.alert.glow:SetAlpha(pulse)
            if anim then
                local scale = 1 + 0.04 * math.sin(now * 10)
                SPR.alert.icon:SetWidth(84 * scale)
                SPR.alert.icon:SetHeight(84 * scale)
            else
                SPR.alert.icon:SetWidth(84)
                SPR.alert.icon:SetHeight(84)
            end
        end
    end
end)
