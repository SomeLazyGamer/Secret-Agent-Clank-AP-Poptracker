-- this is an example/default implementation for AP autotracking
-- it will use the mappings defined in item_mapping.lua and location_mapping.lua to track items and locations via their ids
-- it will also keep track of the current index of on_item messages in CUR_INDEX
-- addition it will keep track of what items are local items and which one are remote using the globals LOCAL_ITEMS and GLOBAL_ITEMS
-- this is useful since remote items will not reset but local items might
-- if you run into issues when touching A LOT of items/locations here, see the comment about Tracker.AllowDeferredLogicUpdate in autotracking.lua
ScriptHost:LoadScript("scripts/autotracking/item_mapping.lua")
ScriptHost:LoadScript("scripts/autotracking/location_mapping.lua")
-- used for hint tracking to quickly map hint status to a value from the Highlight enum
HINT_STATUS_MAPPING = {}
if Highlight then
	HINT_STATUS_MAPPING = {
		[20] = Highlight.Avoid,
		[40] = Highlight.None,
		[10] = Highlight.NoPriority,
		[0] = Highlight.Unspecified,
		[30] = Highlight.Priority,
	}
end

CUR_INDEX = -1
SLOT_DATA = nil
LOCAL_ITEMS = {}
GLOBAL_ITEMS = {}

-- gets the data storage key for hints for the current player
-- returns nil when not connected to AP
function getHintDataStorageKey()
	if AutoTracker:GetConnectionState("AP") ~= 3 or Archipelago.TeamNumber == nil or Archipelago.TeamNumber == -1 or Archipelago.PlayerNumber == nil or Archipelago.PlayerNumber == -1 then
		if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print("Tried to call getHintDataStorageKey while not connect to AP server")
		end
		return nil
	end
	return string.format("_read_hints_%s_%s", Archipelago.TeamNumber, Archipelago.PlayerNumber)
end

-- resets an item to its initial state
function resetItem(item_code, item_type)
	local obj = Tracker:FindObjectForCode(item_code)
	if obj then
		item_type = item_type or obj.Type
		if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print(string.format("resetItem: resetting item %s of type %s", item_code, item_type))
		end
		if item_type == "toggle" or item_type == "toggle_badged" then
			obj.Active = false
		elseif item_type == "progressive" or item_type == "progressive_toggle" then
			obj.CurrentStage = 0
			obj.Active = false
		elseif item_type == "consumable" then
			obj.AcquiredCount = 0
		elseif item_type == "custom" then
		-- your code for your custom lua items goes here
		elseif item_type == "static" and AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print(string.format("resetItem: tried to reset static item %s", item_code))
		elseif item_type == "composite_toggle" and AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print(string.format(
				"resetItem: tried to reset composite_toggle item %s but composite_toggle cannot be accessed via lua." ..
				"Please use the respective left/right toggle item codes instead.", item_code))
		elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print(string.format("resetItem: unknown item type %s for code %s", item_type, item_code))
		end
	elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
		print(string.format("resetItem: could not find item object for code %s", item_code))
	end
end

-- advances the state of an item
function incrementItem(item_code, item_type, multiplier)
	local obj = Tracker:FindObjectForCode(item_code)
	if obj then
		item_type = item_type or obj.Type
		if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print(string.format("incrementItem: code: %s, type %s", item_code, item_type))
		end
		if item_type == "toggle" or item_type == "toggle_badged" then
			obj.Active = true
		elseif item_type == "progressive" or item_type == "progressive_toggle" then
			if obj.Active then
				obj.CurrentStage = obj.CurrentStage + 1
			else
				obj.Active = true
			end
		elseif item_type == "consumable" then
			obj.AcquiredCount = obj.AcquiredCount + obj.Increment * multiplier
		elseif item_type == "custom" then
		-- your code for your custom lua items goes here
		elseif item_type == "static" and AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print(string.format("incrementItem: tried to increment static item %s", item_code))
		elseif item_type == "composite_toggle" and AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print(string.format(
				"incrementItem: tried to increment composite_toggle item %s but composite_toggle cannot be access via lua." ..
				"Please use the respective left/right toggle item codes instead.", item_code))
		elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print(string.format("incrementItem: unknown item type %s for code %s", item_type, item_code))
		end
	elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
		print(string.format("incrementItem: could not find object for code %s", item_code))
	end
