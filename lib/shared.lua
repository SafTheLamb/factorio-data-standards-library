local fds_shared = {}

-------------------------------------------------------------------------- Surface conditions

function fds_shared.get_surface_condition(prototype, property_name)
  assert(type(property_name) == "string")
  if feature_flags["space_travel"] then
    if prototype.surface_conditions then
      for _,condition in pairs(surface_conditions) do
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
