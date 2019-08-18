--Helper Functions

local function get_sign(i)
	if i == 0 then
		return 0
	else
		return i / math.abs(i)
	end
end


local function get_velocity(v, yaw, y)
	local x = -math.sin(yaw) * v
	local z =  math.cos(yaw) * v
	return {x = x, y = y, z = z}
end


local function get_v(v)
	return math.sqrt(v.x ^ 2 + v.z ^ 2)
end

--Entities

--Vertical rocket: lift off, landing

local rocket = {
	initial_properties = {
		hp_max = 50,
		physical = true,
		collide_with_objects = false, -- Workaround fix for a MT engine bug
		collisionbox = {-0.85, 0.0, -0.85, 0.85, 5.0, 0.85}, --{-0.85, -1.5, -0.85, 0.85, 1.5, 0.85},
		visual = "mesh",
		mesh = "rocket.obj",
		visual_size = {x = 1.0, y = 1.0, z = 1.0},
		textures = {"rocket.png"},
	},

	-- Custom fields
	driver = nil,
	removed = false,
	v = 0,
	vy = 0,
	rot = 0,
	auto = false,
}

function rocket.on_punch(self, puncher)
	if not puncher or not puncher:is_player() or self.removed then
		return
	end

	local name = puncher:get_player_name()
	if self.driver and name == self.driver then
		-- Detach
		self.driver = nil
		puncher:set_detach()
		default.player_attached[name] = false
	end
	if not self.driver then
		-- Move to inventory
		self.removed = true
		local inv = puncher:get_inventory()
		if not (creative and creative.is_enabled_for
				and creative.is_enabled_for(name))
				or not inv:contains_item("main", "rocket:rocket_item") then
			local leftover = inv:add_item("main", "rocket:rocket_item")
			if not leftover:is_empty() then
				minetest.add_item(self.object:getpos(), leftover)
			end
		end
		minetest.after(0.1, function()
			self.object:remove()
		end)
	end
end

function rocket.on_rightclick(self, clicker)
	if not clicker or not clicker:is_player() then
		return
	end
	local name = clicker:get_player_name()
	if self.driver and name == self.driver then
		-- Detach
		self.driver = nil
		self.auto = false
		clicker:set_detach()
		default.player_attached[name] = false
		default.player_set_animation(clicker, "stand" , 30)
		local pos = clicker:getpos()
		minetest.after(0.1, function()
			clicker:setpos(pos)
		end)
	elseif not self.driver then
		-- Attach
		local attach = clicker:get_attach()
		if attach and attach:get_luaentity() then
			local luaentity = attach:get_luaentity()
			if luaentity.driver then
				luaentity.driver = nil
			end
			clicker:set_detach()
		end
		self.driver = name
		clicker:set_attach(self.object, "",
			{x = 0, y = 2, z = 0}, {x = 0, y = 4, z = 0})
		default.player_attached[name] = true
		minetest.after(0.2, function()
		--	default.player_set_animation(clicker, "sit" , 30)
			default.player_set_animation(clicker, "stand" , 30)
		end)
		clicker:set_look_horizontal(self.object:getyaw())
	end
end

