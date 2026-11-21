-- MedalUI's words in the client's language (2026-11-19, a player's issue
-- asking for Russian). Every string a player reads is looked up in ns.L by
-- its English, which is its own key (each file's `local Tr = ns.L`, as L is
-- already the strips' layout in many: Tr["Not on your bars"]): a language's file (locale\ruRU.lua,
-- loaded only on its client by the .toc) fills in what it words, and
-- anything it leaves out shows in English. A sentence built round numbers
-- or names is one format ("%d of %d"), so a language can order its words;
-- a count's word takes the game's plural escape, "|4spell:spells;", which
-- a Russian string writes with its three forms ("|4заклинание:заклинания:
-- заклинаний;"). Words the game has (HEALTH, MANA, LEVEL ...) are the
-- game's globals, not keys here. tools/locale.py checks a language's file
-- against the keys the code uses.
local _, ns = ...

-- A word that means two things in English but not in another language
-- carries its sense after ##, which English leaves off: Tr["Left##mouse"]
-- is "Left" here, "ЛКМ" in Russian, apart from a side's "Left".
ns.L = setmetatable({}, { __index = function(_, k) return (k:gsub("##.*$", "")) end })

-- A count's word where the count is not in the same text (the game's |4
-- reads the number before it in its string): ns.Plural(n, "|4point:points;")
-- picks the form for n by the client's language's rule, for every |4...;
-- in the text. English: one, other; Russian: one (1, 21, 31 ...), few (2-4,
-- 22-24 ...), many (the rest).
local RULE = {
    ruRU = function(n)
        local ten, hundred = n % 10, n % 100
        if ten == 1 and hundred ~= 11 then return 1 end
        if ten >= 2 and ten <= 4 and (hundred < 12 or hundred > 14) then return 2 end
        return 3
    end,
}
local function English(n) return n == 1 and 1 or 2 end
local rule = RULE[GetLocale and GetLocale() or "enUS"] or English

function ns.Plural(n, text)
    n = math.floor(math.abs(tonumber(n) or 0))
    local at = rule(n)
    return (text:gsub("|4([^;]*);", function(forms)
        local list = {}
        for f in (forms .. ":"):gmatch("([^:]*):") do list[#list + 1] = f end
        return list[math.min(at, #list)] or ""
    end))
end

-- Text in capitals, Cyrillic too (string.upper changes only A-Z): the
-- shell's titles and the headings that are drawn in capitals.
local CYRILLIC = { ["\209\145"] = "\208\129" }               -- ё Ё
for c = 0xB0, 0xBF do CYRILLIC["\208" .. string.char(c)] = "\208" .. string.char(c - 0x20) end   -- а-п
for c = 0x80, 0x8F do CYRILLIC["\209" .. string.char(c)] = "\208" .. string.char(c + 0x20) end   -- р-я

function ns.Upper(text)
    return (tostring(text or ""):upper():gsub("[\208\209][\128-\191]", CYRILLIC))
end