end

-- apply everything needed from slot_data, called from onClear
function apply_slot_data(slot_data)
-- put any code here that slot_data should affect (toggling setting items for example)
end

-- called right after an AP slot is connected
function onClear(slot_data)
-- use bulk update to pause logic updates until we are done resetting all items/locations
	Tracker.BulkUpdate = true
	if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
		print(string.format("called onClear, slot_data:\n%s", dump_table(slot_data)))
	end
	CUR_INDEX = -1
	-- reset locations
	for _, mapping_entry in pairs(LOCATION_MAPPING) do
		for _, location_table in ipairs(mapping_entry) do
			if location_table then
				local location_code = location_table[1]
				if location_code then
					if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
						print(string.format("onClear: clearing location %s", location_code))
					end
					if location_code:sub(1, 1) == "@" then
						local obj = Tracker:FindObjectForCode(location_code)
						if obj then
							obj.AvailableChestCount = obj.ChestCount
							if obj.Highlight then
								obj.Highlight = Highlight.None
							end
						elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
							print(string.format("onClear: could not find location object for code %s", location_code))
						end
					else
					-- reset hosted item
						local item_type = location_table[2]
						resetItem(location_code, item_type)
					end
				elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
					print(string.format("onClear: skipping location_table with no location_code"))
				end
			elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
				print(string.format("onClear: skipping empty location_table"))
			end
		end
	end
	-- reset items
	for _, mapping_entry in pairs(ITEM_MAPPING) do
		for _, item_table in ipairs(mapping_entry) do
			if item_table then
				local item_code = item_table[1]
				local item_type = item_table[2]
				if item_code then
					resetItem(item_code, item_type)
				elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
					print(string.format("onClear: skipping item_table with no item_code"))
				end
			elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
				print(string.format("onClear: skipping empty item_table"))
			end
		end
	end

    if slot_data['goal'] then
        local obj = Tracker:FindObjectForCode("goal")
        local stage = slot_data['goal']
        if obj then
            obj.CurrentStage = stage
        end
    end
	if slot_data["pick_and_mix_goals"] then
		local pick = slot_data["pick_and_mix_goals"]
		for position, value in pairs(pick) do
    		if value == "defeat_klunk" then
        local obj = Tracker:FindObjectForCode("PickKlunk")
        		obj.CurrentStage = 1
    		elseif value == "qwark_opera" then
        local obj = Tracker:FindObjectForCode("PickOpera")
        		obj.CurrentStage = 1
    		elseif value == "all_gadgetbots" then
        local obj = Tracker:FindObjectForCode("PickGadge")
        		obj.CurrentStage = 1
    		elseif value == "ratchet_prison_escape" then
        local obj = Tracker:FindObjectForCode("PickRatchet")
        		obj.CurrentStage = 1
    		elseif value == "these_are_the_real_adventures_of_captain_qwark" then
        local obj = Tracker:FindObjectForCode("PickQwark")
        		obj.CurrentStage = 1
    		elseif value == "alien_codes" then
        local obj = Tracker:FindObjectForCode("PickAlien")
        		obj.CurrentStage = 1
    		elseif value == "chalice_of_power" then
        local obj = Tracker:FindObjectForCode("PickChalice")
        		obj.CurrentStage = 1
    		end
		end
	end
    if slot_data['infobots'] then
        local obj = Tracker:FindObjectForCode("Info")
        local stage = slot_data['infobots']
        if obj then
            obj.CurrentStage = stage
        end
    end
    if slot_data['operatives']["Clank"] then
        local obj = Tracker:FindObjectForCode("ClankChecks")
        local stage = slot_data['operatives']["Clank"]
        if obj then
            obj.CurrentStage = stage
        end
    end
    if slot_data['operatives']["Ratchet"] then
        local obj = Tracker:FindObjectForCode("RatchetChecks")
        local stage = slot_data['operatives']["Ratchet"]
        if obj then
            obj.CurrentStage = stage
        end
    end
    if slot_data['operatives']["Gadgetbots"] then
        local obj = Tracker:FindObjectForCode("GadgeChecks")
        local stage = slot_data['operatives']["Gadgetbots"]
        if obj then
            obj.CurrentStage = stage
        end
    end
    if slot_data['operatives']["Qwark"] then
        local obj = Tracker:FindObjectForCode("QwarkChecks")
        local stage = slot_data['operatives']["Qwark"]
        if obj then
            obj.CurrentStage = stage
        end
    end
    if slot_data['operatives']["Special Missions"] then
        local obj = Tracker:FindObjectForCode("SpecialChecks")
        local stage = slot_data['operatives']["Special Missions"]
        if obj then
            obj.CurrentStage = stage
        end
    end
    if slot_data['ng_plus'] then
        local obj = Tracker:FindObjectForCode("NGP")
        local stage = slot_data['ng_plus']
        if obj then
            obj.CurrentStage = stage
        end
    end
    if slot_data['progressive_challenge_mode'] == true then
        local obj = Tracker:FindObjectForCode("ProgChall")
        if obj then
            obj.CurrentStage = 1
        end
    end
    if slot_data['progressive_weapons'] then
        local obj = Tracker:FindObjectForCode("ProgWeap")
        local stage = slot_data['progressive_weapons']
        if obj then
            obj.CurrentStage = stage
        end
    end
    if slot_data['progressive_wrench'] then
        local obj = Tracker:FindObjectForCode("ProgWrench")
        local stage = slot_data['progressive_wrench']
        if obj then
            obj.CurrentStage = stage
        end
    end
    if slot_data['all_missions'] then
        local obj = Tracker:FindObjectForCode("Missions")
        local stage = slot_data['all_missions']
        if obj then
            obj.CurrentStage = stage
        end
    end
    if slot_data['all_cutscenes'] == true then
        local obj = Tracker:FindObjectForCode("Cutscenes")
        if obj then
            obj.CurrentStage = 1
        end
    end
    if slot_data['skill_points'] then
        local obj = Tracker:FindObjectForCode("Skills")
        local stage = slot_data['skill_points']
        if obj then
            obj.CurrentStage = stage
        end
    end
    if slot_data['random_skill_points'] == true then
        local obj = Tracker:FindObjectForCode("RandomSkills")
        if obj then
            obj.CurrentStage = 1
        end
    end
    if slot_data['weapon_level_checks'] then
        local obj = Tracker:FindObjectForCode("WeapLVL")
        local stage = slot_data['weapon_level_checks']
        if obj then
            obj.CurrentStage = stage
        end
    end
    if slot_data['nanotech_checks'] == true then
        local obj = Tracker:FindObjectForCode("ClankNano")
        if obj then
            obj.CurrentStage = 1
        end
    end
    if slot_data['ratchet_nanotech_checks'] == true then
        local obj = Tracker:FindObjectForCode("RatchetNano")
        if obj then
            obj.CurrentStage = 1
        end
    end
    if slot_data['stealth_takedown_checks'] then
        local obj = Tracker:FindObjectForCode("StealthChecks")
        obj.AcquiredCount = (slot_data['stealth_takedown_checks'])
    end 
    if slot_data['keycards_and_alien_codes'] == true then
        local obj = Tracker:FindObjectForCode("KeyCode")
        if obj then
            obj.CurrentStage = 1
        end
    end
	if slot_data["selected_skill_points"] then
		local pick = slot_data["selected_skill_points"]
		for position, value in pairs(pick) do
    		if value == "Boltaire (Clank) - Boltaire Museum: Skill Point: Furious Fists of Fury" then
        local obj = Tracker:FindObjectForCode("SP1")
        		obj.CurrentStage = 1
    		elseif value == "Boltaire (Clank) - Boltaire Museum: Skill Point: Silent Night" then
        local obj = Tracker:FindObjectForCode("SP2")
        		obj.CurrentStage = 1
    		elseif value == "Boltaire (Special Missions) - Boltaire Gem Wing: Skill Point: Pyrrhic Victory" then
        local obj = Tracker:FindObjectForCode("SP3")
        		obj.CurrentStage = 1
    		elseif value == "Boltaire (Special Missions) - Boltaire Gem Wing: Skill Point: Triple Platinum Record" then
        local obj = Tracker:FindObjectForCode("SP4")
        		obj.CurrentStage = 1
    		elseif value == "Prison Planet (Ratchet) - Max-Security Cells: Skill Point: Stainless Steel" then
        local obj = Tracker:FindObjectForCode("SP5")
        		obj.CurrentStage = 1
    		elseif value == "Prison Planet (Ratchet) - Max-Security Cells: Skill Point: Playing With Fire" then
        local obj = Tracker:FindObjectForCode("SP6")
        		obj.CurrentStage = 1
    		elseif value == "Asyanica (Gadgetbots) - Rooftop Deathtrap: Skill Point: Speed Demon" then
        local obj = Tracker:FindObjectForCode("SP7")
        		obj.CurrentStage = 1
    		elseif value == "Asyanica (Gadgetbots) - Rooftop Deathtrap: Skill Point: Perfect Chrome Finish" then
        local obj = Tracker:FindObjectForCode("SP8")
        		obj.CurrentStage = 1
    		elseif value == "Asyanica (Clank) - Asyanica Rooftops: Skill Point: Robot Finds Ninja" then
        local obj = Tracker:FindObjectForCode("SP9")
        		obj.CurrentStage = 1
    		elseif value == "Asyanica (Clank) - Asyanica Rooftops: Skill Point: Black Tie Affair" then
        local obj = Tracker:FindObjectForCode("SP10")
        		obj.CurrentStage = 1
    		elseif value == "Asyanica (Clank) - Asyanica Rooftops: Skill Point: Like The Wind" then
        local obj = Tracker:FindObjectForCode("SP11")
        		obj.CurrentStage = 1
    		elseif value == "Asyanica (Qwark) - Larger Than Life: Skill Point: Inverse Ninja Law" then
        local obj = Tracker:FindObjectForCode("SP12")
        		obj.CurrentStage = 1
    		elseif value == "Asyanica (Qwark) - Larger Than Life: Skill Point: Blaster Overload" then
        local obj = Tracker:FindObjectForCode("SP13")
        		obj.CurrentStage = 1
    		elseif value == "Glaciara (Special Missions) - Countess's Villa: Skill Point: Perfect Tango" then
        local obj = Tracker:FindObjectForCode("SP14")
        		obj.CurrentStage = 1
    		elseif value == "Glaciara (Special Missions) - Glaciara, Ski Slopes: Skill Point: Black Diamond" then
        local obj = Tracker:FindObjectForCode("SP15")
        		obj.CurrentStage = 1
    		elseif value == "Glaciara (Special Missions) - Glaciara, Ski Slopes: Skill Point: Smooth Moves" then
        local obj = Tracker:FindObjectForCode("SP16")
        		obj.CurrentStage = 1
    		elseif value == "Glaciara (Special Missions) - Glaciara, Ski Slopes: Skill Point: Ringleader" then
        local obj = Tracker:FindObjectForCode("SP17")
        		obj.CurrentStage = 1
    		elseif value == "Prison Planet (Ratchet) - The Mess Hall: Skill Point: Empty The Warrens" then
        local obj = Tracker:FindObjectForCode("SP18")
        		obj.CurrentStage = 1
    		elseif value == "Prison Planet (Ratchet) - The Mess Hall: Skill Point: Antaeus" then
        local obj = Tracker:FindObjectForCode("SP19")
        		obj.CurrentStage = 1
    		elseif value == "Rionosis (Clank) - Azcotal Alley: Skill Point: Master of Disguise" then
        local obj = Tracker:FindObjectForCode("SP20")
        		obj.CurrentStage = 1
    		elseif value == "Rionosis (Clank) - Azcotal Alley: Skill Point: Trash Talk" then
        local obj = Tracker:FindObjectForCode("SP21")
        		obj.CurrentStage = 1
    		elseif value == "Rionosis (Clank) - Azcotal Alley: Skill Point: Deadly Hands" then
        local obj = Tracker:FindObjectForCode("SP22")
        		obj.CurrentStage = 1
    		elseif value == "Rionosis (Clank) - Gondola Ascent: Skill Point: Steel Rain" then
        local obj = Tracker:FindObjectForCode("SP23")
        		obj.CurrentStage = 1
    		elseif value == "Rionosis (Qwark) - Suck and Jive: Skill Point: 52 Card Pickup" then
        local obj = Tracker:FindObjectForCode("SP24")
        		obj.CurrentStage = 1
    		elseif value == "Rionosis (Qwark) - Suck and Jive: Skill Point: Dress For Success" then
        local obj = Tracker:FindObjectForCode("SP25")
        		obj.CurrentStage = 1
    		elseif value == "The Paradis Des Tricheurs Casino (Clank) - High-Rollers Casino: Skill Point: Beat The House" then
        local obj = Tracker:FindObjectForCode("SP26")
        		obj.CurrentStage = 1
    		elseif value == "Prison Planet (Ratchet) - The Exercise Yard: Skill Point: Indian Burn" then
        local obj = Tracker:FindObjectForCode("SP27")
        		obj.CurrentStage = 1
    		elseif value == "Prison Planet (Ratchet) - The Exercise Yard: Skill Point: The Law Can't Touch Me" then
        local obj = Tracker:FindObjectForCode("SP28")
        		obj.CurrentStage = 1
    		elseif value == "The Paradis Des Tricheurs Casino (Special Missions) - High Stakes Room: Skill Point: Lucky Sevens" then
        local obj = Tracker:FindObjectForCode("SP29")
        		obj.CurrentStage = 1
    		elseif value == "The Paradis Des Tricheurs Casino (Special Missions) - High Stakes Room: Skill Point: A Gadgebot Stands Alone" then
        local obj = Tracker:FindObjectForCode("SP30")
        		obj.CurrentStage = 1
    		elseif value == "Venantonio (Clank) - Venantonio Labs: Skill Point: All Slime Must Burn" then
        local obj = Tracker:FindObjectForCode("SP31")
        		obj.CurrentStage = 1
    		elseif value == "Venantonio (Clank) - Venantonio Labs: Skill Point: Ramming Speed!" then
        local obj = Tracker:FindObjectForCode("SP32")
        		obj.CurrentStage = 1
    		elseif value == "Venantonio (Special Missions) - Venantonio Canals: Skill Point: Evasive Maneuvers" then
        local obj = Tracker:FindObjectForCode("SP33")
        		obj.CurrentStage = 1
    		elseif value == "Venantonio (Special Missions) - Venantonio Canals: Skill Point: Deep Six" then
        local obj = Tracker:FindObjectForCode("SP34")
        		obj.CurrentStage = 1
    		elseif value == "Venantonio (Special Missions) - Venantonio Canals: Skill Point: Wake Of Destruction" then
        local obj = Tracker:FindObjectForCode("SP35")
        		obj.CurrentStage = 1
    		elseif value == "Venantonio (Special Missions) - Venantonio Canals: Skill Point: Ringmaster" then
        local obj = Tracker:FindObjectForCode("SP36")
        		obj.CurrentStage = 1
    		elseif value == "Venantonio (Qwark) - Madam Butterqwark: Skill Point: Twinkle Toes" then
        local obj = Tracker:FindObjectForCode("SP37")
        		obj.CurrentStage = 1
    		elseif value == "Venantonio (Qwark) - Madam Butterqwark: Skill Point: Magnum Opus" then
        local obj = Tracker:FindObjectForCode("SP38")
        		obj.CurrentStage = 1
    		elseif value == "Venantonio (Qwark) - Madam Butterqwark: Skill Point: Sold Out" then
        local obj = Tracker:FindObjectForCode("SP39")
        		obj.CurrentStage = 1
    		elseif value == "Fort Sprocket (Clank) - Galactic Bolt Reserve: Skill Point: With Interest" then
        local obj = Tracker:FindObjectForCode("SP40")
        		obj.CurrentStage = 1
    		elseif value == "Fort Sprocket (Clank) - Galactic Bolt Reserve: Skill Point: Androids In Disguise" then
        local obj = Tracker:FindObjectForCode("SP41")
        		obj.CurrentStage = 1
    		elseif value == "Fort Sprocket (Gadgetbots) - Inside the A-Eye: Skill Point: Vault Vault" then
        local obj = Tracker:FindObjectForCode("SP42")
        		obj.CurrentStage = 1
    		elseif value == "Fort Sprocket (Gadgetbots) - Inside the A-Eye: Skill Point: El Día de los Muertos" then
        local obj = Tracker:FindObjectForCode("SP43")
        		obj.CurrentStage = 1
    		elseif value == "Prison Planet (Ratchet) - The Showers: Skill Point: Ruba-Dub Club" then
        local obj = Tracker:FindObjectForCode("SP44")
        		obj.CurrentStage = 1
    		elseif value == "Prison Planet (Ratchet) - The Showers: Skill Point: Modesty" then
        local obj = Tracker:FindObjectForCode("SP45")
        		obj.CurrentStage = 1
    		elseif value == "Spaceship Graveyard (Clank) - Spaceship Graveyard: Skill Point: It's A Delicacy Somewhere" then
        local obj = Tracker:FindObjectForCode("SP46")
        		obj.CurrentStage = 1
    		elseif value == "Spaceship Graveyard (Clank) - Spaceship Graveyard: Skill Point: Revenant" then
        local obj = Tracker:FindObjectForCode("SP47")
        		obj.CurrentStage = 1
    		elseif value == "Spaceship Graveyard (Qwark) - Saint Qwark: Skill Point: Punchy" then
        local obj = Tracker:FindObjectForCode("SP48")
        		obj.CurrentStage = 1
    		elseif value == "Spaceship Graveyard (Qwark) - Saint Qwark: Skill Point: Sour Victory" then
        local obj = Tracker:FindObjectForCode("SP49")
        		obj.CurrentStage = 1
    		elseif value == "Spaceship Graveyard (Special Missions) - The Quasar Fields: Skill Point: Min Maxing" then
        local obj = Tracker:FindObjectForCode("SP50")
        		obj.CurrentStage = 1
    		elseif value == "Spaceship Graveyard (Special Missions) - The Quasar Fields: Skill Point: I Kill the Rock" then
        local obj = Tracker:FindObjectForCode("SP51")
        		obj.CurrentStage = 1
    		elseif value == "Prison Planet (Ratchet) - Prison Breakout!: Skill Point: Whip It Good" then
        local obj = Tracker:FindObjectForCode("SP52")
        		obj.CurrentStage = 1
    		elseif value == "Prison Planet (Ratchet) - Prison Breakout!: Skill Point: Hanging Judge" then
        local obj = Tracker:FindObjectForCode("SP53")
        		obj.CurrentStage = 1
    		elseif value == "Hydrano (Special Missions) - Dam's Edge, Hydrano: Skill Point: Yeeee Haaaaaw!" then
        local obj = Tracker:FindObjectForCode("SP54")
        		obj.CurrentStage = 1
    		elseif value == "Hydrano (Special Missions) - Dam's Edge, Hydrano: Skill Point: Offensive Driver" then
        local obj = Tracker:FindObjectForCode("SP55")
        		obj.CurrentStage = 1
    		elseif value == "Hydrano (Special Missions) - Dam's Edge, Hydrano: Skill Point: Slippery Slope" then
        local obj = Tracker:FindObjectForCode("SP56")
        		obj.CurrentStage = 1
    		elseif value == "Hydrano (Special Missions) - Dam's Edge, Hydrano: Skill Point: Ring Around the Rosie" then
        local obj = Tracker:FindObjectForCode("SP57")
        		obj.CurrentStage = 1
    		elseif value == "Hydrano (Qwark) - A Fiction Full Of Dollars: Skill Point: He Cleans pools, Too!" then
        local obj = Tracker:FindObjectForCode("SP58")
        		obj.CurrentStage = 1
    		elseif value == "Hydrano (Qwark) - A Fiction Full Of Dollars: Skill Point: Perfect Mirror" then
        local obj = Tracker:FindObjectForCode("SP59")
        		obj.CurrentStage = 1
    		elseif value == "Hydrano (Gadgetbots) - Bulkhead Lock: Skill Point: Cerial Decoder Rung" then
        local obj = Tracker:FindObjectForCode("SP60")
        		obj.CurrentStage = 1
    		elseif value == "Hydrano (Clank) - Underwater Bunker: Skill Point: I33t h4XX0r" then
        local obj = Tracker:FindObjectForCode("SP61")
        		obj.CurrentStage = 1
    		elseif value == "Hydrano (Clank) - Underwater Bunker: Skill Point: Rust Proof" then
        local obj = Tracker:FindObjectForCode("SP62")
        		obj.CurrentStage = 1
    		elseif value == "Hydrano (Clank) - Underwater Bunker: Skill Point: I'm not There" then
        local obj = Tracker:FindObjectForCode("SP63")
        		obj.CurrentStage = 1
    		elseif value == "Hydrano (Clank) - Klunk's Lair: Skill Point: Turn The Tables" then
        local obj = Tracker:FindObjectForCode("SP64")
        		obj.CurrentStage = 1
    		elseif value == "Hydrano (Clank) - Klunk's Lair: Skill Point: A Pretty Good Likeness" then
        local obj = Tracker:FindObjectForCode("SP65")
        		obj.CurrentStage = 1
    		end
		end
	end

	apply_slot_data(slot_data)
	LOCAL_ITEMS = {}
	GLOBAL_ITEMS = {}
	-- manually run snes interface functions after onClear in case we need to update them (i.e. because they need slot_data)
	if PopVersion < "0.20.1" or AutoTracker:GetConnectionState("SNES") == 3 then
	-- add snes interface functions here
	end
	-- setup data storage tracking for hint tracking
	local data_strorage_keys = {}
	if PopVersion >= "0.32.0" then
		data_strorage_keys = { getHintDataStorageKey() }
	end
	    table.insert(data_strorage_keys, "rsm_current_planet_"..Archipelago.PlayerNumber.."_"..Archipelago.TeamNumber)
	-- subscribes to the data storage keys for updates
	-- triggers callback in the SetNotify handler on update
	Archipelago:SetNotify(data_strorage_keys)
	-- gets the current value for the data storage keys
	-- triggers callback in the Retrieved handler when result is received
	Archipelago:Get(data_strorage_keys)
  Tracker.BulkUpdate = false