function rocket.on_step(self, dtime)
	self.v = get_v(self.object:getvelocity()) * get_sign(self.v)
	self.vy = self.object:getvelocity().y

	-- Controls
	if self.driver then
		local driver_objref = minetest.get_player_by_name(self.driver)
		if driver_objref then
			--DOES NOT WORK--> Oxygen system, for when in space or an unbreathable atmosphere
			--self.driver:set_breath(11)
			local ctrl = driver_objref:get_player_control()
			if ctrl.jump and ctrl.sneak then --if ctrl.up and ctrl.down then
				if not self.auto then
					self.auto = true
					minetest.chat_send_player(self.driver,
						"[rocket] Cruise on")
				end
			elseif ctrl.sneak then --ctrl.down then
				--self.v = self.v - 0.1
				if self.auto then
					self.auto = false
					minetest.chat_send_player(self.driver,
						"[rocket] Cruise off")
				end
				--[[
			elseif ctrl.up or self.auto then
				self.v = self.v + 0.1
				--self.v = self.v + 10]]
			end
			if ctrl.up then
				self.v = self.v + 0.1
				--self.v = self.v + 10
			elseif ctrl.down then
				self.v = self.v - 0.1
			end
			if ctrl.left and ctrl.right then
				local sideways_rocket = minetest.add_entity(self.object:getpos(), "rocket:sideways_rocket")
				sideways_rocket:setyaw(self.object:getyaw())
				default.player_set_animation(driver_objref, "sit" , 30)
				driver_objref:set_detach()
				driver_objref:set_attach(sideways_rocket, "", {x = 0, y = 1, z = 0}, {x = 0, y = 2, z = 0})
				self.object:remove()
				--right click after pressing A+D to go into the sideways rocket
			elseif ctrl.left then
				self.rot = self.rot + 0.001
			elseif ctrl.right then
				self.rot = self.rot - 0.001
			end
			if (ctrl.jump or self.auto) and self.vy < 50 and (not self.auto) then
				self.vy = self.vy + 0.075
				--self.vy = self.vy + 7.5
				
				minetest.add_particlespawner({
					amount = 3, --1,
					time = 0.2, --0.1,
					minpos = {x = 0, y = 0, z = 0},
					maxpos = {x = 0, y = 0, z = 0},
					minvel = {x = -0.2, y = 0, z = -0.2},
					maxvel = {x = 0.3, y = 0.3, z = 0.3},
					minacc = {x = 0, y = 0.1, z = 0},
					maxacc = {x = 0, y = 0.3, z = 0},
					minexptime = 1,
					maxexptime = 2.5,
					minsize = 4, --1,
					maxsize = 10, --4,
					attached = self.object,
					texture = "rocket_smoke.png",
				})
				
				minetest.add_particlespawner({
					amount = 1, --1,
					time = 1.0, --0.1,
					minpos = {x = 0, y = 0, z = 0},
					maxpos = {x = 0, y = 0, z = 0},
					minvel = {x = -0.2, y = 0, z = -0.2},
					maxvel = {x = 0.3, y = 0.3, z = 0.3},
					minacc = {x = 0, y = 0.1, z = 0},
					maxacc = {x = 0, y = 0.3, z = 0},
					minexptime = 0.25, --1
					maxexptime = 0.75, --2.5,
					minsize = 14, --1,
					maxsize = 16, --4,
					attached = self.object,
					texture = "rocket_boom.png",
				})
				
			elseif (not (ctrl.jump or self.auto)) and self.vy > -50 then --elseif ctrl.sneak then
				self.vy = self.vy - 0.075
				--self.vy = self.vy - 7.5
			end
			if self.auto and self.vy > 0 and (not ctrl.jump) then
				minetest.add_particlespawner({
					amount = 3, --1,
					time = 0.2, --0.1,
					minpos = {x = 0, y = 0, z = 0},
					maxpos = {x = 0, y = 0, z = 0},
					minvel = {x = -0.2, y = 0, z = -0.2},
					maxvel = {x = 0.3, y = 0.3, z = 0.3},
					minacc = {x = 0, y = 0.1, z = 0},
					maxacc = {x = 0, y = 0.3, z = 0},
					minexptime = 1,
					maxexptime = 2.5,
					minsize = 4, --1,
					maxsize = 10, --4,
					attached = self.object,
					texture = "rocket_smoke.png",
				})
				
				minetest.add_particlespawner({
					amount = 1, --1,
					time = 1.0, --0.1,
					minpos = {x = 0, y = 0, z = 0},
					maxpos = {x = 0, y = 0, z = 0},
					minvel = {x = -0.2, y = 0, z = -0.2},
					maxvel = {x = 0.3, y = 0.3, z = 0.3},
					minacc = {x = 0, y = 0.1, z = 0},
					maxacc = {x = 0, y = 0.3, z = 0},
					minexptime = 0.25, --1
					maxexptime = 0.75, --2.5,
					minsize = 14, --1,
					maxsize = 16, --4,
					attached = self.object,
					texture = "rocket_boom.png",
				})
			end
		else
			-- Player left server while driving
			-- In MT 5.0.0 use 'rocket:on_detach_child()' to do this
			self.driver = nil
			self.auto = false
			minetest.log("warning", "[rocket] Driver left server while" ..
				" driving. This may cause some 'Pushing ObjectRef to" ..
				" removed/deactivated object' warnings.")
		end
	end

