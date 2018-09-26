local NAME = "ManaCostPerc"
ManaCostPerc = LibStub("AceAddon-3.0"):NewAddon(NAME, "AceHook-3.0" )

local ManaCostPerc, self = ManaCostPerc, ManaCostPerc

-- Locale
local L = LibStub("AceLocale-3.0"):GetLocale(NAME)

-- Some local functions/values
local _G = _G
local tonumber = tonumber
local math_ceil = math.ceil
local math_min = math.min
local table_concat = table.concat
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local BreakUpLargeNumbers = BreakUpLargeNumbers
local GetSpellPowerCost = GetSpellPowerCost
local PowerBarColor = PowerBarColor

local powerTypeMana = Enum.PowerType.Mana

local metadata = {
    title = GetAddOnMetadata(NAME, "Title"),
    notes = GetAddOnMetadata(NAME, "Notes")
}

local function filter(t, filterFunc)
    local res = {}
    for k, v in pairs(t) do
        if filterFunc(v, k, t) then
            if type(k) == "number" then
                tinsert(res, v)
            else
                res[k] = v
            end            
        end
    end
    return res
end

local function map(t, mapFunc)
    local res = {}
    for k, v in pairs(t) do
        res[k] = mapFunc(v, k, t)
    end
    return res
end

local function printThru(label, text)
    if not text then
        label, text = nil, label
    end
    print(label and label..": "..text or text)
    return text
end

local useHelpGroups = true

-- Default options
local defaults = {
    profile = {
        baseFormat = "[name][colName::] [cost] [costPM] [costPC]",
        perSecFormatNoBase = ("[name][colName:/%s:] [costSec] [costSecPM] [costSecPC]"):format(L["sec"]),
        perSecFormat = ("[name][colName::] [cost] [costPM] [costPC] + [costSec] [costSecPM] [costSecPC] /%s"):format(L["sec"]),
        colors = {
            colGlobal = { r = 1, g = 1, b = 1, a = 1 },
            colName = { r = 0, g = 0, b = 1, a = 1 },
            colCost = { r = 1, g = 1, b = 1, a = 1 },
            colPM = { r = 0, g = 0, b = 1, a = 1 },
            colPC = { r = 0.4, g = 0.4, b = 1, a = 1 },
            colSec = { r = 1, g = 1, b = 1, a = 1 },
            colSecPM = { r = 0, g = 0, b = 1, a = 1 },
            colSecPC = { r = 0.4, g = 0.4, b = 1, a = 1 },
        },
        useApiPercents = false,
        commify = true,
        showTenths = true,
        disableColors = false,
        colorAllCosts = false -- true to color power cost line in every skill tooltip into corresponding power color: use PowerBarColor[name]
    }
}

local db

