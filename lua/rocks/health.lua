---@mod rocks.health rocks.nvim health checks
--
-- Copyright (C) 2023 NTBBloodbath
--
-- Version:    0.1.0
-- License:    GPLv3
-- Created:    24 Oct 2023
-- Updated:    24 Oct 2023
-- Homepage:   https://github.com/nvim-neorocks/rocks.nvim
-- Maintainers: NTBBloodbath <bloodbathalchemist@protonmail.com>, Vhyrro <vhyrro@gmail.com>
--
---@brief [[
--
-- rocks.nvim health checks
--
---@brief ]]

local health = {}

---@type RocksConfig
local config = require("rocks.config.internal")

local h = vim.health
local start = h.start or h.report_start
local ok = h.ok or h.report_ok
local error = h.error or h.report_error
local warn = h.warn or h.report_warn

---@class (exact) LuaDependency
---@field module string The name of a module
---@field optional fun():boolean Function that returns whether the dependency is optional
---@field url string URL (markdown)
---@field info string Additional information

---@type LuaDependency[]
local lua_dependencies = {
    {
        module = "toml",
        optional = function()
            return true
        end,
        url = "[toml.lua](https://luarocks.org/modules/LebJe/toml)",
        info = "Required for TOML config serialization.",
    },
    {
        module = "toml_edit",
        optional = function()
            return true
        end,
        url = "[toml-edit](https://luarocks.org/modules/neorg/toml-edit)",
        info = "Required for TOML config editing.",
    },
}

---@class (exact) ExternalDependency
---@field name string Name of the dependency
---@field get_binaries fun():string[]Function that returns the binaries to check for
---@field version_flag? string
---@field parse_version? fun(stdout:string):string
---@field optional fun():boolean Function that returns whether the dependency is optional
---@field url string URL (markdown)
---@field info string Additional information
---@field extra_checks function|nil Optional extra checks to perform if the dependency is installed

---@type ExternalDependency[]
local external_dependencies = {
    {
        name = "luarocks",
        get_binaries = function()
            return { "luarocks" }
        end,
        optional = function()
            return true
        end,
        url = "[luarocks](https://luarocks.org/#quick-start)",
        info = "LuaRocks is the package manager for Lua modules.",
    },
    {
        name = "lua",
        get_binaries = function()
            return { "lua" }
        end,
        version_flag = "-v",
        parse_version = function(stdout)
            return stdout:match("^Lua%s(%d+%.%d+%.%d+)")
        end,
        optional = function()
            return true
        end,
        url = "[Lua](https://www.lua.org/)",
        info = "luarocks requires a Lua installation.",
    },
}

---@param dep LuaDependency
local function check_lua_dependency(dep)
    if pcall(require, dep.module) then
        ok(dep.url .. " installed.")
        return
    end
    if dep.optional() then
        warn(("%s not installed. %s %s"):format(dep.module, dep.info, dep.url))
    else
        error(("Lua dependency %s not found: %s"):format(dep.module, dep.url))
    end
end

---@param dep ExternalDependency
---@return boolean is_installed
---@return string|nil version
local check_installed = function(dep)
    local binaries = dep.get_binaries()
    for _, binary in ipairs(binaries) do
        if vim.fn.executable(binary) == 1 then
            local systemObj = vim.system({ binary, dep.version_flag or "--version" }):wait()
            local version = binary == "lua" -- (╯°□°)╯︵ ┻━┻
                    and systemObj.stderr
                or systemObj.stdout
            return true, version
        end
    end
    return false
end

---@param dep ExternalDependency
local function check_external_dependency(dep)
    local installed, mb_version = check_installed(dep)
    if installed then
        local mb_version_newline_idx = mb_version and mb_version:find("\n")
        local mb_version_len = mb_version
            and (mb_version_newline_idx and mb_version_newline_idx - 1 or mb_version:len())
        local version = mb_version and mb_version:sub(0, mb_version_len) or "(unknown version)"
        ok(("%s: found %s"):format(dep.name, version))
        if dep.extra_checks then
            dep.extra_checks()
        end
        return
    end
    if dep.optional() then
        warn(([[
        %s: not found.
        Install %s for extended capabilities.
        %s
        ]]):format(dep.name, dep.url, dep.info))
    else
        error(([[
        %s: not found.
        rocks.nvim requires %s.
        %s
        ]]):format(dep.name, dep.url, dep.info))
    end
end

local function check_config()
    start("Checking config")
    if vim.g.rocks_nvim then
        ok("vim.g.rocks_nvim is set")
    else
        ok("vim.g.rocks_nvim is not set")
    end
    local valid, err = require("rocks.config.check").validate(config)
    if valid then
        ok("No errors found in config.")
    else
        error(err or "" .. vim.g.rocks_nvim and "" or " This looks like a plugin bug!")
    end
end

function health.check()
    start("Checking for Lua dependencies")
    for _, dep in ipairs(lua_dependencies) do
        check_lua_dependency(dep)
    end

    start("Checking external dependencies")
    for _, dep in ipairs(external_dependencies) do
        check_external_dependency(dep)
    end
    check_config()
end

return health
