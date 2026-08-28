local math2d = require("__core__.lualib.math2d")
local fds_util = require("__fdsl__.lib.util")

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

---Moves and scales an icon / icons. Careful: will modify the passed in icon(s).
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
	local shift = icon.shift and math2d.position.ensure_xy(icon.shift) or {x=0, y=0}
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
---@param alignment fds_icon.alignment Which "corner" to put the sub-icon in.
---@param scale double? How much to shrink the corner icon. Defaults to 0.5.
---@param shift_amount double? Overrides the auto-calculated shift amount.
---@return data.IconData,data.IconData?,data.IconData?,data.IconData?,data.IconData?,data.IconData?,data.IconData?,data.IconData?,data.IconData?,data.IconData?
function fds_icon.make_corner_icon(prototype_type, prototype_name, alignment, scale, shift_amount)
	local prototype = prototype_type and data.raw[prototype_type][prototype_name] or prototype_name
	if prototype then
		scale = scale or 0.5
		shift_amount = shift_amount or (16 * (1 - scale))
		local shift = {x=0, y=0}

		if fds_icon.alignment.is_left(alignment) then
			shift.x = -shift_amount
		elseif fds_icon.alignment.is_right(alignment) then
			shift.x = shift_amount
		end
		if fds_icon.alignment.is_top(alignment) then
			shift.y = -shift_amount
		elseif fds_icon.alignment.is_bottom(alignment) then
			shift.y = shift_amount
		end

		if type(prototype) == "string" then
			return fds_icon.adjust_icon({icon=prototype, draw_background=true}, scale, shift)
		else
			if not (prototype.icon or prototype.icons) and prototype_type == "recipe" then
				local main_product = util.get_recipe_main_product(prototype, util.normalize_recipe_products(prototype))

				for _,subtype in pairs(defines.prototypes[main_product.type]) do
					if data.raw[subtype][main_product.name] then
						prototype = data.raw[subtype][main_product.name]
						break
					end
				end
			end
			assert(prototype.icon or prototype.icons)
			if prototype.icons then
				local icons = util.table.deepcopy(prototype.icons)
				assert(icons)
				fds_icon.adjust_icon(icons, scale, shift)
				icons[1].draw_background = true
				return table.unpack(icons)
			elseif prototype.icon then
				return fds_icon.adjust_icon({icon=prototype.icon, icon_size=prototype.icon_size, draw_background=true}, scale, shift)
			end
		end
	end
	return {icon="__core__/graphics/empty.png"}
end

---Shortcut for making icon with shift -12 and scale 0.4
---@param prototype_type any
---@param prototype_name any
---@return data.IconData
function fds_icon.make_big_corner_icon(prototype_type, prototype_name)
	return fds_icon.make_corner_icon(prototype_type, prototype_name, fds_icon.alignment.top_left, 0.8, 12)
end

---Converts the provided prototype to have icons, instead of icon and icon_size
---@param prototype table 
---@return boolean success Whether the prototype now has an icons table
function fds_icon.convert_to_icons(prototype)
	if prototype.icons then return true end
	if prototype.icon then
		prototype.icons = {{icon=prototype.icon, icon_size = prototype.icon_size}}
		return true
	end
	if prototype.type == "recipe" then
		local main_product = util.get_recipe_main_product(prototype)
		local substitute = fds_util.get_prototype(main_product.type, main_product.name)
		if substitute then
			if substitute.icons then
				prototype.icons = util.table.deepcopy(substitute.icons)
			else
				prototype.icons = {{icon=substitute.icon, icon_size = substitute.icon_size}}
			end
			return true
		end
	end
	return false
end

---Adjusts icons to fit within the [-16, 16] bounds that icons are usually contained within.
---@param icons data.IconData[]
function fds_icon.adjust_to_fit(icons)
	local desired_size = 32
	local bounds = {left_top={x=0, y=0}, right_bottom={x=0, y=0}}
	for _,icon in pairs(icons) do
		local size = (icon.icon_size or 64) * (icon.scale or 0.5)
		local icon_bounds = math2d.bounding_box.create_from_centre(icon.shift or {x=0, y=0}, size, size)
		if icon_bounds.left_top.x < bounds.left_top.x then bounds.left_top.x = icon_bounds.left_top.x end
		if icon_bounds.left_top.y < bounds.left_top.y then bounds.left_top.y = icon_bounds.left_top.y end
		if icon_bounds.right_bottom.x > bounds.right_bottom.x then bounds.right_bottom.x = icon_bounds.right_bottom.x end
		if icon_bounds.right_bottom.y > bounds.right_bottom.y then bounds.right_bottom.y = icon_bounds.right_bottom.y end
	end
	-- Move the icon to fit within the desired bounds of [-16, 16]
	local shift = math2d.position.multiply_scalar(math2d.bounding_box.get_centre(bounds), -1)
	local extent = math2d.position.subtract(bounds.right_bottom, bounds.left_top)
	local scale = desired_size / math.max(extent.x, extent.y)
	return fds_icon.adjust_icon(icons, scale, shift)
end

---Shortcut for adding a big corner icon BEHIND the target's existing icon
---@param prototype_or_icons table|data.IconData[] Target prototype or icons to add to
---@param source_type string Type of the prototype to get the corner icons from
---@param source_name string Name of the prototype to get the corner icons from
---@return boolean
function fds_icon.add_big_corner_icon(prototype_or_icons, source_type, source_name)
	local target_icons = prototype_or_icons
	if prototype_or_icons.type then
		local convert_successful = fds_icon.convert_to_icons(prototype_or_icons)
		assert(convert_successful)
		target_icons = prototype_or_icons.icons
	end
	if target_icons and data.raw[source_type][source_name] then
		local new_icons = {
			fds_icon.make_big_corner_icon(source_type, source_name)
		}
		target_icons[1].draw_background = true
		for i=#new_icons,1,-1 do
			table.insert(target_icons, new_icons[i])
		end
		fds_icon.adjust_to_fit(target_icons)
		return true
	end
	return false
end

return fds_icon
