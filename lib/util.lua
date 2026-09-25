local fds_util = {}

function fds_util.get_prototype(prototype_type, prototype_name)
	for subtype in pairs(defines.prototypes[prototype_type] or {}) do
		local prototypes = data.raw[subtype]
		if prototypes and prototypes[prototype_name] then
			return prototypes[prototype_name]
		end
  	end
end

function fds_util.hide_prototype(prototype_type, prototype_name)
	if data.raw[prototype_type] and data.raw[prototype_type][prototype_name] then
		data.raw[prototype_type][prototype_name].hidden = true
		return true
	end
	return false
end

function fds_util.hide_all_prototypes(prototype_name)
  for _,prototype_table in pairs(data.raw) do
    for _,prototype in pairs(prototype_table) do
      if prototype.name == prototype_name then
        prototype.hidden = true
        prototype.next_upgrade = nil
      end
    end
  end
end

return fds_util
