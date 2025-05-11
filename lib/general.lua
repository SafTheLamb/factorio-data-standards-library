local fds_general = {}

function fds_general.hide_all_prototypes(prototype_name)
  for _,prototype_table in pairs(data.raw) do
    for _,prototype in pairs(prototype_table) do
      if prototype.name == prototype_name then
        prototype.hidden = true
        prototype.next_upgrade = nil
      end
    end
  end
end

return fds_general
