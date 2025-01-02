local fds_technology = {}

-------------------------------------------------------------------------- General



-------------------------------------------------------------------------- Technology modifying

-- merge_technologies

-- remove_technology ()

-------------------------------------------------------------------------- Prerequisites

function fds_technology.add_prereq(tech_name, prereq_name)
  local technology = data.raw.technology[tech_name]
  local prerequisite = data.raw.technology[prereq_name]
  assert(prerequisite or not FDS_ASSERT)
  if technology and prerequisite then
    table.insert(technology.prerequisites, prereq_name)
  end
end

function fds_technology.remove_prereq(tech_name, prereq_name)
  local technology = data.raw.technology[tech_name]
  if technology then
    for i,prereq in pairs(technology.prerequisites) do
      if prereq == prereq_name then
        table.remove(technology.prerequisites, i)
      end
    end
  end
end

-------------------------------------------------------------------------- Recipe unlocks

function fds_technology.add_unlock(tech_name, recipe_name, index)
  local technology = data.raw.technology[tech_name]
  local recipe = data.raw.recipe[recipe_name]
  if technology and recipe then
    if recipe.enabled ~= false then
      recipe.enabled = false
    end
    if type(index) == "number" then
      table.insert(technology.effects, index, {type="unlock-recipe", recipe=recipe_name})
    else
      table.insert(technology.effects, {type="unlock-recipe", recipe=recipe_name})
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
