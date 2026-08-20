local fds_assert = require("lib.assert")

local fds_recipe = {}

------------------------------------------------------------------------------- Find
local fds_shared = require("__fdsl__.lib.shared")

local find_recipe = fds_shared.find_recipe
fds_recipe.find = fds_shared.find_recipe

---@param ingredient_name string Name of the ingredient to search for
---@return table recipes All recipes with the given ingredient
function fds_recipe.find_by_ingredient(ingredient_name)
	local matches = {}
	for _,recipe in pairs(data.raw.recipe) do
		for _,ingredient in pairs(recipe.ingredients or {}) do
			if ingredient.name == ingredient_name then
				table.insert(matches, recipe.name)
				goto continue
			end
		end
		::continue::
	end
	return matches
end

---@param category_name string Name of the category to search for
---@return table recipes All recipes with the given category
function fds_recipe.find_by_category(category_name)
	local matches = {}
	for _,recipe in pairs(data.raw.recipe) do
		if recipe.categories then
			for _,category in pairs(recipe.categories) do
				if category == category_name then
					table.insert(matches, recipe.name)
					goto continue
				end
			end
		elseif category_name == "crafting" then
			table.insert(matches, recipe.name)
		end
		::continue::
	end
	return matches
end

---@param result_name string Name of the result to search for
---@return table recipes All recipes with the given result
function fds_recipe.find_by_result(result_name)
	local matches = {}
	for _,recipe in pairs(data.raw.recipe) do
		for _,result in pairs(recipe.results or {}) do
			if result.name == result_name then
				table.insert(matches, recipe.name)
				goto continue
			end
		end
		::continue::
	end
	return matches
end

------------------------------------------------------------------------------- Categories

---comment
---@param recipe_in any
---@param category_name any
---@return boolean
function fds_recipe.has_category(recipe_in, category_name)
	local recipe = find_recipe(recipe_in)
	if recipe then
		if recipe.categories == nil then
			return category_name == "crafting"
		end
		for _,category in pairs(recipe.categories) do
			if category == category_name then
				return true
			end
		end
	end
	return false
end

---Check
---@param recipe_in string|table Recipe to check. Either a RecipePrototype or 
---@param category_map table A table with [value] == true. A list can be converted to a map with util.list_to_map from the __core__.lua
---@return boolean Whether the 
function fds_recipe.has_any_category(recipe_in, category_map)
	local recipe = find_recipe(recipe_in)
	fds_assert.ensure(type(category_map) == "table")
	if recipe then
		if recipe.categories == nil then
			return (category_map["crafting"] == true)
		end
		for _,category in pairs(recipe.categories) do
			if category_map[category] == true then
				return true
			end
		end
	end
	return false
end

function fds_recipe.add_category(recipe_in, category_name)
	local recipe = find_recipe(recipe_in)
	fds_assert.ensure(data.raw["recipe-category"][category_name], "fds_recipe.add_category: Recipe category `%s` does not exist.", category_name)
	if recipe and not fds_recipe.has_category(recipe, category_name) then
		if not recipe.categories then
			recipe.categories = {"crafting"}
		end
		table.insert(recipe.categories, category_name)
		return recipe.categories
	end
end

---@param allow_empty boolean|nil If true, will allow the categories table to be {}, which is invalid
function fds_recipe.remove_category(recipe_in, category_name, allow_empty)
	local recipe = find_recipe(recipe_in)
	if recipe then
		if recipe.categories then
			for i,recipe_category in pairs(recipe.categories) do
				if category_name == recipe_category then
					table.remove(recipe.categories, i)
					if #recipe.categories == 0 and allow_empty ~= true then
						recipe.categories = nil
					end
					return true
				end
			end
		elseif category_name == "crafting" and allow_empty then
			recipe.categories = {}
		end
	end
	return false
end

function fds_recipe.replace_category(recipe_in, old_category, new_category)
	local recipe = find_recipe(recipe_in)
	fds_assert.ensure(data.raw["recipe-category"][new_category], "fds_recipe.replace_category: Recipe category `%s` does not exist.", new_category)
	if recipe then
		if recipe.categories then
			for i,category in pairs(recipe.categories) do
				if category == old_category then
					recipe.categories[i] = new_category
					return true
				end
			end
		elseif old_category == "crafting" then
			recipe.categories = {new_category}
			return true
		end
	end
	return false
end

-- Prefer to use the above, such as replace_category("recipe", "crafting", "hand-crafting")
function fds_recipe.set_categories(recipe_in, categories)
	local recipe = find_recipe(recipe_in)
	if recipe then
		recipe.categories = categories
	end
