local fds_mutate = {}

-- Gets whether the mutation is enabled based on its conditions, if it has any
--  mutation.settings (FdsSettingCondition)
function fds_mutate.can_mutation_run(mutation)
  if mutation.enabled == false then
    return false
  end

  if mutation.mods then
    if mutation.mods.any == true then
      local none = true
      for _,name in ipairs(mutation.mods) do
        if mods[name] then
          none = false
          break
        end
      end
      if none then return false end
    else
      local all = mutation.mods.none ~= true
      for _,name in ipairs(mutation.mods) do
        if not mods[name] == all then
          return false
        end
      end
    end
  end

  if mutation.settings then
    if mutation.settings.any == true then
      local none = true
      for _,name in ipairs(mutation.settings) do
        if settings.startup[name].value then
          none = false
          break
        end
      end
      if none then return false end
    else
      local all = mutation.settings.none ~= true
      for _,name in ipairs(mutation.settings) do
        if not settings.startup[name].value == all then
          return false
        end
      end
    end
  end

  return true
end

-- Executes all mutations passed in using the given callback if their conditions are met
--  mutations (FdsMutationInfo structs, see below): Data about each mutation and conditions about when to run it
function fds_mutate.mutate(mutations, callback)
  for _,mutation in pairs(mutations) do
    if fds_mutate.can_mutation_run(mutation) then
      callback(table.unpack(mutation))
    end
  end
end

-- FdsMutationInfo examples:
-- fds_mutate.mutate({{"steel-plate", {type="item", name="salt", amount=1}}, {"ice-platform", settings={"cold-snacc"}, {type="item", name="salt", amount=50}}}, fds_recipe.add_ingredient)
-- fds_mutate.mutate({{"flying-robot-frame", mods={"propellor-hat"}, "steel-plate", "propellor-hat"}}, fds_recipe.replace_ingredient)

return fds_mutate
