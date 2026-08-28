local fds_util = {}

function fds_util.get_prototype(prototype_type, prototype_name)
	for subtype in pairs(defines.prototypes[prototype_type]) do
		local prototypes = data.raw[subtype]
		if prototypes and prototypes[prototype_name] then
			return prototypes[prototype_name]
		end
  	end
end

return fds_util
