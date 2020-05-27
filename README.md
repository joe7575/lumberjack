# Lumberjack

A Mod for tree harvesting and planting!

This mod fulfills several aspects:
- New players are trained to always fell trees completely and replace them with saplings (education for sustainability)
- Trained players with additional "skills" get lumberjack privs to fell trees more efficiently (based on ideas from TreeCapitator and several Timber mods)
- No parts of trees hanging in the air anymore
  
This mod allows to completely fell trees by destroying only one block. The whole tree is harvested and moved to the players inventory. But therefore lumberjack privs are needed. New player normally will not get the necessary privs immediately, they have to harvest the tree from the top, block by block "to improve their skills".

But there are three configuration possibilities:
1. All players get directly lumberjack privs
2. Players have to collect points to get lumberjack privs
3. Players will never get lumberjack privs from the mod itself (but will be granted by means of other reasons)

Points have to be collected by harvesting tree blocks *AND* planting saplings.
The default setting is 400 which means, you have to harvest more then 400 tree blocks and plant more then 66 (400/6) saplings to get lumberjack privs.

The configuration can be changed directly in the file 'settingtypes.txt' or by means of the Minetest GUI.

Some technical aspects:
- 'param1' of the nodes data is used to distinguish between grown trees and placed tree blocks so that this mod will not have any impact to buildings or other objects based on tree blocks
- an API function allows to register additional trees from other mods, which is quite simple
- the Ethereal mod is already supported, others will follow
 
 
## Dependencies
default

# License
Copyright (C) 2018-2020 Joachim Stolberg  
Code: Licensed under the GNU LGPL version 2.1 or later. See LICENSE.txt and http://www.gnu.org/licenses/lgpl-2.1.txt  
Sound is taken from Hybrid Dog (TreeCapitator)

# History
v0.1 - 07/Apr/2018 - Mod initial created  
v0.2 - 08/Apr/2018 - Priv 'lumberjack' added, digging of trees from the top only added, tool wearing added  
v0.3 - 09/Apr/2018 - Harvesting points for placing saplings and destroying tree blocks added to reach lumberjack privs  
v0.4 - 16/Apr/2018 - Stem steps added  
v0.5 - 17/Apr/2018 - protection bug fixed, further improvements  
v0.6 - 07/Jan/2020 - screwdriver bugfix
v0.7 - 27/May/2020 - ethereal bugfix