end

------------------------------------------------------------------------------- Crafting time

function fds_recipe.scale_time(recipe_in, time_scalar)
	local recipe = find_recipe(recipe_in)
	if recipe then
		recipe.energy_required = (recipe.energy_required or 0.5) * time_scalar
	end
end

function fds_recipe.add_time(recipe_in, time_to_add)
	local recipe = find_recipe(recipe_in)
	if recipe then
		recipe.energy_required = (recipe.energy_required or 0.5) + time_to_add
	end
end

function fds_recipe.set_time(recipe_in, new_time)
	local recipe = find_recipe(recipe_in)
	if recipe then
		recipe.energy_required = new_time
	end
end

------------------------------------------------------------------------------- Ingredients

-- Gets the ingredient from the recipe, if it exists.
--  recipe_in (RecipeID string OR table): Name of the recipe (eg "iron-gear-wheel") or the recipe itself.
--  ingredient_name (ItemID or FluidID string): Name of ingredient to find.
-- return (index, IngredientPrototype or nil): IngredientPrototype if it exists, otherwise nil.
function fds_recipe.get_ingredient(recipe_in, ingredient_name)
	assert(type(ingredient_name) == "string")
	local recipe, recipe_name = find_recipe(recipe_in)
	assert(recipe or not FDS_ASSERT, string.format("fds_recipe.get_ingredient: recipe `%s` does not exist.", recipe_name))
	if recipe and recipe.ingredients then
		for index,ingredient in pairs(recipe.ingredients) do
			if ingredient.name == ingredient_name then
				return index,ingredient
			end
		end
	end
	return nil,nil
end

-- Adds the provided ingredient to the given recipe.
--  recipe_in (RecipeID string OR table): Name of the recipe, (eg "iron-gear-wheel") or the recipe itself. Nothing happens if the recipe is not defined. Will assert if FDS_ASSERT is true.
--  new_ingredient (IngredientPrototype struct): IngredientPrototype to add.
--  allow_combine (optional, boolean): If false, will assert if a conflicting ingredient exists.
--  index (optional, int): If set and new_ingredient is unique, inserts the ingredient at this index.
function fds_recipe.add_ingredient(recipe_in, new_ingredient, allow_combine, index)
	assert(type(new_ingredient) == "table", string.format("fds_recipe.add_ingredient: new_ingredient for `%s` must be an IngredientPrototype.", recipe_name))
	local recipe, recipe_name = find_recipe(recipe_in)
	assert(recipe or not FDS_ASSERT, string.format("fds_recipe.add_ingredient: recipe `%s` does not exist.", recipe_name))
	if recipe then
		local _,conflict = fds_recipe.get_ingredient(recipe_in, new_ingredient.name)
		if conflict then
			assert(allow_combine ~= false, string.format("fds_recipe.replace_ingredient: recipe `%s` has a conflicting ingredient `%s` that already exists.", recipe_name, conflict.name))
			conflict.amount = conflict.amount + new_ingredient.amount
		else
			if type(index) == "number" then
				table.insert(recipe.ingredients, index, new_ingredient)
			else
				table.insert(recipe.ingredients, new_ingredient)
			end
		end
	end
end

-- Changes a set of variables on the given ingredient.
--  recipe_in (RecipeID string OR table): Name of the recipe or the recipe itself.
--  ingredient_name (ItemID or FluidID string): Name of the ingredient.
--  modifiers (dictionary): Map of values to change. e.g. {amount=0, min_temperature=9999}
function fds_recipe.modify_ingredient(recipe_in, ingredient_name, modifiers)
	assert(type(modifiers) == "table")
	local recipe, recipe_name = find_recipe(recipe_in)
	local _,ingredient = fds_recipe.get_ingredient(recipe_in, ingredient_name)
	assert(ingredient or not FDS_ASSERT, string.format("fds_recipe.modify_ingredient: recipe `%s` does not have ingredient `%s`.", recipe_name, ingredient_name))
	if ingredient then
		for key,val in pairs(modifiers) do
			ingredient[key] = val
		end
	end
end

-- 
function fds_recipe.scale_ingredient(recipe_in, ingredient_name, scalars)
	local _,ingredient = fds_recipe.get_ingredient(recipe_in, ingredient_name)
	if ingredient then
		for key,scalar in pairs(scalars) do
			assert(type(scalar) == "number")
			assert(type(ingredient[key]) == "number" or not FDS_ASSERT)
			ingredient[key] = ingredient[key] * scalar
		end
	end
