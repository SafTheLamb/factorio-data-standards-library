local fds_entity = {}

-------------------------------------------------------------------------- Resistances

function fds_entity.set_resistance(entity_type, entity_name, new_resistance)
  local entity = data.raw[entity_type][entity_name]
  if entity then
    if not entity.resistances then
      entity.resistances = {new_resistance}
    end
    for i,resistance in pairs(entity.resistances) do
      if resistance.type == new_resistance.type then
        entity.resistances[i] = new_resistance
        return
      end
    end
    table.insert(entity.resistances, new_resistance)
  end
end

function fds_entity.remove_resistance(entity_type, entity_name, damage_type)
  local entity = data.raw[entity_type][entity_name]
  if entity and entity.resistances then
    for i,resistance in pairs(entity.resistances) do
      if resistance.type == damage_type then
        table.remove(entity.resistances, i)
        return
      end
    end
  end
end

-------------------------------------------------------------------------- Shared

local fds_shared = require("__fdsl__.lib.shared")

function fds_entity.get_surface_condition(entity_type, entity_name, property_name)
  local entity = data.raw[entity_type][entity_name]
  return entity and fds_shared.get_surface_condition(entity, property_name) or nil
end

function fds_entity.set_surface_condition(entity_type, entity_name, new_property)
  local entity = data.raw[entity_type][entity_name]
  if entity then
    fds_shared.set_surface_condition(entity, new_property)
  end
end

function fds_entity.remove_surface_condition(entity_type, entity_name, property_name)
  local entity = data.raw[entity_type][entity_name]
  if entity then
    return fds_shared.remove_surface_condition(entity, property_name)
  end
  return false
end

--------------------------------------------------------------------------

return fds_entity