end

-- called when an item gets collected
function onItem(index, item_id, item_name, player_number)
	if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
		print(string.format("called onItem: %s, %s, %s, %s, %s", index, item_id, item_name, player_number, CUR_INDEX))
	end
	if not AUTOTRACKER_ENABLE_ITEM_TRACKING then
		return
	end
	if index <= CUR_INDEX then
		return
	end
	local is_local = player_number == Archipelago.PlayerNumber
	CUR_INDEX = index
	local mapping_entry = ITEM_MAPPING[item_id]
	if not mapping_entry then
		if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print(string.format("onItem: could not find item mapping for id %s", item_id))
		end
		return
	end
	for _, item_table in pairs(mapping_entry) do
		if item_table then
			local item_code = item_table[1]
			local item_type = item_table[2]
			local multiplier = item_table[3] or 1
			if item_code then
				incrementItem(item_code, item_type, multiplier)
				-- keep track which items we touch are local and which are global
				if is_local then
					if LOCAL_ITEMS[item_code] then
						LOCAL_ITEMS[item_code] = LOCAL_ITEMS[item_code] + 1
					else
						LOCAL_ITEMS[item_code] = 1
					end
				else
					if GLOBAL_ITEMS[item_code] then
						GLOBAL_ITEMS[item_code] = GLOBAL_ITEMS[item_code] + 1
					else
						GLOBAL_ITEMS[item_code] = 1
					end
				end
			elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
				print(string.format("onClear: skipping item_table with no item_code"))
			end
		elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print(string.format("onClear: skipping empty item_table"))
		end
	end
	if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
		print(string.format("local items: %s", dump_table(LOCAL_ITEMS)))
		--print(string.format("global items: %s", dump_table(GLOBAL_ITEMS)))
	end
	-- track local items via snes interface
	if PopVersion < "0.20.1" or AutoTracker:GetConnectionState("SNES") == 3 then
	-- add snes interface functions for local item tracking here
	end