end

function fds_recipe.scale_ingredients(recipe_in, scalars)
	local recipe, recipe_name = find_recipe(recipe_in)
	if recipe and recipe.ingredients then
		for key,scalar in pairs(scalars) do
			fds_assert.ensure(type(scalar) == "number", "fds_recipe.scale_ingredients: scalar `%s` is not a number.", key)
			for _,ingredient in pairs(recipe.ingredients) do
				if type(ingredient[key]) == "number" then
					ingredient[key] = ingredient[key] * scalar
				end
			end
		end
	end
end

-- Adds the provided ingredient to the given recipe.
--  recipe_in (RecipeID string OR table): Name of the recipe, (eg "iron-gear-wheel") or the recipe itself. Nothing happens if the recipe is not defined. Will assert if FDS_ASSERT is true.
--  old_ingredient_name (ItemID or FluidID string): Name of ingredient to replace (eg "iron-plate")
--  new_ingredient (string or IngredientPrototype): Ingredient to replace with. If an IngredientPrototype is provided, replaces the whole thing. If a string, changes the ingredient name.
--  allow_combine (optional, boolean): If false, will assert if an existing ingredient conflicts with new_ingredient. If FDS_ASSERT is set, allow_combine must be true to avoid assert.
function fds_recipe.replace_ingredient(recipe_in, old_ingredient_name, new_ingredient, no_combine)
	local recipe, recipe_name = find_recipe(recipe_in)
	assert(recipe or not FDS_ASSERT, string.format("fds_recipe.replace_ingredient: recipe `%s` does not exist.", recipe_name))
	if recipe then
		local old_index,old_ingredient = fds_recipe.get_ingredient(recipe_in, old_ingredient_name)
		assert(not FDS_ASSERT or (type(old_ingredient) == "table" and old_index ~= nil), string.format("fds_recipe.replace_ingredient: recipe `%s` does not have ingredient `%s`.", recipe_name, old_ingredient_name))
		
		if old_index and old_ingredient then
			local is_full_replace = type(new_ingredient) == "table"
			local _,conflict = fds_recipe.get_ingredient(recipe_in, is_full_replace and new_ingredient.name or new_ingredient)

			if conflict then
				assert(no_combine ~= true and (no_combine == false or not FDS_ASSERT), "fds_recipe.replace_ingredient: recipe `%s` has a conflicting ingredient `%s` that already exists.", recipe_name, conflict.name)
				conflict.amount = conflict.amount + (is_full_replace and new_ingredient.amount or old_ingredient.amount)
				table.remove(recipe.ingredients, old_index)
			else
				if is_full_replace then
					recipe.ingredients[old_index] = new_ingredient
				else
					old_ingredient.name = new_ingredient
				end
			end
		end
	end
end

-- Splits the old ingredient into the new set of ingredients.
--   recipe_in: Name of the recipe or the recipe itself.
--   old_ingredient_name (ItemID or FluidID string): Name of the ingredient to split.
--   new_ingredients (table of strings and/or [string]=value pairs): Names of the ingredients to split the given ingredient into.
--     Entries that are a string key and number value use the number specified as the split factor (% with range [0,1]).
--     The original ingredient CAN be included in this.
--   allow_combine (optional, boolean)
function fds_recipe.split_ingredient(recipe_in, old_ingredient_name, new_ingredients, no_combine)
	local recipe, recipe_name = find_recipe(recipe_in)
	assert(recipe or not FDS_ASSERT, string.format("fds_recipe.split_ingredient: recipe `%s` does not exist.", recipe_name))
	if recipe then
		local old_index,old_ingredient = fds_recipe.get_ingredient(recipe_in, old_ingredient_name)
		if old_index and old_ingredient then
			-- Deepcopy
			old_ingredient = util.table.deepcopy(old_ingredient)

			local default_split_factor = 1 / table_size(new_ingredients)
			local default_split_amount = math.ceil(default_split_factor * old_ingredient.amount)
			local old_unused = true
			local insert_index = old_index + 1
			for split_key,split_value in pairs(new_ingredients) do
				-- Get the split amount if the split factor is specified for this ingredient
				-- Otherwise, use the default split amount
				local has_split_factor = (type(split_key) == "string" and type(split_value) == "number")
				local split_amount = has_split_factor and math.ceil(split_value * old_ingredient.amount) or default_split_amount

				-- Add the split amount to the recipe, either by combining with existing ingredients or adding to the recipe
				local new_ingredient_name = has_split_factor and split_key or split_value
				fds_assert.ensure(type(new_ingredient_name) == "string")
				local _,conflict = fds_recipe.get_ingredient(recipe_in, new_ingredient_name)
				if conflict then
					if new_ingredient_name == old_ingredient_name then
						old_unused = false
						conflict.amount = split_amount
						-- Don't increment insert_index in this case
					else
						assert(no_combine == false)
						conflict.amount = conflict.amount + split_amount
						insert_index = insert_index + 1
					end
				else
					local new_ingredient_prototype = util.table.deepcopy(old_ingredient)
					new_ingredient_prototype.name = new_ingredient_name
					new_ingredient_prototype.amount = split_amount
					table.insert(recipe.ingredients, insert_index, new_ingredient_prototype)
					insert_index = insert_index + 1
				end
			end

			-- Remove the old ingredient after we're done copying it
			if old_unused then
				table.remove(recipe.ingredients, old_index)
			end
		end
	end
