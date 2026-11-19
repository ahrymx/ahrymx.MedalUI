-- Medalluin's words in the client's language (2026-11-19, a player's issue
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

ns.L = setmetatable({}, { __index = function(_, k) return k end })
