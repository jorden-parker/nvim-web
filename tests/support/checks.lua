local checks = {}

local failure_count = 0

function checks.check(description, assertion)
  local is_passing, failure_reason = pcall(assertion)
  if is_passing then
    io.stdout:write("ok   " .. description .. "\n")
    return
  end
  failure_count = failure_count + 1
  io.stdout:write("FAIL " .. description .. "\n     " .. tostring(failure_reason) .. "\n")
end

function checks.expect_equal(actual, expected)
  if not vim.deep_equal(actual, expected) then
    error("expected " .. vim.inspect(expected) .. " but got " .. vim.inspect(actual), 2)
  end
end

function checks.finish()
  io.stdout:write(failure_count == 0 and "all checks passed\n" or (failure_count .. " check(s) failed\n"))
  os.exit(failure_count == 0 and 0 or 1)
end

return checks
