-- entry point for all lua code of the pack
-- more info on the lua API: https://github.com/black-sliver/PopTracker/blob/master/doc/PACKS.md#lua-interface
ENABLE_DEBUG_LOG = true
-- get current variant
local variant = Tracker.ActiveVariantUID
-- check variant info
IS_ITEMS_ONLY = variant:find("itemsonly")

print("-- Example Tracker --")
print("Loaded variant: ", variant)
if ENABLE_DEBUG_LOG then
	print("Debug logging is enabled!")
end

-- Utility Script for helper functions etc.
ScriptHost:LoadScript("scripts/utils.lua")

-- Logic
ScriptHost:LoadScript("scripts/logic/logic.lua")

-- Custom Items
ScriptHost:LoadScript("scripts/custom_items/class.lua")
ScriptHost:LoadScript("scripts/custom_items/progressiveTogglePlus.lua")
ScriptHost:LoadScript("scripts/custom_items/progressiveTogglePlusWrapper.lua")

-- Items
Tracker:AddItems("items/items.json")

if not IS_ITEMS_ONLY then -- <--- use variant info to optimize loading
-- Maps
	Tracker:AddMaps("maps/maps.json")
	-- Locations
	Tracker:AddLocations("locations/locations.json")
end

-- Layout
Tracker:AddLayouts("layouts/clankitems.json")
Tracker:AddLayouts("layouts/ratchetitems.json")
Tracker:AddLayouts("layouts/planets.json")
Tracker:AddLayouts("layouts/extra.json")
Tracker:AddLayouts("layouts/mods.json")
Tracker:AddLayouts("layouts/tracker.json")
Tracker:AddLayouts("layouts/ratchet.json")
Tracker:AddLayouts("layouts/clank.json")
Tracker:AddLayouts("layouts/gadge.json")
Tracker:AddLayouts("layouts/qwark.json")
Tracker:AddLayouts("layouts/special.json")
Tracker:AddLayouts("layouts/overview.json")
Tracker:AddLayouts("layouts/settings.json")
Tracker:AddLayouts("layouts/broadcast.json")

print("------------------------DEBUG-----------------------")
-- Table of All Planets

-- AutoTracking for Poptracker
if PopVersion and PopVersion >= "0.18.0" then
	ScriptHost:LoadScript("scripts/autotracking.lua")
end
