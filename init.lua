--[[

	lumberjack
	==========

	Copyright (C) 2018 Joachim Stolberg

	LGPLv2.1+
	See LICENSE.txt for more information

	Mod to completely cut trees by destroying only one block.
	This mod allows to destroy the bottom of the tree and the whole tree is felled
	and moved to the players inventory.
	
	To distinguish between "grown" trees and placed tree nodes, the attribute 
	'node.param1' is used to identify placed nodes.
	
	The number of necessary lumberjack points has to be configured via 'settingtypes.txt'
	
]]--

lumberjack = {}

local MY_PARAM1_VAL = 7  -- to identify placed nodes

-- Necessary number of points for dug trees and placed sapling to get lumberjack privs
local LUMBERJACK_TREE_POINTS = tonumber(minetest.settings:get("lumberjack_points")) or 400
local LUMBERJACK_SAPL_POINTS = LUMBERJACK_TREE_POINTS / 6

local lTrees = {} -- List of registered tree items

--
-- Check if used tool is some kind of axe and is used by a player
--
local function chopper_tool(digger)
	if digger and digger:is_player() then
		local tool = digger:get_wielded_item()
		if tool:get_name() == "screwdriver:screwdriver" then
			return true
		end
		if tool then
			local caps = tool:get_tool_capabilities()
			return caps.groupcaps and caps.groupcaps.choppy
		end 
	end
	return false
end

--
-- Remove/add tree steps
--
local function remove_steps(pos)
	local pos1 = {x=pos.x-1, y=pos.y, z=pos.z-1}
	local pos2 = {x=pos.x+1, y=pos.y, z=pos.z+1}
	for _,pos in ipairs(minetest.find_nodes_in_area(pos1, pos2, "lumberjack:step")) do
		minetest.remove_node(pos)
	end
end

local function add_steps(pos, digger)
	local facedir = minetest.dir_to_facedir(digger:get_look_dir(), false)
	local dir = minetest.facedir_to_dir((facedir + 2) % 4)
	local newpos = vector.add(pos, dir)
	if minetest.get_node(newpos).name == "air" then
		minetest.add_node(newpos, {name="lumberjack:step", param2=facedir})
	end
end

local function on_punch(pos, node, puncher, pointed_thing)
	if chopper_tool(puncher) and node.param1 == 0 then  -- grown tree?
		if not minetest.is_protected(pos, puncher:get_player_name()) then
			add_steps(pos, puncher)
		end
	end
	minetest.node_punch(pos, node, puncher, pointed_thing)
end

--
-- tool wearing
--
local function add_wear(digger, node, num_nodes)
	local tool = digger:get_wielded_item()
	if tool then
		local caps = tool:get_tool_capabilities()
		if caps.groupcaps and caps.groupcaps.choppy then 
			local uses = caps.groupcaps.choppy.uses or 10
			uses = uses * 9
			tool:add_wear(65535 * num_nodes / uses)
			digger:set_wielded_item(tool)
		end
	end 
end

--
-- Remove all treen nodes including steps in the given area
--
local function remove_items(pos1, pos2, name)
	local cnt = 0
	for _,pos in ipairs(minetest.find_nodes_in_area(pos1, pos2, name)) do
		minetest.remove_node(pos)
		remove_steps(pos)
		cnt = cnt + 1
	end
	return cnt
end

--
-- Check for tree nodes on the next higher level
-- We have to check more than one level, because Ethereal allows stem gaps
--
local function is_top_tree_node(pos, name)
	local pos1 = {x=pos.x-1, y=pos.y+1, z=pos.z-1}
	local pos2 = {x=pos.x+1, y=pos.y+3, z=pos.z+1}
	for _,pos in ipairs(minetest.find_nodes_in_area(pos1, pos2, name)) do
		return false
	end
	return true
end

--
-- Check for the necessary number of points and grant lumberjack privs if level is reached
--
local function check_points(player)
	local player_attributes = player:get_meta()
	local points
	
	if player_attributes:get("lumberjack_tree_points") then
		points = player_attributes:get_float("lumberjack_tree_points")
	else
		points = LUMBERJACK_TREE_POINTS
	end
	
	if player_attributes:get("lumberjack_sapl_points") then
		points = points	+ player_attributes:get_float("lumberjack_sapl_points")
	else
		points = points	+ LUMBERJACK_SAPL_POINTS
	end
	
	if points > 0 then
		return false
	elseif points == 0 then
		local privs = minetest.get_player_privs(player:get_player_name())
		privs.lumberjack = true
		minetest.set_player_privs(player:get_player_name(), privs)
		player_attributes:get_float("lumberjack_tree_points", "-1")
		player_attributes:get_float("lumberjack_sapl_points", "-1")
		minetest.chat_send_player(player:get_player_name(), "You got lumberjack privs now")
		minetest.log("action", player:get_player_name().." got lumberjack privs")
	end
	return true
