local fds_assert = require("lib.assert")

local fds_recipe = {}

-------------------------------------------------------------------------- Find recipes

function fds_recipe.find(recipe_name, required)
  local recipe = data.raw.recipe[recipe_name]
  fds_assert.ensure_if(recipe, required, "fds_recipe.find: Required recipe `%s` is missing.", recipe_name)
  return recipe
end

function fds_recipe.find_by_ingredient(ingredient_name)
  local matches = {}
  for _,recipe in pairs(data.raw.recipe) do
    for _,ingredient in pairs(recipe.ingredients or {}) do
      if ingredient.name == ingredient_name then
        table.insert(matches, recipe.name)
      end
    end
  end
  return matches
end

function fds_recipe.find_by_result(result_name)
  local matches = {}
  for _,recipe in pairs(data.raw.recipe) do
    if #recipe.results > 0 then
      for _,result in pairs(recipe.results) do
        if result.name == result_name then
          table.insert(matches, recipe.name)
        end
      end
    end
  end
  return matches
end

-------------------------------------------------------------------------- General

-- Does not change RecipePrototype.category, so should not prevent the recipe from being used in existing machines
-- Requires new API feature from 2.0.49
function fds_recipe.add_category(recipe_name, additional_category)
  local recipe = data.raw.recipe[recipe_name]
  fds_assert.ensure(data.raw["recipe-category"][additional_category], "fds_recipe.add_category: Recipe category %s does not exist.", additional_category)
  if recipe then
    if not recipe.additional_categories then
      recipe.additional_categories = {additional_category}
    else
      table.insert(recipe.additional_categories, additional_category)
    end
    return recipe.additional_categories
  end
end

function fds_recipe.change_time(recipe_name, modifiers)
  assert(type(modifiers) == "table")
  local recipe = data.raw.recipe[recipe_name]
  assert(recipe or not FDS_ASSERT, string.format("fds_recipe.change_time: recipe `%s` does not exist.", recipe_name))
  if recipe then
    local energy_required = recipe.energy_required or 0.5
    if type(modifiers.scale) == "number" then
      energy_required = modifiers.scale * energy_required
    end
    if type(modifiers.add) == "number" then
      energy_required = energy_required + modifiers.add
    end
    recipe.energy_required = energy_required
  end
end

-------------------------------------------------------------------------- Ingredients

-- Gets the ingredient from the recipe, if it exists.
--  recipe_name (RecipeID string): Name of the recipe (eg "iron-gear-wheel").
--  ingredient_name (ItemID or FluidID string): Name of ingredient to find.
-- return (index, IngredientPrototype or nil): IngredientPrototype if it exists, otherwise nil.
function fds_recipe.get_ingredient(recipe_name, ingredient_name)
  assert(type(ingredient_name) == "string")
  local recipe = data.raw.recipe[recipe_name]
  assert(recipe or not FDS_ASSERT, string.format("fds_recipe.get_ingredient: recipe `%s` does not exist.", recipe_name))
  if recipe and recipe.ingredients then
    for index,ingredient in pairs(recipe.ingredients) do
      if ingredient.name == ingredient_name then
        return index,ingredient
      end
    end
  end
  return nil
end

-- Adds the provided ingredient to the given recipe.
--  recipe_name (RecipeID string): Name of the recipe, (eg "iron-gear-wheel"). Nothing happens if the recipe is not defined. Will assert if FDS_ASSERT is true.
--  new_ingredient (IngredientPrototype struct): IngredientPrototype to add.
--  allow_combine (optional, boolean): If false, will assert if a conflicting ingredient exists.
--  index (optional, int): If set and new_ingredient is unique, inserts the ingredient at this index.
function fds_recipe.add_ingredient(recipe_name, new_ingredient, allow_combine, index)
  assert(type(new_ingredient) == "table", string.format("fds_recipe.add_ingredient: new_ingredient for `%s` must be an IngredientPrototype.", recipe_name))
  local recipe = data.raw.recipe[recipe_name]
  assert(recipe or not FDS_ASSERT, string.format("fds_recipe.add_ingredient: recipe `%s` does not exist.", recipe_name))
  if recipe then
    local _,conflict = fds_recipe.get_ingredient(recipe_name, new_ingredient.name)
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
--  recipe_name (RecipeID string): Name of the recipe.
--  ingredient_name (ItemID or FluidID string): Name of the ingredient.
--  modifiers (dictionary): Map of values to change. e.g. {amount=0, min_temperature=9999}
function fds_recipe.modify_ingredient(recipe_name, ingredient_name, modifiers)
  assert(type(modifiers) == "table")
  local _,ingredient = fds_recipe.get_ingredient(recipe_name, ingredient_name)
  assert(ingredient or not FDS_ASSERT, string.format("fds_recipe.modify_ingredient: recipe `%s` does not have ingredient `%s`.", recipe_name, ingredient_name))
  if ingredient then
    for key,val in pairs(modifiers) do
      ingredient[key] = val
    end
  end
end

-- 
function fds_recipe.scale_ingredient(recipe_name, ingredient_name, scalars)
  local _,ingredient = fds_recipe.get_ingredient(recipe_name, ingredient_name)
  if ingredient then
    for key,scalar in pairs(scalars) do
      assert(type(scalar) == "number")
      assert(type(ingredient[key]) == "number" or not FDS_ASSERT)
      ingredient[key] = ingredient[key] * scalar
    end
  end
end