end

-- called when a location gets cleared
function onLocation(location_id, location_name)
	if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
		print(string.format("called onLocation: %s, %s", location_id, location_name))
	end
	if not AUTOTRACKER_ENABLE_LOCATION_TRACKING then
		return
	end
	local mapping_entry = LOCATION_MAPPING[location_id]
	if not mapping_entry then
		if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print(string.format("onLocation: could not find location mapping for id %s", location_id))
		end
		return
	end
	for _, location_table in pairs(mapping_entry) do
		if location_table then
			local location_code = location_table[1]
			if location_code then
				local obj = Tracker:FindObjectForCode(location_code)
				if obj then
					if location_code:sub(1, 1) == "@" then
						obj.AvailableChestCount = obj.AvailableChestCount - 1
					else
					-- increment hosted item
						local item_type = location_table[2]
						incrementItem(location_code, item_type)
					end
				elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
					print(string.format("onLocation: could not find object for code %s", location_code))
				end
			elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
				print(string.format("onLocation: skipping location_table with no location_code"))
			end
		elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print(string.format("onLocation: skipping empty location_table"))
		end
	end
end

-- called when a locations is scouted
function onScout(location_id, location_name, item_id, item_name, item_player)
	if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
		print(string.format("called onScout: %s, %s, %s, %s, %s", location_id, location_name, item_id, item_name,
			item_player))
	end
