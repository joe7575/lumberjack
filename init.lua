--[[

	lumberjack
	==========

	Copyright (C) 2018 Joachim Stolberg

	LGPLv2.1+
	See LICENSE.txt for more information

	This mod allows to hit the bottom of the tree and the whole tree is harvested
	and moved to the players inventory.
	To distinguish between "grown" trees and playes tree nodes, the 'node.param1'
	is used to identify placed nodes.
	
]]--

lumberjack = {}

local MY_PARAM1_VAL = 7  -- to identify placed nodes

local lTrees = {} -- List od registered tree items

--
-- Register the tree node to the lumberjack mod.
-- 'radius' the the range (+x/-x/+z/-z), where all available tree nodes will be removed-
-- 'stem_height_min' is the minimum number of tree nodes, to be a valid stem (and not the a root)-
--
function lumberjack.register_tree(name, radius, stem_height_min)
	local data = minetest.registered_nodes[name]
	if data == nil then
		error("[lumberjack] "..name.." is no valid item")
	end
	if data.after_dig_node == nil then
		minetest.override_item(name, {
				after_dig_node = after_dig_node, 
				on_construct = on_construct,
		})
	else
		error("[lumberjack] "..name.." has already an 'after_dig_node' function")
	end
	lTrees[name] = {radius=radius, height_min=stem_height_min}
end


--
-- Remove all treen nodes in the given range
--
local function remove_level(pos1, pos2, name)
	local cnt = 0
	for _,pos in ipairs(minetest.find_nodes_in_area(pos1, pos2, name)) do
		minetest.remove_node(pos)
		cnt = cnt + 1
	end
	return cnt
end

--
-- Remove the complete tree and return the number of removed items
--
local function remove_tree(pos, radius, name)
	local level = 1
	local num_nodes = 0
	while true do
		local pos1 = {x=pos.x-radius, y=pos.y+level, z=pos.z-radius}
		local pos2 = {x=pos.x+radius, y=pos.y+level, z=pos.z+radius}
		local cnt = remove_level(pos1, pos2, name)
		if cnt == 0 then break end
		num_nodes = num_nodes + cnt
		level = level + 1
	end
	return num_nodes
end

--
-- Add tree items to the players inventory
--
local function add_to_inventory(digger, name, len)
	local inv = digger:get_inventory()
	local items = ItemStack(name .. " " .. len)
	if inv and items and inv:room_for_item("main", items) then
		inv:add_item("main", items)
	end
end	


--
-- Remove the complete tree if the digged node belongs to a tree
--
local function after_dig_node(pos, oldnode, oldmetadata, digger)
	if not digger or digger:get_player_control().sneak then	return end
	-- not a player placed node?
	if oldnode.param1 == MY_PARAM1_VAL then return end
	-- not root nodes?
	local height_min = lTrees[oldnode.name].height_min or 3
	local test_pos = {x=pos.x, y=pos.y+height_min-1, z=pos.z}
	if minetest.get_node(test_pos).name ~= oldnode.name then return	end
	-- OK, cut tree
	local radius = lTrees[oldnode.name].radius or 0
	local num_nodes = remove_tree(pos, radius, oldnode.name)
	add_to_inventory(digger, oldnode.name, num_nodes)
	minetest.sound_play("tree_falling", {pos = pos, max_hear_distance = 16})
end	

--
-- Mark node as "used placed"
--
local function on_construct(pos)
	local node = minetest.get_node(pos)
	if node then
		minetest.swap_node(pos, {name=node.name, param1=MY_PARAM1_VAL, param2=node.param2})		
	end
end


lumberjack.register_tree("default:jungletree", 1, 5)
lumberjack.register_tree("default:acacia_tree", 2, 3)
lumberjack.register_tree("default:aspen_tree", 0, 5)
lumberjack.register_tree("default:tree", 1, 2)
lumberjack.register_tree("default:pine_tree", 0, 3)

if minetest.get_modpath("ethereal") and ethereal ~= nil then 
	lumberjack.register_tree("ethereal:palm_trunk", 1, 3)
	lumberjack.register_tree("ethereal:mushroom_trunk", 1, 3)
	lumberjack.register_tree("ethereal:birch_trunk", 0, 3)
	lumberjack.register_tree("ethereal:banana_trunk", 1, 3)
	lumberjack.register_tree("ethereal:willow_trunk", 4, 3)
	lumberjack.register_tree("ethereal:frost_tree", 1, 3)
end