--[[
	if self.vy > 0 then
		minetest.add_particlespawner({
			amount = 3, --1,
			time = 0.2, --0.1,
			minpos = {x = 0, y = 0, z = 0},
			maxpos = {x = 0, y = 0, z = 0},
			minvel = {x = -0.2, y = 0, z = -0.2},
			maxvel = {x = 0.3, y = 0.3, z = 0.3},
			minacc = {x = 0, y = 0.1, z = 0},
			maxacc = {x = 0, y = 0.3, z = 0},
			minexptime = 1,
			maxexptime = 2.5,
			minsize = 4, --1,
			maxsize = 10, --4,
			attached = self.object,
			texture = "rocket_smoke.png",
		})
	end

	if self.vy > 0 then
		minetest.add_particlespawner({
			amount = 1, --1,
			time = 1.0, --0.1,
			minpos = {x = 0, y = 0, z = 0},
			maxpos = {x = 0, y = 0, z = 0},
			minvel = {x = -0.2, y = 0, z = -0.2},
			maxvel = {x = 0.3, y = 0.3, z = 0.3},
			minacc = {x = 0, y = 0.1, z = 0},
			maxacc = {x = 0, y = 0.3, z = 0},
			minexptime = 0.25, --1
			maxexptime = 0.75, --2.5,
			minsize = 14, --1,
			maxsize = 16, --4,
			attached = self.object,
			texture = "rocket_boom.png",
		})
	end
]]

	-- Early return for stationary vehicle
	if self.v == 0 and self.rot == 0 and self.vy == 0 then
		self.object:setpos(self.object:getpos())
		return
	end

	-- Reduction and limiting of linear speed
	local s = get_sign(self.v)
	self.v = self.v - 0.02 * s
	if s ~= get_sign(self.v) then
		self.v = 0
	end
	if math.abs(self.v) > 6 then
		self.v = 6 * get_sign(self.v)
	end

	-- Reduction and limiting of rotation
	local sr = get_sign(self.rot)
	self.rot = self.rot - 0.0003 * sr
	if sr ~= get_sign(self.rot) then
		self.rot = 0
	end
	if math.abs(self.rot) > 0.015 then
		self.rot = 0.015 * get_sign(self.rot)
	end

	-- Reduction and limiting of vertical speed
	--[[
	local sy = get_sign(self.vy)
	self.vy = self.vy - 0.03 * sy
	if sy ~= get_sign(self.vy) then
		self.vy = 0
	end
	if math.abs(self.vy) > 4 then
		self.vy = 4 * get_sign(self.vy)
	end
	]]

	local new_acce = {x = 0, y = 0, z = 0}
	-- Bouyancy in liquids
	--[[
	local p = self.object:getpos()
	p.y = p.y - 1.5
	local def = minetest.registered_nodes[minetest.get_node(p).name]
	if def and (def.liquidtype == "source" or def.liquidtype == "flowing") then
		new_acce = {x = 0, y = 10, z = 0}
	end
	]]

	self.object:setpos(self.object:getpos())
	self.object:setvelocity(get_velocity(self.v, self.object:getyaw(), self.vy))
	self.object:setacceleration(new_acce)
	self.object:setyaw(self.object:getyaw() + (1 + dtime) * self.rot)
end

minetest.register_entity("rocket:rocket", rocket)