-- Adds the provided ingredient to the given recipe.
--  recipe_name (RecipeID string): Name of the recipe, (eg "iron-gear-wheel"). Nothing happens if the recipe is not defined. Will assert if FDS_ASSERT is true.
--  old_ingredient_name (ItemID or FluidID string): Name of ingredient to replace (eg "iron-plate")
--  new_ingredient (string or IngredientPrototype): Ingredient to replace with. If an IngredientPrototype is provided, replaces the whole thing. If a string, changes the ingredient name.
--  allow_combine (optional, boolean): If false, will assert if an existing ingredient conflicts with new_ingredient. If FDS_ASSERT is set, allow_combine must be true to avoid assert.
function fds_recipe.replace_ingredient(recipe_name, old_ingredient_name, new_ingredient, no_combine)
  local recipe = data.raw.recipe[recipe_name]
  assert(recipe or not FDS_ASSERT, string.format("fds_recipe.replace_ingredient: recipe `%s` does not exist.", recipe_name))
  if recipe then
    local old_index,old_ingredient = fds_recipe.get_ingredient(recipe_name, old_ingredient_name)
    assert(not FDS_ASSERT or (type(old_ingredient) == "table" and old_index ~= nil), string.format("fds_recipe.replace_ingredient: recipe `%s` does not have ingredient `%s`.", recipe_name, old_ingredient_name))
    
    if old_index and old_ingredient then
      local is_full_replace = type(new_ingredient) == "table"
      local _,conflict = fds_recipe.get_ingredient(recipe_name, is_full_replace and new_ingredient.name or new_ingredient)

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

-- Removes the provided ingredient from the given recipe.
--  recipe_name (RecipeID string): Name of the recipe (eg "iron-gear-wheel"). Nothing happens if the recipe is not defined. Will assert if FDS_ASSERT is true.
--  ingredient_name (ItemID or FluidID string): Name of the ingredient to remove.
function fds_recipe.remove_ingredient(recipe_name, ingredient_name)
  local recipe = data.raw.recipe[recipe_name]
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
--  recipe_name (RecipeID string): Name of the recipe (eg "iron-gear-wheel").
--  result_name (ItemID or FluidID string): Name of result to find.
-- return (index, ResultPrototype or nil): ResultPrototype if it exists, otherwise nil.
function fds_recipe.get_result(recipe_name, result_name)
  assert(type(result_name) == "string")
  local recipe = data.raw.recipe[recipe_name]
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
--  recipe_name (RecipeID string): Name of the recipe, (eg "iron-gear-wheel"). Nothing happens if the recipe is not defined. Will assert if FDS_ASSERT is true.
--  new_result (ResultPrototype table): ResultPrototype to add.
--  allow_combine (optional, boolean): If false, will assert if a conflicting result exists.
--  new_index (optional, int): If set and new_result is unique, inserts the result at this index.
function fds_recipe.add_result(recipe_name, new_result, allow_combine, new_index)
  assert(type(new_result) == "table", string.format("fds_recipe.add_result: new_result must be an ResultPrototype"))
  local recipe = data.raw.recipe[recipe_name]
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
--  recipe_name (RecipeID string): Name of the recipe.
--  result_name (ItemID or FluidID string): Name of the result.
--  modifiers (dictionary of ProductPrototype values): Map of values to change. e.g. {amount=0, amount_min=0, amount_max=10}
function fds_recipe.modify_result(recipe_name, result_name, modifiers)
  assert(type(modifiers) == "table")
  local _,result = fds_recipe.get_result(recipe_name, result_name)
  assert(result or not FDS_ASSERT, string.format("fds_recipe.modify_result: recipe `%s` does not have result `%s`.", recipe_name, result_name))
  if result then
    for key,val in pairs(modifiers) do
      result[key] = val
      return result
    end
  end
end

-- 
function fds_recipe.scale_result(recipe_name, result_name, scalars)
  local _,result = fds_recipe.get_result(recipe_name, result_name)
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
-- @param1 recipe_name (RecipeID string): Name of the recipe, (eg "iron-gear-wheel"). Nothing happens if the recipe is not defined. Will assert if FDS_ASSERT is true.
--  old_result_name (ItemID or FluidID string): Name of result to replace (eg "iron-plate")
--  new_result (string OR table): Result to replace with. If an ResultPrototype is provided, replaces the whole thing. If a string, changes the result name.
--  no_combine (optional, boolean): If false, will assert if an existing result conflicts with new_result. If FDS_ASSERT is set, allow_combine must be true to avoid assert.
function fds_recipe.replace_result(recipe_name, old_result_name, new_result, no_combine)
  local recipe = data.raw.recipe[recipe_name]
  if recipe then
    local old_index,old_result = fds_recipe.get_result(recipe_name, old_result_name)
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

function fds_recipe.reorder_result(recipe_name, result_name, new_index)
  local recipe = data.raw.recipe[recipe_name]
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
function fds_recipe.remove_result(recipe_name, result_name)
  local recipe = data.raw.recipe[recipe_name]
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

-------------------------------------------------------------------------- Shared

local fds_shared = require("__fdsl__.lib.shared")

function fds_recipe.get_surface_condition(recipe_name, property_name)
  local recipe = data.raw.recipe[recipe_name]
  return recipe and fds_shared.get_surface_condition(recipe, property_name) or nil
end

function fds_recipe.set_surface_condition(recipe_name, new_property)
  local recipe = data.raw.recipe[recipe_name]
  if recipe then
    fds_shared.set_surface_condition(recipe, new_property)
  end
end

function fds_recipe.remove_surface_condition(recipe_name, property_name)
  local recipe = data.raw.recipe[recipe_name]
  if recipe then
    return fds_shared.remove_surface_condition(recipe, property_name)
  end
  return false
end

--------------------------------------------------------------------------

return fds_recipe
