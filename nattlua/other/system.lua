local system = {}

function system.is_tty()
    if os.getenv("CI") or os.getenv("GITHUB_ACTIONS") or os.getenv("TRAVIS") or 
        os.getenv("CIRCLECI") or os.getenv("GITLAB_CI") or os.getenv("JENKINS_HOME") then
        return false
    end
    
    -- Try to detect if stdout is a terminal
    local handle = io.popen("test -t 1 && echo yes || echo no", "r")
    if handle then
        local result = handle:read("*a"):match("^%s*(.-)%s*$")
        return result == "yes"
    end

    return true
end

return system