--Horizontal rocket: moving in space, docking

local sideways_rocket = {
	initial_properties = {
		hp_max = 50,
		physical = true,
		collide_with_objects = false, -- Workaround fix for a MT engine bug
		collisionbox = {-0.9, 0.0, -2.5, 0.9, 1.85, 2.5},
		visual = "mesh",
		mesh = "sideways_rocket.obj",
		visual_size = {x = 1.0, y = 1.0, z = 1.0},
		textures = {"rocket.png"},
	},

	-- Custom fields
	driver = nil,
	removed = false,
	v = 0,
	vy = 0,
	rot = 0,
	auto = false,
}

function sideways_rocket.on_punch(self, puncher)
	if not puncher or not puncher:is_player() or self.removed then
		return
	end

	local name = puncher:get_player_name()
	if self.driver and name == self.driver then
		-- Detach
		self.driver = nil
		puncher:set_detach()
		default.player_attached[name] = false
	end
	if not self.driver then
		-- Move to inventory
		self.removed = true
		local inv = puncher:get_inventory()
		if not (creative and creative.is_enabled_for
				and creative.is_enabled_for(name))
				or not inv:contains_item("main", "rocket:rocket_item") then
			local leftover = inv:add_item("main", "rocket:rocket_item")
			if not leftover:is_empty() then
				minetest.add_item(self.object:getpos(), leftover)
			end
		end
		minetest.after(0.1, function()
			self.object:remove()
		end)
	end
end

function sideways_rocket.on_rightclick(self, clicker)
	if not clicker or not clicker:is_player() then
		return
	end
	local name = clicker:get_player_name()
	if self.driver and name == self.driver then
		-- Detach
		self.driver = nil
		self.auto = false
		clicker:set_detach()
		default.player_attached[name] = false
		default.player_set_animation(clicker, "stand" , 30)
		local pos = clicker:getpos()
		minetest.after(0.1, function()
			clicker:setpos(pos)
		end)
	elseif not self.driver then
		-- Attach
		local attach = clicker:get_attach()
		if attach and attach:get_luaentity() then
			local luaentity = attach:get_luaentity()
			if luaentity.driver then
				luaentity.driver = nil
			end
			clicker:set_detach()
		end
		self.driver = name
		clicker:set_attach(self.object, "",
			{x = 0, y = 1, z = 0}, {x = 0, y = 2, z = 0})
		default.player_attached[name] = true
		minetest.after(0.2, function()
			default.player_set_animation(clicker, "sit" , 30)
		end)
		clicker:set_look_horizontal(self.object:getyaw())
	end
end

