-- Shared test utilities: check(), assert_eq(), summary()
-- Pass/fail counters shared across all test files via require cache

local helpers = {}

helpers.passed = 0
helpers.failed = 0

function helpers.check(condition, msg)
    if condition then
        helpers.passed = helpers.passed + 1
        io.write("  PASS: " .. msg .. "\n")
    else
        helpers.failed = helpers.failed + 1
        io.write("  FAIL: " .. msg .. "\n")
    end
end

function helpers.assert_eq(a, b, msg)
    local prefix = msg and (msg .. ": ") or ""
    helpers.check(a == b, prefix .. "expected " .. tostring(b) .. ", got " .. tostring(a))
end

function helpers.summary()
    io.write("\n=== Results ===\n")
    io.write("Passed: " .. helpers.passed .. "\n")
    io.write("Failed: " .. helpers.failed .. "\n")
    if helpers.failed > 0 then
        io.write("SOME TESTS FAILED\n")
        os.exit(1)
    else
        io.write("ALL TESTS PASSED\n")
    end
end

return helpers