end

--
-- Maintain lumberjack points and grant lumberjack privs if level is reached
--
local function needed_points(digger)
	local digger_attributes = digger:get_meta()
	local points = digger_attributes:get_float("lumberjack_tree_points") or LUMBERJACK_TREE_POINTS
	if points > 0 then
		digger_attributes:set_float("lumberjack_tree_points", points - 1)
	end
	if points == 0 then
		return check_points(digger)
	end
	return false
end

--
-- Decrement sapling points
--
local function after_place_sapling(pos, placer)
	if placer and placer.is_player and placer:is_player() and placer.get_meta then
		local placer_attributes = placer:get_meta()
		local points = placer_attributes:get_float("lumberjack_sapl_points") or LUMBERJACK_SAPL_POINTS
		if points > 0 then
			placer_attributes:set_float("lumberjack_sapl_points", points - 1)
		end
		if points == 0 then
			check_points(placer)
		end
	end
end	

--
-- Remove the complete tree and return the number of removed items
--
local function remove_tree(pos, radius, name)
	local level = 1
	local num_nodes = 0
	while true do
		-- We have to check more than one level, because Ethereal allows stem gaps
		local pos1 = {x=pos.x-radius, y=pos.y+level,   z=pos.z-radius}
		local pos2 = {x=pos.x+radius, y=pos.y+level+2, z=pos.z+radius}
		local cnt = remove_items(pos1, pos2, name)
		if cnt == 0 then break end
		num_nodes = num_nodes + cnt
		level = level + 3
	end
	return num_nodes
end


--
-- Add tree items to the players inventory
--
local function add_to_inventory(digger, name, len, pos)
	local inv = digger:get_inventory()
	local items = ItemStack(name .. " " .. len)
	if inv and items and inv:room_for_item("main", items) then
		inv:add_item("main", items)
	else
		minetest.item_drop(items, digger, pos)
	end
end	

--
-- Remove the complete tree if the destroyed node belongs to a tree
--
local function after_dig_node(pos, oldnode, oldmetadata, digger)
	-- Player placed node?
	if oldnode.param1 ~= 0 then return end
	remove_steps(pos)
	-- don't remove whole tree?
	if not digger or digger:get_player_control().sneak then	return end
	-- Get tree parameters
	local height_min = 3
	local radius = 0
	local registered_tree = lTrees[oldnode.name]
	if registered_tree then
		height_min = registered_tree.height_min or height_min
		radius = registered_tree.radius or radius
	end
	-- Or root nodes?
	local test_pos = {x=pos.x, y=pos.y+height_min-1, z=pos.z}
	if minetest.get_node(test_pos).name ~= oldnode.name then return	end
	-- Fell the tree
	local num_nodes = remove_tree(pos, radius, oldnode.name)
	add_to_inventory(digger, oldnode.name, num_nodes, pos)
	add_wear(digger, oldnode, num_nodes)
	minetest.log("action", digger:get_player_name().." fells "..oldnode.name..
					" ("..num_nodes.." items)".." at "..minetest.pos_to_string(pos))
	minetest.sound_play("tree_falling", {pos = pos, max_hear_distance = 16})
end	

--
-- Mark node as "placed by player"
--
local function on_construct(pos)
	local node = minetest.get_node(pos)
	if node then
		minetest.swap_node(pos, {name=node.name, param1=MY_PARAM1_VAL, param2=node.param2})		
	end
end

local function can_dig(pos, digger)
	if not digger then
		return true
	end
	if minetest.is_protected(pos, digger:get_player_name()) then
		return false
	end
	if minetest.check_player_privs(digger:get_player_name(), "lumberjack") then
		if chopper_tool(digger) then
			return true
		else
			minetest.chat_send_player(digger:get_player_name(), "[Lumberjack Mod] You have to use an axe")
			return false
		end
	end
	local node = minetest.get_node(pos)
	if node.param1 ~= 0 then 
		return true
	end
	if is_top_tree_node(pos, node.name) or needed_points(digger) then
		return true
	end
	minetest.chat_send_player(digger:get_player_name(), "[Lumberjack Mod] From the top, please")
	return false
end

minetest.register_privilege("lumberjack", 
	{description = "Gives you the rights to fell a tree at once", 
	give_to_singleplayer = true})

minetest.register_node("lumberjack:step", {
	description = "Lumberjack Step",
	drawtype = "nodebox",
	tiles = {"lumberjack_steps.png"},
	node_box = {
		type = "fixed",
		fixed = {
			{  -0.5, -0.5, 0.49,  0.5,  0.5,  0.5},
		},
	},	
	paramtype2 = "facedir",
	is_ground_content = false,
	climbable = true,
	paramtype = "light",
	use_texture_alpha = true,
	sunlight_propagates = true,
	walkable = false,
	pointable = false,
	drop = "",
	groups = {choppy = 2},
})