function sideways_rocket.on_step(self, dtime)
	self.v = get_v(self.object:getvelocity()) * get_sign(self.v)
	self.vy = self.object:getvelocity().y

	-- Controls
	if self.driver then
		local driver_objref = minetest.get_player_by_name(self.driver)
		if driver_objref then
			local ctrl = driver_objref:get_player_control()
			if ctrl.up and ctrl.down then
				if not self.auto then
					self.auto = true
					minetest.chat_send_player(self.driver,
						"[rocket] Cruise on")
				end
			elseif ctrl.down then --braking
				--self.v = self.v - 0.1
				if self.v > 0 and self.v < 0.01 then
					self.v = 0
				elseif self.v > 0 then
					self.v = self.v - 0.1
				end
				if self.auto then
					self.auto = false
					minetest.chat_send_player(self.driver,
						"[rocket] Cruise off")
				end
			elseif ctrl.up or self.auto then
				--self.v = self.v + 0.1
				if self.v < 30.0 then
					self.v = self.v + 0.1
				end
				minetest.add_particlespawner({
					amount = 1, --1,
					time = 1.0, --0.1,
					minpos = {x = 0, y = 0.5, z = 0},
					maxpos = {x = 0, y = 0.5, z = 0},
					minvel = {x = -0.2, y = 0, z = -0.2},
					maxvel = {x = 0.3, y = 0.3, z = 0.3},
					minacc = {x = 0, y = 0.1, z = 0},
					maxacc = {x = 0, y = 0.3, z = 0},
					minexptime = 0.25, --1
					maxexptime = 1.0, --2.5,
					minsize = 14, --1,
					maxsize = 16, --4,
					attached = self.object,
					texture = "rocket_boom.png",
				})
			end
			if ctrl.left and ctrl.right then
				local rocket = minetest.add_entity(self.object:getpos(), "rocket:rocket")
				rocket:setyaw(self.object:getyaw())
				default.player_set_animation(driver_objref, "stand" , 30)
				driver_objref:set_detach()
				driver_objref:set_attach(rocket, "", {x = 0, y = 1, z = 0}, {x = 0, y = 2, z = 0})
				self.object:remove()
				--right click after pressing A+D to go into the rocket
			elseif ctrl.left then
				self.rot = self.rot + 0.001
			elseif ctrl.right then
				self.rot = self.rot - 0.001
			end
			if ctrl.jump then
				self.vy = self.vy + 0.075
			elseif ctrl.sneak then
				self.vy = self.vy - 0.075
			end
		else
			-- Player left server while driving
			-- In MT 5.0.0 use 'sideways_rocket:on_detach_child()' to do this
			self.driver = nil
			self.auto = false
			minetest.log("warning", "[rocket] Driver left server while" ..
				" driving. This may cause some 'Pushing ObjectRef to" ..
				" removed/deactivated object' warnings.")
		end
	end

--[[
	if self.v > 0 then
		minetest.add_particlespawner({
			amount = 1, --1,
			time = 1.0, --0.1,
			minpos = {x = 0, y = 0.5, z = 0},
			maxpos = {x = 0, y = 0.5, z = 0},
			minvel = {x = -0.2, y = 0, z = -0.2},
			maxvel = {x = 0.3, y = 0.3, z = 0.3},
			minacc = {x = 0, y = 0.1, z = 0},
			maxacc = {x = 0, y = 0.3, z = 0},
			minexptime = 0.25, --1
			maxexptime = 1.0, --2.5,
			minsize = 14, --1,
			maxsize = 16, --4,
			attached = self.object,
			texture = "rocket_boom.png",
		})
	end
]]

	-- Early return for stationary vehicle
	if self.v == 0 and self.rot == 0 and self.vy == 0 then
		self.object:setpos(self.object:getpos())
		return
	end

	-- Reduction and limiting of linear speed
	--[[
	local s = get_sign(self.v)
	self.v = self.v - 0.02 * s
	if s ~= get_sign(self.v) then
		self.v = 0
	end
	if math.abs(self.v) > 6 then
		self.v = 6 * get_sign(self.v)
	end
	]]

	-- Reduction and limiting of rotation
	local sr = get_sign(self.rot)
	self.rot = self.rot - 0.0003 * sr
	if sr ~= get_sign(self.rot) then
		self.rot = 0
	end
	if math.abs(self.rot) > 0.015 then
		self.rot = 0.015 * get_sign(self.rot)
	end

	-- Reduction and limiting of vertical speed
	local sy = get_sign(self.vy)
	self.vy = self.vy - 0.03 * sy
	if sy ~= get_sign(self.vy) then
		self.vy = 0
	end
	if math.abs(self.vy) > 4 then
		self.vy = 4 * get_sign(self.vy)
	end

	local new_acce = {x = 0, y = 0, z = 0}
	-- Bouyancy in liquids
	--[[
	local p = self.object:getpos()
	p.y = p.y - 1.5
	local def = minetest.registered_nodes[minetest.get_node(p).name]
	if def and (def.liquidtype == "source" or def.liquidtype == "flowing") then
		new_acce = {x = 0, y = 10, z = 0}
	end
	]]

	self.object:setpos(self.object:getpos())
	self.object:setvelocity(get_velocity(self.v, self.object:getyaw(), self.vy))
	self.object:setacceleration(new_acce)
	self.object:setyaw(self.object:getyaw() + (1 + dtime) * self.rot)
