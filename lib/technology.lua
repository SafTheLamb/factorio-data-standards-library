local fds_assert = require("lib.assert")

local fds_technology = {}

-------------------------------------------------------------------------- General

function fds_technology.find(tech_name, required)
  local technology = data.raw.technology[tech_name]
  fds_assert.ensure_if(technology, required, "fds_technology.find: Required technology `%s` does not exist", tech_name)
  return technology
end

function fds_technology.find_by_unlock(recipe_name, required)
  local matches = {}
  for _,technology in pairs(data.raw.technology) do
    for _,effect in pairs(technology.effects or {}) do
      if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
        table.insert(matches, technology.name)
      end
    end
  end
  fds_assert.ensure_if(next(matches) ~= nil, required, "fds_technology.find_by_unlock: No technology with unlock `%s` exists when required", recipe_name)
  return matches
end

function fds_technology.find_by_prereq(prereq_name, required)
  local matches = {}
  for _,technology in pairs(data.raw.technology) do
    for _,prereq in pairs(technology.prerequisites or {}) do
      if prereq == prereq_name then
        table.insert(matches, technology.name)
      end
    end
  end
  fds_assert.ensure_if(next(matches) ~= nil, required, "fds_technology.find_by_prereq: No technology with prerequisite `%s` exists when required", prereq_name)
  return matches
end

-------------------------------------------------------------------------- Technology modifying

-- merge_technology

-- remove_technology ()

-------------------------------------------------------------------------- Prerequisites

function fds_technology.has_prereq(tech_name, prereq_name)
  local technology = data.raw.technology[tech_name]
  fds_assert.ensure(technology, "fds_technology.has_prereq: Technology `%s` does not exist", tech_name)
  for _,prereq in pairs(technology.prerequisites) do
    if prereq == prereq_name then
      return true
    end
  end
  return false
end

function fds_technology.has_prereq_recursive(tech_name, prereq_name)
  fds_assert.ensure(data.raw.technology[tech_name], "fds_technology.has_prereq_recursive: Technology `%s` does not exist", tech_name)
  local open_list = {tech_name}
  local visit_list = {}
  local i = 0
  while i < #open_list do
    i = i + 1
    local visit_name = open_list[i]
    local visit_tech = data.raw.technology[visit_name]
    if visit_tech and not visit_list[visit_name] then
      visit_list[visit_name] = true
      if visit_name == prereq_name then
        return true
      end
      for _,visit_prereq in pairs(visit_tech.prerequisites or {}) do
        table.insert(open_list, visit_prereq)
      end
    end
  end
  return false
end

function fds_technology.add_prereq(tech_name, prereq_name)
  local technology = data.raw.technology[tech_name]
  local prerequisite = data.raw.technology[prereq_name]
  assert(prerequisite or not FDS_ASSERT)
  if technology and prerequisite then
    if technology.prerequisites then
      table.insert(technology.prerequisites, prereq_name)
    else
      technology.prerequisites = {prereq_name}
    end
  end
  return technology.prerequisites
end

function fds_technology.replace_prereq(tech_name, old_prereq_name, new_prereq_name)
  local technology = data.raw.technology[tech_name]
  local prerequisite = data.raw.technology[new_prereq_name]
  if technology and prerequisite and technology.prerequisites then
    for i,prereq in pairs(technology.prerequisites) do
      if prereq == old_prereq_name then
        prereq = new_prereq_name
        return true
      end
    end
  end
end

function fds_technology.remove_prereq(tech_name, prereq_name)
  local technology = data.raw.technology[tech_name]
  if technology and technology.prerequisites then
    for i,prereq in pairs(technology.prerequisites) do
      if prereq == prereq_name then
        table.remove(technology.prerequisites, i)
        if #technology.prerequisites == 0 then
          technology.prerequisites = nil
        end
        return true
      end
    end
  end
end

-- move_prereq(old_tech_name, new_tech_name, prereq_name)

-------------------------------------------------------------------------- Effects

function fds_technology.add_effect(tech_name, effect, index)
  local technology = data.raw.technology[tech_name]
  if technology then
    if not technology.effects then
      technology.effects = {}
    end
    if type(index) == "number" then
      table.insert(technology.effects, index, effect)
    else
      table.insert(technology.effects, effect)
    end
  end
end

function fds_technology.add_unlock(tech_name, recipe_name, index)
  local technology = data.raw.technology[tech_name]
  local recipe = data.raw.recipe[recipe_name]
  if technology and recipe then
    if recipe.enabled ~= false then
      recipe.enabled = false
    end
    if technology.effects then
      if type(index) == "number" then
        table.insert(technology.effects, index, {type="unlock-recipe", recipe=recipe_name})
      else
        table.insert(technology.effects, {type="unlock-recipe", recipe=recipe_name})
      end
    else
      technology.effects = {{type="unlock-recipe", recipe=recipe_name}}
    end
  end
end

function fds_technology.check_recipe_unlocks(recipe_name)
  local recipe = data.raw.recipe[recipe_name]
  if recipe then
    for _,technology in pairs(data.raw.technology) do
      for _,effect in pairs(technology.effects or {}) do
        if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
          return
        end
      end
    end
    recipe.enabled = true
  end
end

function fds_technology.replace_unlock(tech_name, old_recipe_name, new_recipe_name)
  local technology = data.raw.technology[tech_name]
  if technology and technology.effects then
    for i,effect in pairs(technology.effects) do
      if effect.type == "unlock-recipe" and effect.recipe == old_recipe_name then
        effect.recipe = new_recipe_name
        fds_technology.check_recipe_unlocks(old_recipe_name)
        return true
      end
    end
  end
end

function fds_technology.remove_unlock(tech_name, recipe_name)
  local technology = data.raw.technology[tech_name]
  if technology and technology.effects then
    for i,effect in pairs(technology.effects) do
      if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
        table.remove(technology.effects, i)
        fds_technology.check_recipe_unlocks(recipe_name)
        return
      end
    end
  end
end

function fds_technology.move_unlock(old_tech_name, new_tech_name, recipe_name)
  -- TODO:
end

-------------------------------------------------------------------------- Research costs

function fds_technology.add_cost_ingredient(tech_name, pack_name)
  local technology = data.raw.technology[tech_name]
  if technology and technology.unit then
    if not technology.unit.ingredients then technology.unit.ingredients = {} end
    table.insert(technology.unit.ingredients, {pack_name, 1})
  end
end

function fds_technology.modify_cost(tech_name, modifiers)
  local technology = data.raw.technology[tech_name]
  if technology and technology.unit then
    for key,val in pairs(modifiers) do
      technology.unit[key] = val
    end
  end
end

function fds_technology.scale_cost(tech_name, scalars)
  local technology = data.raw.technology[tech_name]
  if technology and technology.unit then
    for key,val in pairs(scalars) do
      technology.unit[key] = technology.unit[key] * val
    end
  end
end

function fds_technology.remove_cost_ingredient(tech_name, pack_name)
  local technology = data.raw.technology[tech_name]
  if technology and technology.unit then
    for i,ingredient in pairs(technology.unit.ingredients) do
      if ingredient[1] == pack_name then
        table.remove(technology.unit.ingredients, i)
        return
      end
    end
  end
end

--------------------------------------------------------------------------

return fds_technology