--
-- Register the tree node to the lumberjack mod.
-- 'tree_name' is the tree item name,, e.g. "default:tree"
-- 'sapling_name' is the tree sapling name, e.g. "default:sapling"
-- 'radius' the the range in nodes (+x/-x/+z/-z), where all available tree nodes will be removed.
-- 'stem_height_min' is the minimum number of tree nodes, to be a valid stem (and not the a root item).
--
function lumberjack.register_tree(tree_name, sapling_name, radius, stem_height_min)
	
	-- check tree attributes
	local data = minetest.registered_nodes[tree_name]
	if data == nil then
		error("[lumberjack] "..tree_name.." is no valid item")
	end
	if data.after_dig_node then
		error("[lumberjack] "..tree_name.." has already an 'after_dig_node' function")
	end
	if data.on_construct then
		error("[lumberjack] "..tree_name.." has already an 'on_construct' function")
	end
	if data.can_dig then
		error("[lumberjack] "..tree_name.." has already a 'can_dig' function")
	end
	if not data.groups.choppy then
		error("[lumberjack] "..tree_name.." has no 'choppy' property")
	end
	
	-- check sapling attributes
	if minetest.registered_nodes[sapling_name].after_place_node then
		error("[lumberjack] "..sapling_name.." has already an 'after_place_node' function")
	end
	
	minetest.override_item(tree_name, {
			after_dig_node = after_dig_node, 
			on_construct = on_construct,
			can_dig = can_dig,
			on_punch = on_punch,
	})
	minetest.override_item(sapling_name, {
			after_place_node = after_place_sapling
	})

	lTrees[tree_name] = {radius=radius, height_min=stem_height_min, choppy=data.groups.choppy}
end

lumberjack.register_tree("default:tree", "default:sapling", 1, 2)
lumberjack.register_tree("default:jungletree", "default:junglesapling", 1, 5)
lumberjack.register_tree("default:acacia_tree", "default:acacia_sapling", 2, 3)
lumberjack.register_tree("default:aspen_tree", "default:aspen_sapling", 0, 5)
lumberjack.register_tree("default:pine_tree", "default:pine_sapling", 0, 3)

if minetest.get_modpath("ethereal") and minetest.global_exists("ethereal") then 
	lumberjack.register_tree("ethereal:palm_trunk", "ethereal:palm_sapling", 1, 3)
	lumberjack.register_tree("ethereal:mushroom_trunk", "ethereal:mushroom_sapling", 1, 3)
	lumberjack.register_tree("ethereal:birch_trunk", "ethereal:birch_sapling", 0, 3)
	lumberjack.register_tree("ethereal:banana_trunk", "ethereal:banana_tree_sapling", 1, 3)
	lumberjack.register_tree("ethereal:willow_trunk", "ethereal:willow_sapling", 4, 3)
	lumberjack.register_tree("ethereal:frost_tree", "ethereal:frost_tree_sapling", 1, 3)
	lumberjack.register_tree("ethereal:sakura_trunk", "ethereal:sakura_sapling", 4, 3)
	lumberjack.register_tree("ethereal:yellow_trunk", "ethereal:yellow_tree_sapling", 3, 3)
end

if minetest.get_modpath("moretrees") and minetest.global_exists("moretrees") then
	lumberjack.register_tree("moretrees:beech_trunk", "moretrees:beech_sapling", 1, 3)
	lumberjack.register_tree("moretrees:apple_tree_trunk", "moretrees:apple_tree_sapling", 8, 3)
	lumberjack.register_tree("moretrees:oak_trunk", "moretrees:oak_sapling", 13,5 )
	lumberjack.register_tree("moretrees:sequoia_trunk", "moretrees:sequoia_sapling", 9, 3)
	lumberjack.register_tree("moretrees:birch_trunk", "moretrees:birch_sapling", 12,5)
	lumberjack.register_tree("moretrees:palm_trunk", "moretrees:palm_sapling", 5, 3)
--	lumberjack.register_tree("moretrees:palm_fruit_trunk", "moretrees:palm_sapling", 5, 3)
	lumberjack.register_tree("moretrees:spruce_trunk", "moretrees:spruce_sapling", 1, 3)
	lumberjack.register_tree("moretrees:pine_trunk", "moretrees:pine_sapling", 0, 3)
	lumberjack.register_tree("moretrees:willow_trunk", "moretrees:willow_sapling",1,3)
	lumberjack.register_tree("moretrees:rubber_tree_trunk", "moretrees:rubber_tree_sapling", 7, 3)
--	lumberjack.register_tree("moretrees:jungletree_trunk", "moretrees:jungletree_sapling", 1, 5) -- crashes
	lumberjack.register_tree("moretrees:fir_trunk", "moretrees:fir_sapling", 5, 3) -- below leaves by 5
end