end

minetest.register_entity("rocket:sideways_rocket", sideways_rocket)

--Main Craftitem

minetest.register_craftitem("rocket:rocket_item", {
	description = "Space Shuttle",
	inventory_image = "rocket_rocket_inv.png",
	wield_scale = {x = 1, y = 1, z = 1},
	liquids_pointable = true,

	on_place = function(itemstack, placer, pointed_thing)
		local under = pointed_thing.under
		local node = minetest.get_node(under)
		local udef = minetest.registered_nodes[node.name]

		-- Run any on_rightclick function of pointed node instead
		if udef and udef.on_rightclick and
				not (placer and placer:is_player() and
				placer:get_player_control().sneak) then
			return udef.on_rightclick(under, node, placer, itemstack,
				pointed_thing) or itemstack
		end

		if pointed_thing.type ~= "node" then
			return itemstack
		end

		pointed_thing.under.y = pointed_thing.under.y + 0.5 -- + 2
		local rocket = minetest.add_entity(pointed_thing.under,
			"rocket:rocket")
		if rocket then
			if placer then
				rocket:setyaw(placer:get_look_horizontal())
			end
			local player_name = placer and placer:get_player_name() or ""
			if not (creative and creative.is_enabled_for and
					creative.is_enabled_for(player_name)) then
				itemstack:take_item()
			end
		end
		return itemstack
	end,
})

--Other craftitems

minetest.register_craftitem("rocket:rocket_cone", {
	description = "Rocket Cone",
	inventory_image = "rocket_cone.png"
})

minetest.register_craftitem("rocket:rocket_thruster", {
	description = "Rocket Thruster",
	inventory_image = "rocket_thruster.png"
})

minetest.register_craftitem("rocket:rocket_hull", {
	description = "Rocket Hull",
	inventory_image = "rocket_hull.png"
})

minetest.register_craftitem("rocket:rocket_left_fin", {
	description = "Rocket Left Fin",
	inventory_image = "rocket_left_fin.png"
})

minetest.register_craftitem("rocket:rocket_right_fin", {
	description = "Rocket Right Fin",
	inventory_image = "rocket_right_fin.png"
})

--Crafting recipes

minetest.register_craft({
    type = "shaped",
    output = "rocket:rocket_left_fin",
    recipe = {
        {"", "", "default:steel_ingot"},
        {"", "default:steel_ingot", "default:steel_ingot"},
        {"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"}
    }
})

minetest.register_craft({
    type = "shaped",
    output = "rocket:rocket_right_fin",
    recipe = {
        {"default:steel_ingot", "", ""},
        {"default:steel_ingot", "default:steel_ingot", ""},
        {"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"}
    }
})

minetest.register_craft({
    type = "shaped",
    output = "rocket:rocket_thruster",
    recipe = {
        {"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
        {"", "default:steelblock", ""},
        {"default:steelblock", "bucket:bucket_lava", "default:steelblock"}
    }
})

minetest.register_craft({
    type = "shaped",
    output = "rocket:rocket_hull",
    recipe = {
        {"default:steelblock", "default:glass", "default:steelblock"},
        {"default:steelblock", "default:glass", "default:steelblock"},
        {"default:steelblock", "default:glass", "default:steelblock"}
    }
})

minetest.register_craft({
    type = "shaped",
    output = "rocket:rocket_cone",
    recipe = {
        {"", "default:steel_ingot", ""},
        {"", "stairs:slab_steelblock", ""},
        {"stairs:slab_steelblock", "default:steelblock", "stairs:slab_steelblock"}
    }
})

minetest.register_craft({
    type = "shaped",
    output = "rocket:rocket_item",
    recipe = {
        {"", "rocket:rocket_cone", ""},
        {"", "rocket:rocket_hull", ""},
        {"rocket:rocket_left_fin", "rocket:rocket_thruster", "rocket:rocket_right_fin"}
    }
})