local function getOptions()
    local options = {
        name = metadata.title,
        type = "group",
        guiInline = true,
        get = function(info)
            return db[info[#info]]
        end,
        set = function(info, value)
            db[info[#info]] = value
        end,
        args = {
            mpdesc = {
                name = metadata.notes,
                type = "description",
                order = 0,
            },
            patterns = {
                name = L["Patterns"],
                type = "group",
                order = 1,
                guiInline = true,
                width = "full",
                args = {
                    pdesc = {
                        type = "description",
                        order = 10,
                        name = L["Mana text patterns."]
                    },
                    baseFormat = {
                        name = L["Base Mana Cost Text Pattern"],
                        desc = L["Customise the mana cost text for spell with base cost only."],
                        type = "input",
                        order = 11,
                        width = "full"
                    },
                    perSecFormatNoBase = {
                        name = L["Per Time Mana Cost Text Pattern"],
                        desc = L["Customise the mana cost text for spell with per-time cost only."],
                        type = "input",
                        order = 12,
                        width = "full"
                    },
                    perSecFormat = {
                        name = L["Base + Per Time Mana Cost Text Pattern"],
                        desc = L["Customise the mana cost text for spell with base and per-time cost."],
                        type = "input",
                        order = 13,
                        width = "full"
                    },
                    commify = {
                        name = L["Break up big numbers"],
                        desc = L["Add thousand separators to numbers over 1000."],
                        type = "toggle",
                        order = 14,
                    },
                    showTenths = {
                        name = L["Show tenth of percents"],
                        desc = L["Show percent values with tenth parts."],
                        type = "toggle",
                        order = 15,
                    },
                    useApiPercents = {
                        name = L["Percents by Blizzard"],
                        desc = L["Obtain percent values returned by WoW API."],
                        type = "toggle",
                        order = 16,
                    }
                }
            },
            colors = {
                name = L["Colors"],
                type = "group",
                order = 2,
                width = "full",
                guiInline = true,
                get = function(info)
                    local col = db.colors[info[#info]]
                    return col.r, col.g, col.b, col.a or 1
                end,
                set = function(info, r, g, b, a)
                    local col = db.colors[info[#info]]
                    col.r, col.g, col.b, col.a = r, g, b, a
                end,
                args = {
                    cdesc = {
                        name = L["Mana text colors."],
                        type = "description",
                        order = 10
                    },
                    colGlobal = {
                        name = L["General"],
                        desc = L["Set the color of mana cost string."],
                        type = "color",
                        order = 20,
                        hasAlpha = true,
                    },
                    colName = {
                        name = L["Name"],
                        desc = L["Set the color of mana power name."],
                        type = "color",
                        order = 30,
                        hasAlpha = true,
                    },
                    colDummy = {
                        name = "",
                        type = "color",
                        order = 35,
                        hasAlpha = true,
                        disabled = true,
                        get = function() return 0, 0, 0, 0 end,
                        set = function() end
                    },
                    colCost = {
                        name = L["Cost"],
                        desc = L["Set the color of mana cost number."],
                        type = "color",
                        order = 40,
                        hasAlpha = true,
                    },
                    colPM = {
                        name = L["Cost max. percent"],
                        desc = L["Set the color of mana cost percent of maximum amount."],
                        type = "color",
                        order = 50,
                        hasAlpha = true,
                    },
                    colPC = {
                        name = L["Cost curr. percent"],
                        desc = L["Set the color of mana cost percent of current amount."],
                        type = "color",
                        order = 60,
                        hasAlpha = true,
                    },
                    colSec = {
                        name = L["Cost per time"],
                        desc = L["Set the color of mana cost per time number."],
                        type = "color",
                        order = 70,
                        hasAlpha = true,
                    },
                    colSecPM = {
                        name = L["Cost/time max. percent"],
                        desc = L["Set the color of mana cost per time percent of maximum amount."],
                        type = "color",
                        order = 80,
                        hasAlpha = true,
                    },
                    colSecPC = {
                        name = L["Cost/time curr. percent"],
                        desc = L["Set the color of mana cost per time percent of current amount."],
                        type = "color",
                        order = 90,
                        hasAlpha = true,
                    },
                    colorToggles = {
                        name = "",
                        type = "group",
                        guiInline = true,
                        order = 95,
                        get = function(info)
                            return db[info[#info]]
                        end,
                        set = function(info, value)
                            db[info[#info]] = value
                        end,
                        args = {
                            disableColors = {
                                name = L["Disable cost text coloring"],
                                desc = L["Ignore any color settings and display cost text in original color."],
                                type = "toggle",
                                order = 100,
                            },
                            colorAllCosts = {
                                name = L["Color other cost powers"],
                                desc = L["Color cost text of all spell with its power bar color."],
                                type = "toggle",
                                order = 110,
                                disabled = function() return db.disableColors end
                            },
                        }
                    }
                }
            }
        }
    }
    return options
end

local function createGroupItems(description, items, keyMap)
    local result = {
        text = {
            name = description,
            type = "description",
            order = 10,
            fontSize = "medium",
        },
    }

    for i, v in ipairs(items) do
        local k, vv = unpack(v)
        result[k] = {
            name = keyMap and keyMap(k, vv) or k,
            type = "group",
            order = (i + 1) * 10,
            width = "full",
            guiInline = true,
            args = {
                text = {
                    name = vv,
                    type = "description",
                    fontSize = "medium",
                },
            }
        }
    end

    return result
end

local function createGroupDescription(description, items, keyMap)
    for _, v in ipairs(items) do
        local k, vv = unpack(v)
        description = description .. ("\n\n\32\32\32\32%s\n%s"):format(keyMap and keyMap(k, vv) or k, vv)
    end
    
    return {
        text = {
            name = description,
            type = "description",
            order = 10,
            fontSize = "medium",
        },
    }
end

local function getHelp()
    local gen = useHelpGroups and createGroupItems or createGroupDescription
    return {
        name = L["Help on patterns"],
        type = "group",
        width = "full",
        childGroups = "tab",
        args = {
            text = {
                name = L["HELP.GENERIC"],
                type = "description",
                order = 1,
                fontSize = "medium",
            },
            patternGroup = {
                name = L["Content patterns"],
                type = "group",
                order = 2,
                width = "full",
                args = gen(
                    L["HELP.CONTENTPT"], {
                        { "name", L["Name of the Power Type: \"Mana\"."] },
                        { "cost", L["Number for spell base absolute power cost."] },
                        { "costPM", L["Spell base cost percentage of maximum player mana amount."] },
                        { "costPC", L["Spell base cost percentage of current player mana amount."] },
                        { "costSec", L["Number for spell absolute power cost per second (usually for channeling spells)."] },
                        { "costSecPM", L["Spell cost per second percentage of maximum player mana amount."] },
                        { "costSecPC", L["Spell cost per second percentage of current player mana amount."] },
                    },
                    function(key)
                        return "|cffffff00[" .. key .. "]|r"
                    end                    
                )
            },
            patternColGroup = {
                name = L["Text color patterns"],
                type = "group",
                order = 3,
                width = "full",
                args = gen(--createGroupItems(--createGroupDescription(
                    L["HELP.CONTENTCOL"], {
                        -- { "colGlobal", L_[""] }, -- Do not need
                        { "colName", L["Set text color to color of power type name color."] },
                        { "colCost", L["Set text color to color of spell base cost absolute number."] },
                        { "colPM", L["Set text color to color of spell cost in percent of maximum mana."] },
                        { "colPC", L["Set text color to color of spell cost in percent of current mana."] },
                        { "colSec", L["Set text color to color of spell absolute power cost per second."] },
                        { "colSecPM", L["Set text color to color of spell cost per second in percent of maximum mana."] },
                        { "colSecPC", L["Set text color to color of spell cost per second in percent of current mana."] },
                    },
                    function(key)
                        return ("|cffffff00[%s:...]|r"):format(key)
                    end
                    
                    --[[text = {
                        type = "description",
                        name = L["HELP.CONTENTCOL"],
                        order = 1,
                        fontSize = "medium",
                    },]]
                )
            },
        }
    }
end

function ManaCostPerc:OnInitialize()
    -- Grab our DB and fill in the 'db' variable
    self.db = LibStub("AceDB-3.0"):New(NAME .. "DB", defaults, "Default")
    db = self.db.profile

    -- Register our options
    local ACReg, ACDialog = LibStub("AceConfigRegistry-3.0"), LibStub("AceConfigDialog-3.0")
    local helpName = NAME .. "-Help"
    ACReg:RegisterOptionsTable(NAME, getOptions)
    ACReg:RegisterOptionsTable(helpName, getHelp)
    ACDialog:AddToBlizOptions(NAME, metadata.title)
    ACDialog:AddToBlizOptions(helpName, L["Help on patterns"], metadata.title)
end

function ManaCostPerc:OnEnable()
    self:SecureHookScript(GameTooltip, "OnTooltipSetSpell", "ProcessOnShow")
end

local function findFirst(t, filterFunc)
    for k, v in pairs(t) do
        if filterFunc(v, k, t) then
            return k, v
        end
    end
    return nil
end

local function getPercent(num, whole)
    return whole ~= 0 and (num / whole) * 100 or 0
end

local function getSpellCosts(id)
    if type(id) == "number" and id > 0 then
        local costs = filter(
                            GetSpellPowerCost(id),
                            function (v)
                                return v.requiredAuraID == 0 or v.hasRequiredAura
                            end
                        )
        local _, manaCost = findFirst(
                                costs,
                                function(v)
                                    return v.type == powerTypeMana
                                end
                            )
        if manaCost then -- assume spells to cost only mana
            local currMana = UnitPower("player", powerTypeMana)
            local totalMana = UnitPowerMax("player", powerTypeMana)

            return {
                name = _G[manaCost.name],
                cost = manaCost.cost,
                costPerSec = manaCost.costPerSec,
                costPercentMax = db.useApiPercents
                                    and manaCost.costPercent
                                    or getPercent(manaCost.cost, totalMana),
                costPercentCurr = getPercent(manaCost.cost, currMana),
                costPerSecPercentMax = getPercent(manaCost.costPerSec, totalMana),
                costPerSecPercentCurr = getPercent(manaCost.costPerSec, currMana)
            }
        else
            return map(
                    -- Skip zero costs (due to some aura(s)), for they do not have costs text in tooltip
                    filter(costs, function(v) return v.cost > 0 or v.costPerSec > 0 end),
                    function(v) return v.name end
                )
        end
    end
    return nil
end

local function formatPercent(num)
    local fmt
    if db.showTenths then
        fmt = "%.1f%%"
        num = math_ceil(10 * num) / 10
    else
        fmt = "%d%%"
        num = math_ceil(num)
    end
    return fmt:format(num) .. "%" -- double trailing percent for using result in string.gsub()
end

local function commify(num)
    if db.commify and type(num) == "number" and num >= 1000 then
        return BreakUpLargeNumbers(num)
    end
    return tostring(num)
end

local function rgbaPercToHex(colorTable)
    local r, g, b, a = colorTable.r, colorTable.g, colorTable.b, colorTable.a
	r = r and r <= 1 and r >= 0 and r or 0
	g = g and g <= 1 and g >= 0 and g or 0
    b = b and b <= 1 and b >= 0 and b or 0
    a = a and a <= 1 and a >= 0 and a or 1
	return ("%02x%02x%02x%02x"):format(a * 255, r * 255, g * 255, b * 255)
end

local function wrapInColorTag(text, color)
    if not db.disableColors and color and text and #text > 0 then
        return ("|c%s%s|r"):format(rgbaPercToHex(color), text)
    end
    return text
end

local function replaceColorPlaceholder(colorKey, text)    
    local color = db.colors[colorKey]
    return color and wrapInColorTag(text, color) or text
  end

local function getManaCostText(costs)
    if costs then
        local result
        local cols = db.colors

        if costs.cost > 0 and costs.costPerSec > 0 then
            result = db.perSecFormat
        elseif costs.cost > 0 then
            result = db.baseFormat
        else
            result = db.perSecFormatNoBase
        end

        result = result:gsub("%[name%]", wrapInColorTag(costs.name, cols.colName))
        result = result:gsub("%[cost%]", wrapInColorTag(commify(costs.cost), cols.colCost))
        result = result:gsub("%[costPM%]", wrapInColorTag(formatPercent(costs.costPercentMax), cols.colPM))
        result = result:gsub("%[costPC%]", wrapInColorTag(formatPercent(costs.costPercentCurr), cols.colPC))
        result = result:gsub("%[costSec%]", wrapInColorTag(commify(costs.costPerSec), cols.colSec))
        result = result:gsub("%[costSecPM%]", wrapInColorTag(formatPercent(costs.costPerSecPercentMax), cols.colSecPM))
        result = result:gsub("%[costSecPC%]", wrapInColorTag(formatPercent(costs.costPerSecPercentCurr), cols.colSecPC))
        -- replace [colorKey:text] with text wrapped in db.colors[colorKey] colored tag
        result = result:gsub("%[(%a+):([^%]]+)%]", replaceColorPlaceholder)

        return wrapInColorTag(result, cols.colGlobal)
    end
    return nil
end

function ManaCostPerc:ProcessOnShow(tt, ...)
    local textLine = _G[tt:GetName() .. "TextLeft2"]
    local _, id = tt:GetSpell()
    local costs = getSpellCosts(id)
    local text = nil

    if not costs then
        -- Do nothing
    elseif costs.name then
        text = getManaCostText(costs)
    elseif not db.disableColors and db.colorAllCosts and #costs > 0 then
        local parts, i = {}, 1
        for m in textLine:GetText():gmatch("[^\n]+") do
            parts[i] = wrapInColorTag(m, PowerBarColor[costs[math_min(i, #costs)]])
            i = i + 1
        end
        text = table_concat(parts, "\n")
    end    

    if text then
        textLine:SetText(text)
    end    
end