end

-- Removes the provided ingredient from the given recipe.
--  recipe_in (RecipeID string OR table): Name of the recipe (eg "iron-gear-wheel") or the recipe itself. Nothing happens if the recipe is not defined. Will assert if FDS_ASSERT is true.
--  ingredient_name (ItemID or FluidID string): Name of the ingredient to remove.
function fds_recipe.remove_ingredient(recipe_in, ingredient_name)
	local recipe, recipe_name = find_recipe(recipe_in)
	assert(recipe or not FDS_ASSERT, string.format("fds_recipe.remove_ingredient: recipe `%s` does not exist.", recipe_name))
	if recipe then
		for i,ingredient in pairs(recipe.ingredients) do
			if ingredient.name == ingredient_name then
				table.remove(recipe.ingredients, i)
				return true
			end
		end
		assert(not FDS_ASSERT, string.format("fds_recipe.remove_ingredient: recipe `%s` does not have ingredient `%s`", recipe_name, ingredient_name))
	end
	return false
end

-------------------------------------------------------------------------- Results

-- Gets the result from the recipe, if it exists.
--  recipe_in (RecipeID string OR table): Name of the recipe (eg "iron-gear-wheel") or the recipe itself.
--  result_name (ItemID or FluidID string): Name of result to find.
-- return (index, ResultPrototype or nil): ResultPrototype if it exists, otherwise nil.
function fds_recipe.get_result(recipe_in, result_name)
	assert(type(result_name) == "string")
	local recipe, recipe_name = find_recipe(recipe_in)
	if recipe then
		for index,result in pairs(recipe.results or {}) do
			if result.name == result_name then
				return index,result
			end
		end
	end
	return nil
end

-- Adds the provided result to the given recipe.
--  recipe_in (RecipeID string OR table): Name of the recipe, (eg "iron-gear-wheel") or the recipe itself. Nothing happens if the recipe is not defined. Will assert if FDS_ASSERT is true.
--  new_result (ResultPrototype table): ResultPrototype to add.
--  allow_combine (optional, boolean): If false, will assert if a conflicting result exists.
--  new_index (optional, int): If set and new_result is unique, inserts the result at this index.
function fds_recipe.add_result(recipe_in, new_result, allow_combine, new_index)
	assert(type(new_result) == "table", string.format("fds_recipe.add_result: new_result must be an ResultPrototype"))
	local recipe, recipe_name = find_recipe(recipe_in)
	if recipe then
		local _,conflict = fds_recipe.get_result(recipe_name, new_result.name)
		if conflict then
			assert(allow_combine ~= false, string.format("fds_recipe.add_result: recipe `%s` has a conflicting result `%s` that already exists", recipe_name, conflict.name))
			conflict.amount = conflict.amount + new_result.amount
		else
			if type(new_index) == "number" then
				table.insert(recipe.results, new_index, new_result)
			else
				table.insert(recipe.results, new_result)
			end
			return result
		end
	end
end

-- Changes a set of variables on the given result.
--  recipe_in (RecipeID string OR table): Name of the recipe or the recipe itself.
--  result_name (ItemID or FluidID string): Name of the result.
--  modifiers (dictionary of ProductPrototype values): Map of values to change. e.g. {amount=0, amount_min=0, amount_max=10}
function fds_recipe.modify_result(recipe_in, result_name, modifiers)
	assert(type(modifiers) == "table")
	local _,result = fds_recipe.get_result(recipe_in, result_name)
	local recipe, recipe_name = find_recipe(recipe_in)
	assert(result or not FDS_ASSERT, string.format("fds_recipe.modify_result: recipe `%s` does not have result `%s`.", recipe_name, result_name))
	if result then
		for key,val in pairs(modifiers) do
			result[key] = val
			return result
		end
	end
