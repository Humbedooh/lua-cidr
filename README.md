# lua-cidr
Simple CIDR block matching library for Lua 5.2+

## Usage:

`cidr` works with both IPv4 and Ipv6, and requires no bit library to operate.
All it needs is Lua 5.2 or above. LuaJIT should work fine as well.


IPv4 example:

~~~lua
local cidr = import 'cidr'
local network = cidr:network('127.0.0.1/25')
local my_ip = '127.0.0.65'
local outside_ip = '1.2.3.4'

assert(network.ipv4) -- network is ipv4
assert(not network.ipv6) -- network is not ipv6
assert(network:match(my_ip)) -- my_ip is within network range
assert(not network:match(outside_ip)) -- outside_ip is not within network range
~~~

IPv6 example:

~~~lua
local cidr = require 'cidr'
local network = cidr:network("2001:dead:beef::1/48")
local my_ip = "2001:dead:beef::2"
assert(network.ipv6) -- network is ipv6
assert(not network.ipv4) -- is not ipv4
assert(network:match(my_ip)) -- my_ip is within network range
~~~
