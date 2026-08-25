local math2d = require("__core__.lualib.math2d")

local fds_icon = {
	alignment = {
		top_left =      "top-left",
		middle_left =   "middle-left",
		bottom_left =   "bottom-left",
		top_center =    "top-center",
		middle_center = "middle-center",
		bottom_center = "bottom-center",
		top_right =     "top-right",
		middle_right =  "middle-right",
		bottom_right =  "bottom-right"
	}
}

---@alias fds_icon.alignment (string)

---@param alignment fds_icon.alignment
---@return boolean
function fds_icon.alignment.is_left(alignment)
	return alignment == fds_icon.alignment.top_left or alignment == fds_icon.alignment.middle_left or alignment == fds_icon.alignment.bottom_left
end

---@param alignment fds_icon.alignment
---@return boolean
function fds_icon.alignment.is_center(alignment)
	return alignment == fds_icon.alignment.top_center or alignment == fds_icon.alignment.middle_center or alignment == fds_icon.alignment.bottom_center
end

---@param alignment fds_icon.alignment
---@return boolean
function fds_icon.alignment.is_right(alignment)
	return alignment == fds_icon.alignment.top_right or alignment == fds_icon.alignment.middle_right or alignment == fds_icon.alignment.bottom_right
end

---@param alignment fds_icon.alignment
---@return boolean
function fds_icon.alignment.is_top(alignment)
	return alignment == fds_icon.alignment.top_left or alignment == fds_icon.alignment.top_center or alignment == fds_icon.alignment.top_right
end

---@param alignment fds_icon.alignment
---@return boolean
function fds_icon.alignment.is_middle(alignment)
	return alignment == fds_icon.alignment.middle_left or alignment == fds_icon.alignment.middle_center or alignment == fds_icon.alignment.middle_right
end

---@param alignment fds_icon.alignment
---@return boolean
function fds_icon.alignment.is_bottom(alignment)
	return alignment == fds_icon.alignment.bottom_left or alignment == fds_icon.alignment.bottom_center or alignment == fds_icon.alignment.bottom_right
end

---Moves and scales an icon
---@param icon data.IconData|data.IconData[]
---@param in_scale double
---@param in_shift data.Vector
---@return data.IconData|data.IconData[]
function fds_icon.adjust_icon(icon, in_scale, in_shift)
	if #icon > 0 then
		for _,subicon in pairs(icon) do
			fds_icon.adjust_icon(subicon, in_scale, in_shift)
		end
		return icon
	end
	local shift = icon.shift and {icon.shift.x or icon.shift[1], icon.shift.y or icon.shift[1]} or {0,0}
	shift = math2d.position.add(math2d.position.multiply_scalar(shift, in_scale), in_shift)
	if icon.shift and icon.shift.x then
		icon.shift = {x=shift.x, y=shift.y}
	else
		icon.shift = shift
	end
	icon.scale = in_scale * (icon.scale or 0.5)
	return icon
end

---Constructs an icon for the given prototype, if it exists. Supports prototypes with multiple icons.
---@param prototype_type string Type of the prototype to get the icon from, or nil to use a file directly.
---@param prototype_name string Name of the prototype to get the icon from, or the mod-relative filepath.
---@param alignment fds_icon.alignment Which "corner" to put the sub-icon in
---@return data.IconData,data.IconData?,data.IconData?,data.IconData?,data.IconData?,data.IconData?,data.IconData?,data.IconData?,data.IconData?,data.IconData?
function fds_icon.make_corner_icon(prototype_type, prototype_name, alignment)
	local prototype = prototype_type and data.raw[prototype_type][prototype_name] or prototype_name
	if prototype then
		local shift = {0,0}

		if fds_icon.alignment.is_left(alignment) then
			shift[1] = -8
		elseif fds_icon.alignment.is_right(alignment) then
			shift[1] = 8
		end
		if fds_icon.alignment.is_top(alignment) then
			shift[2] = -8
		elseif fds_icon.alignment.is_bottom(alignment) then
			shift[2] = 8
		end

		if type(prototype) == "string" then
			return fds_icon.adjust_icon({icon=prototype, draw_background=true}, 0.5, shift)
		else
			if prototype.icons then
				local icons = util.table.deepcopy(prototype.icons)
				assert(icons)
				fds_icon.adjust_icon(icons, 0.5, shift)
				for _,icon in pairs(icons) do
					icon.draw_background = true
				end
				return table.unpack(icons)
			elseif prototype.icon then
				assert(type(prototype.icon) == "string" and helpers.is_valid_sprite_path(prototype.icon))
				return fds_icon.adjust_icon({icon=prototype.icon, icon_size=prototype.icon_size, draw_background=true}, 0.5, shift)
			end
		end
	end
	return {icon="__core__/graphics/empty.png"}
end

return fds_icon