end

-- 
function fds_recipe.scale_result(recipe_in, result_name, scalars)
	local _,result = fds_recipe.get_result(recipe_in, result_name)
	if result then
		for key,scalar in pairs(scalars) do
			assert(type(scalar) == "number")
			assert(type(result[key]) == "number" or not FDS_ASSERT)
			result[key] = result[key] * scalar
			return result
		end
	end
end

--- Replaces.
-- @param1 recipe_in (RecipeID string OR table): Name of the recipe, (eg "iron-gear-wheel") or the recipe itself. Nothing happens if the recipe is not defined. Will assert if FDS_ASSERT is true.
--  old_result_name (ItemID or FluidID string): Name of result to replace (eg "iron-plate")
--  new_result (string OR table): Result to replace with. If an ResultPrototype is provided, replaces the whole thing. If a string, changes the result name.
--  no_combine (optional, boolean): If false, will assert if an existing result conflicts with new_result. If FDS_ASSERT is set, allow_combine must be true to avoid assert.
function fds_recipe.replace_result(recipe_in, old_result_name, new_result, no_combine)
	local recipe, recipe_name = find_recipe(recipe_in)
	if recipe then
		local old_index,old_result = fds_recipe.get_result(recipe_in, old_result_name)
		assert(not FDS_ASSERT or (type(old_result) == "table" and old_index ~= nil), string.format("fds_recipe.replace_result: recipe `%s` does not have result `%s`", recipe_name, old_result_name))

		if old_index and old_result then
			local is_full_replace = type(new_result) == "table"
			local _,conflict = fds_recipe.get_result(recipe_name, is_full_replace and new_result.name or new_result)

			if conflict then
				assert(no_combine ~= true and (no_combine == false or not FDS_ASSERT), string.format("fds_recipe.replace_result: recipe `%s` has a conflicting result `%s` that already exists", recipe_name, conflict.name))
				conflict.amount = conflict.amount + (is_full_replace and new_result.amount or old_result.amount)
				table.remove(recipe.results, old_index)
				return conflict
			else
				if is_full_replace then
					recipe.results[old_index] = new_result
					return new_result
				else
					old_result.name = new_result
					return old_result
				end
			end
		end
	end
end

function fds_recipe.reorder_result(recipe_in, result_name, new_index)
	local recipe, recipe_name = find_recipe(recipe_in)
	if recipe then
		for i,result in pairs(recipe.results or {}) do
			if result.name == result_name then
				table.insert(recipe.results, new_index, result)
				if new_index <= i then
					table.remove(recipe.results, i + 1)
				end
				return true
			end
		end
	end
	return false
end

-- Removes the provided result from the given recipe.
--  recipe_name (RecipeID string): Name of the recipe (eg "iron-gear-wheel"). Nothing happens if the recipe is not defined. Will assert if FDS_ASSERT is true.
--  result_name (ItemID or FluidID string): Name of the result to remove.
function fds_recipe.remove_result(recipe_in, result_name)
	local recipe, recipe_name = find_recipe(recipe_in)
	assert(recipe or not FDS_ASSERT, string.format("fds_recipe.remove_result: recipe `%s` does not exist.", recipe_name))
	if recipe then
		for i,result in pairs(recipe.results) do
			if result.name == result_name then
				table.remove(recipe.results, i)
				return true
			end
		end
		assert(not FDS_ASSERT, "fds_recipe.remove_result: recipe `%s` does not have result `%s`", recipe_name, result_name)
	end
	return false
end

-------------------------------------------------------------------------- Shared probability

