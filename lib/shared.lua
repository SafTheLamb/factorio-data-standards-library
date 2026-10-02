local fds_assert = require("lib.assert")

local fds_shared = {}

-------------------------------------------------------------------------- Find prototypes

---Gets the given recipe if it exists, either by name (e.g. "iron-gear-wheel"), or the literal recipe prototype itself.
---This may seem odd, but this allows many functions to accept either a recipe name, or modify a recipe that hasn't been added to data.raw.recipes
---@param recipe_in string|data.RecipePrototype 
---@param required any
---@return data.RecipePrototype?
---@return string?
function fds_shared.find_recipe(recipe_in, required)
	local recipe = recipe_in
	if type(recipe_in) == "string" then recipe = data.raw.recipe[recipe_in] end
	if recipe ~= nil then
		fds_assert.ensure(recipe.type == "recipe", "fds_shared.find_recipe: Provided table is not a RecipePrototype")
	end
	---@cast recipe data.RecipePrototype
	fds_assert.ensure_if(recipe, required, "fds_shared.find_recipe: Required recipe `%s` is missing.", recipe_in)
	return recipe, (recipe and recipe.name)
end

-------------------------------------------------------------------------- Surface conditions

---Checks if a set of surface conditions are met by a set of surface properties
---If there's a condition for a property that is not contained within the properties table, the default value for that surface property will be checked
---@param surface_conditions SurfaceCondition[]? 
---@param surface_properties table<SurfacePropertyID, double>? 
---@return boolean are_compatible
function fds_shared.are_surface_conditions_compatible(surface_conditions, surface_properties)
	if not feature_flags["space_travel"] then return true end
	for _,condition in pairs(surface_conditions or {}) do
		local value = surface_properties and surface_properties[condition.property] or nil
		if not value then
			local property = data.raw["surface-property"][condition.property]
			value = property and property.default_value or nil
		end
		if type(value) ~= "number" then return false end
		if (condition.min and value < condition.min) or (condition.max and value > condition.max) then
			return false
		end
	end
	return true
end

---Relaxes the limits of all surface conditions to be permitted by a set of surface properties
---@param surface_conditions SurfaceCondition[]? Conditions to relax
---@param surface_properties table<SurfacePropertyID, double>?
function fds_shared.make_surface_conditions_compatible(surface_conditions, surface_properties)
	if not feature_flags["space_travel"] then return end
	for _,condition in pairs(surface_conditions or {}) do
		local value = surface_properties and surface_properties[condition.property] or nil
		if not value then
			local property = data.raw["surface-property"][condition.property]
			value = property and property.default_value or nil
		end
		if type(value) == "number" then
			if condition.min and value < condition.min then
				condition.min = value
			elseif condition.max and value > condition.max then
				condition.max = value
			end
		end
	end
end

function fds_shared.get_surface_condition(prototype, property_name)
	assert(type(property_name) == "string")
	if feature_flags["space_travel"] then
		if prototype.surface_conditions then
			for _,condition in pairs(prototype.surface_conditions) do
				if condition.property == property_name then
					return condition
				end
			end
		end
	end
	return nil
end

function fds_shared.set_surface_condition(prototype, new_condition)
	assert(type(new_condition.property) == "string" and (type(new_condition.min) == "number" or type(new_condition.max) == "number"))
	if feature_flags["space_travel"] then
		if prototype.surface_conditions == nil then
			prototype.surface_conditions = {new_condition}
		else
			for _,condition in pairs(prototype.surface_conditions) do
				if condition.property == new_condition.property then
					condition.min = new_condition.min
					condition.max = new_condition.max
					return
				end
			end
			table.insert(prototype.surface_conditions, new_condition)
		end
	end
end

function fds_shared.remove_surface_condition(prototype, property_name)
	assert(type(property_name) == "string")
	if feature_flags["space_travel"] and prototype.surface_conditions then
		for i,condition in pairs(prototype.surface_conditions) do
			if condition.property == property_name then
				table.remove(prototype.surface_conditions, i)
				return true
			end
		end
	end
	return false
end

-------------------------------------------------------------------------- 

return fds_shared
