local fds_assert = {}

function fds_assert.ensure(condition, message, ...)
  if condition then
    return true
  end
  assert(false, string.format(message, table.unpack(arg)))
  return false
end

function fds_assert.ensure_if(condition, flag, message, ...)
  if condition then
    return true
  elseif flag then
    assert(false, string.format(message, table.unpack(arg)))
  end
  return false
end

return fds_assert