-- not implemented yet :(
end

-- called when a bounce message is received
function onBounce(json)
	if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
		print(string.format("called onBounce: %s", dump_table(json)))
	end
-- your code goes here
end

-- called whenever Archipelago:Get returns data from the data storage or
-- whenever a subscribed to (via Archipelago:SetNotify) key in data storgae is updated
-- oldValue might be nil (always nil for "_read" prefixed keys and via retrieved handler (from Archipelago:Get))
function onDataStorageUpdate(key, value, oldValue)
--if you plan to only use the hints key, you can remove this if
	if key == getHintDataStorageKey() then
		onHintsUpdate(value)
	end
end

-- called whenever the hints key in data storage updated
-- NOTE: this should correctly handle having multiple mapped locations in a section.
--       if you only map sections 1 to 1 you can simplfy this. for an example see
--       https://github.com/Cyb3RGER/sm_ap_tracker/blob/main/scripts/autotracking/archipelago.lua
function onHintsUpdate(hints)
-- Highlight is only supported since version 0.32.0
	if PopVersion < "0.32.0" or not AUTOTRACKER_ENABLE_LOCATION_TRACKING then
		return
	end
	local player_number = Archipelago.PlayerNumber
	-- get all new highlight values per section
	local sections_to_update = {}
	for _, hint in ipairs(hints) do
	-- we only care about hints in our world
		if hint.finding_player == player_number then
			updateHint(hint, sections_to_update)
		end
	end
	-- update the sections
	for location_code, highlight_code in pairs(sections_to_update) do
	-- find the location object
		local obj = Tracker:FindObjectForCode(location_code)
		-- check if we got the location and if it supports Highlight
		if obj and obj.Highlight then
			obj.Highlight = highlight_code
		end
	end
end

-- update section highlight based on the hint
function updateHint(hint, sections_to_update)
-- get the highlight enum value for the hint status
	local hint_status = hint.status
	local highlight_code = nil
	if hint_status then
		highlight_code = HINT_STATUS_MAPPING[hint_status]
	end
	if not highlight_code then
		if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print(string.format("updateHint: unknown hint status %s for hint on location id %s", hint.status,
				hint.location))
		end
		-- try to "recover" by checking hint.found (older AP versions without hint.status)
		if hint.found == true then
			highlight_code = Highlight.None
		elseif hint.found == false then
			highlight_code = Highlight.Unspecified
		else
			return
		end
	end
	-- get the location mapping for the location id
	local mapping_entry = LOCATION_MAPPING[hint.location]
	if not mapping_entry then
		if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
			print(string.format("updateHint: could not find location mapping for id %s", hint.location))
		end
		return
	end
	--get the "highest" highlight value pre section
	for _, location_table in pairs(mapping_entry) do
		if location_table then
			local location_code = location_table[1]
			-- skip hosted items, they don't support Highlight
			if location_code and location_code:sub(1, 1) == "@" then
			-- see if we already set a Highlight for this section
				local existing_highlight_code = sections_to_update[location_code]
				if existing_highlight_code then
				-- make sure we only replace None or "increase" the highlight but never overwrite with None
				-- this so sections with mulitple mapped locations show the "highest" Highlight and
				-- only show no Highlight when all hints are found
					if existing_highlight_code == Highlight.None or (existing_highlight_code < highlight_code and highlight_code ~= Highlight.None) then
						sections_to_update[location_code] = highlight_code
					end
				else
					sections_to_update[location_code] = highlight_code
				end
			end
		end
	end
end

-- add AP callbacks
-- un-/comment as needed
Archipelago:AddClearHandler("clear handler", onClear)
if AUTOTRACKER_ENABLE_ITEM_TRACKING then
	Archipelago:AddItemHandler("item handler", onItem)
end
if AUTOTRACKER_ENABLE_LOCATION_TRACKING then
	Archipelago:AddLocationHandler("location handler", onLocation)
end
Archipelago:AddRetrievedHandler("retrieved handler", onDataStorageUpdate)
Archipelago:AddSetReplyHandler("set reply handler", onDataStorageUpdate)
-- Archipelago:AddScoutHandler("scout handler", onScout)
-- Archipelago:AddBouncedHandler("bounce handler", onBounce)
