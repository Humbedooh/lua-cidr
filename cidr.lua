#!/usr/bin/env lua5.3
--[[
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

Copyright© 2021, Daniel Gruno - humbedooh@apache.org
]]--

--[[
    cidr.lua - simple CIDR range checker for Lua 5.1+

    usage:
        local cidr = require 'cidr'
        local net = cidr.network("127.0.0.1/25")
        local myip = "127.0.0.5"
        assert(net.ipv4) -- network is ipv4
        assert(net:match(myip)) -- myip is within network

    Works with both IPv4 and IPv6. Requires no bit library.
]]--


-- Figure out bitwise ops
local bor = nil
local major,minor = _VERSION:match("Lua (%d+)%.(%d+)")
major = tonumber(major)
minor = tonumber(minor)
if major == 5 and minor < 3 then
    local bit = require 'bit'
    bor = bit.bor
elseif major > 5 or minor >= 3 then
    -- hack to circumvent bad syntax when not 5.3+
    bor = load("return function(a,b) return a|b end")()
end

-- ip_raw: converts IPv4 and IPv6 to 8-bit tuples
local function ip_raw(cidr, ipv6)
    local ip_struct = ipv6 and {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0} or {0,0,0,0}
    local pos = 1
    if cidr:match("%.") then
        for part in cidr:gmatch("(%d+)") do
            ip_struct[pos] = tonumber(part, 10)
            pos = pos + 1
        end
    elseif cidr:match(":") then
        for part in cidr:gmatch("([a-f0-9]+(:*))") do
            local shift = part:match("::")
            part = part:gsub(":", "")
            if #part > 2 then
                p1, p2 = part:match("^(%w+)(%w%w)$")
                ip_struct[pos] = tonumber(p1, 16)
                pos = pos + 1
                ip_struct[pos] = tonumber(p2, 16)
                pos = pos + 1
            else
                ip_struct[pos] = tonumber(part, 16)
                pos = pos + 1
            end
            if shift then
                pos = ipv6 and 16 or 4
            end
        end
    end
    return ip_struct
end

-- ip_match: checks if an IP is within a CIDR range or not
local function ip_match(self, ip)
    local x_lowest = ip_raw(ip, ip:match(":") and true or false)
    local within_cidr = true
    for k, part in pairs(x_lowest) do
        if not (part >= self._lowest[k] and part <= self._highest[k]) then
            within_cidr = false
            break
        end
    end
    return within_cidr
end

-- network: Defines a network range based on CIDR notation
local function network(self, cidr)
    local t = {}
    local ipv6 = cidr:match(":") and true or false
    local range = cidr:match("/(%d+)")
    if range then
        cidr = cidr:gsub("/%d+", "")
    end
    local lowest = ip_raw(cidr, ipv6) -- accept FROM here...
    local highest = ipv6 and {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0} or {0,0,0,0}-- ...TO here (we'll mod with cidr range later)
    local cidr_range = tonumber(range) or (ipv6 and 128 or 32)
    local c_pos = 8
    for k, v in pairs(lowest) do
        if cidr_range < c_pos and k <= (ipv6 and 16 or 4) then
            local m = 8 - ((cidr_range - c_pos) % 8)
            if cidr_range < c_pos - 8 then
                m = 8
            end
            v = bor(v, 2^m-1)
        end
        c_pos = c_pos + 8
        highest[k] = v
    end
    t._lowest = lowest
    t._highest = highest
    t.match = ip_match
    t.ipv6 = ipv6 and true or false
    t.ipv4 = not t.ipv6
    return t
end

local function test()
    local ipv4_test = network(1, "127.0.0.0/25")
    assert(ipv4_test.ipv4, "127.0.0.1/25 should report as IPv4!")
    assert(not ipv4_test.ipv6, "127.0.0.1/25 should not report as IPv6!")
    assert(ipv4_test:match("127.0.0.1"), "127.0.0.1 should be within 127.0.0.0/25!")
    assert(not ipv4_test:match("127.0.0.128"), "127.0.0.128 should not be within 127.0.0.0/25!")
    assert(not ipv4_test:match("230.0.0.1"), "230.0.0.1 should not be within 127.0.0.0/25!")
    assert(not ipv4_test:match("2001:dead:beef::1"), "2001:dead:beef::1 should not be within 127.0.0.0/25!")

    local ipv6_test = network(1, "2001:dead:beef:0000::1/48")
    assert(ipv6_test.ipv6, "2001:dead:beef:0000::1/48 should report as IPv6!")
    assert(not ipv6_test.ipv4, "2001:dead:beef:0000::1/48 should not report as IPv4!")
    assert(ipv6_test:match("2001:dead:beef::2"), "2001:dead:beef::2 should be within 2001:dead:beef::1/48!")
    assert(not ipv6_test:match("2001:ffab:beef::2"), "2001:ffab:beef::2 should not be within 2001:dead:beef::1/48!")
    assert(not ipv6_test:match("127.0.0.1"), "127.0.0.1 should not be within 2001:dead:beef::1/48!")
end


return {
    network = network,
    run_tests = test
}