---Gets all shared probability ranges that do not yield any results.
---@param recipe_in table|string Name of the recipe, or the RecipePrototype itself.
---@return table|nil unused_ranges Ranges that are free for other results to be added to.
function fds_recipe.get_unused_shared_probability(recipe_in)
	local recipe, recipe_name = find_recipe(recipe_in)
	if recipe then
		local unused_ranges = {{min=0.0, max=1.0}}
		local new_ranges = {}
		for _,result in pairs(recipe.results or {}) do
			if result.shared_probability then
				::restart::
				for i=1,#unused_ranges do
					local range = unused_ranges[i]
					-- If there is any intersection
					if result.shared_probability.max >= range.min and result.shared_probability.min <= range.max then
						local union = {
							min=math.max(result.shared_probability.min, range.min),
							max=math.min(result.shared_probability.max, range.max),
						}
						if union.max - union.min <= 0 then goto continue end
						if union.min > range.min then
							table.insert(unused_ranges, {min=range.min, max=union.min})
						end
						if union.max < range.max then
							table.insert(unused_ranges, {min=union.max, max=range.max})
						end
						table.remove(unused_ranges, i)
						goto restart
					end
					::continue::
				end
			end
		end
		local total = 0
		for _,range in pairs(unused_ranges) do
			total = total + (range.max - range.min)
		end
		unused_ranges.total = total
		return unused_ranges
	end
	return nil
end

---Defragment the shared probability ranges to increase the amount of contiguous probability space.
---Biases everything to start at 0, and will not break any overlaps of shared probability ranges between results.
---@param recipe_in string|table The recipe to defragment, if it has shared probabilities.
---@param in_unused_ranges nil|table Pre-calculated unused ranges (from get_unused_shared_probability).
function fds_recipe.optimize_shared_probability(recipe_in, in_unused_ranges)
	local recipe, recipe_name = find_recipe(recipe_in)
	if recipe then
		local unused_ranges = in_unused_ranges or fds_recipe.get_unused_shared_probability(recipe)
		assert(unused_ranges)
		-- TODO: Could be optimized further by walking the results and ranges in a shared loop, accumulating the amount of shift needed as we go
		if unused_ranges.total > 0 and unused_ranges.total < 1 then
			for i=#unused_ranges,1,-1 do
				local  range = unused_ranges[i]
				local range_size =  range.max - range.min
				for _,result in pairs(recipe.results) do
					if result.shared_probability and result.shared_probability.min >= range.max then
						result.shared_probability.min = result.shared_probability.min - range_size
						result.shared_probability.max = result.shared_probability.min - range_size
					end
				end
			end
		end
	end
end

---Add a shared probability result with the given total probability.
---Best practice is to remove unwanted shared probability results before adding new ones.
---@param recipe_in string|table The recipe to modify.
---@param result_in table The ResultPrototype to add, excluding the shared_probability.
---@param probability number The size of the probability range for the new result (max - min).
---@param allow_optimizing nil|boolean Auto-optimize probabilities if the result CAN be added, but the range is too fragmented.
---@return table|nil shared_probability The shared probability range of the recipe added, if successful.
function fds_recipe.add_shared_probability_result(recipe_in, result_in, probability, allow_optimizing)
	assert(type(result_in) == "table" or type(result_in) == "string")
	assert(type(probability) == "number" and probability > 0 and probability < 1)
	local recipe, recipe_name = find_recipe(recipe_in)
	if recipe then
		local unused_ranges = fds_recipe.get_unused_shared_probability(recipe)
		assert(unused_ranges)
		if unused_ranges.total < probability then
			return nil
		end
		local best_range_index = nil
		local best_range_size = 1
		for i,range in ipairs(unused_ranges) do
			local range_size = range.max - range.min
			-- Prefer filling smaller ranges
			if range_size >= probability and range_size < best_range_size then
				best_range_index = i
				best_range_size = range_size
			end
		end
		local range_start = nil
		if best_range_index then
			range_start = unused_ranges[best_range_index].min
		elseif allow_optimizing ~= false then
			fds_recipe.optimize_shared_probability(recipe, unused_ranges)
			range_start = 1 - unused_ranges.total
		end
		if range_start then
			local new_result = util.table.deepcopy(result_in)
			new_result.shared_probability = {
				min = range_start,
				max = range_start + probability
			}
			table.insert(recipe.results, new_result)
			return new_result.shared_probability
		end
	end
	return nil
end

-------------------------------------------------------------------------- Shared

function fds_recipe.get_surface_condition(recipe_in, property_name)
	local recipe = find_recipe(recipe_in)
	return recipe and fds_shared.get_surface_condition(recipe, property_name) or nil
end

function fds_recipe.set_surface_condition(recipe_in, new_property)
	local recipe = find_recipe(recipe_in)
	if recipe then
		fds_shared.set_surface_condition(recipe, new_property)
	end
end

function fds_recipe.remove_surface_condition(recipe_in, property_name)
	local recipe = find_recipe(recipe_in)
	if recipe then
		return fds_shared.remove_surface_condition(recipe, property_name)
	end
	return false
end

--------------------------------------------------------------------------

return fds_recipe
