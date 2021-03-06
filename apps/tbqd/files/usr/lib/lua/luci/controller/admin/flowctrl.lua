local js = require("cjson")
module("luci.controller.admin.flowctrl", package.seeall)
local path = "/etc/config/tc.json"

function index()
	entry({"admin", "flowctrl"}, alias("admin", "flowctrl", "flowctrl"), _("流量控制"), 50).index = true 
	entry({"admin", "flowctrl", "flowctrl"}, template("admin_flowcrtl/flowctrl"), _("流量控制"), 1)
	
	entry({"admin", "flowctrl", "get_flow"}, call("get_flow")).leaf = true
	entry({"admin", "flowctrl", "set_globalshare"}, call("set_globalshare")).leaf = true
	entry({"admin", "flowctrl", "insRules"}, call("insRules")).leaf = true
	entry({"admin", "flowctrl", "updateRules"}, call("updateRules")).leaf = true
	entry({"admin", "flowctrl", "deletRules"}, call("deletRules")).leaf = true
end

local function read(path, func)
	func = func and func or io.open
	local fp = func(path, "rb")
	if not fp then 
		return 
	end 
	local s = fp:read("*a")
	fp:close()
	return s
end

local function save_file(path, map)
	local tmp = path .. ".tmp"
	local s = js.encode(map)
	s = string.gsub(s, "{}", "[]")
	s = string.gsub(s, '"Enabled":"true"', '"Enabled":true')
	s = string.gsub(s, '"Enabled":"false"', '"Enabled":false')
	local fp = io.open(tmp, "wb")

	fp:write(s)
	fp:flush()
	fp:close()

	local cmd = string.format("mv %s %s", tmp, path)
	os.execute(cmd)

	local cmd = "lua /usr/sbin/settc.lua /etc/config/tc.json | cat > /sys/module/tbq/tbq"
	os.execute(cmd)

	local cmd = "echo 1 > /sys/module/tbq/tbq"
	os.execute(cmd)
end

function get_flow()
	local s = read(path) or "" 
	luci.http.header("Content-Length", #s)
	luci.http.write(s)
end

function set_globalshare()
	local map = luci.http.formvalue()
	local s = read(path)
	local fmap = {}
	if s then
		fmap = js.decode(s)
	end
	
	for k, v in pairs(map) do
		fmap[k] = v
	end
	save_file(path, fmap)
	luci.http.write_json({state = 0})
end

function insRules()
	local map = luci.http.formvalue()
	local s = read(path)
	local fmap = js.decode(s)
	local f = true

	for _, v in ipairs(fmap["Rules"]) do
		if v["Name"] == map["Name"] then
			f = false
			break
		end
	end

	if f == true then
		table.insert(fmap["Rules"], map)
		save_file(path, fmap)
		luci.http.write_json({state = 0})
	else
		luci.http.write_json({state = 1})
	end
end

function updateRules()
	local map = luci.http.formvalue()
	local s = read(path)
	local fmap = js.decode(s)
	local f = false
	
	if not fmap["Rules"] then
		luci.http.write_json({state = 1})
		return
	end

	local arr = {}
	for _, v in ipairs(fmap["Rules"]) do
		if v["Name"] == map["Name"] then
			for key, val in pairs(map) do
				v[key] = map[key]
			end
			table.insert(arr, v)
			f = true
		else
			table.insert(arr, v)
		end
	end
	
	fmap["Rules"] = arr
	if f == true then
		save_file(path, fmap)
		luci.http.write_json({state = 0})
	else
		luci.http.write_json({state = 1})
	end
end

function deletRules()
	local map = luci.http.formvalue()
	local s = read(path)
	local fmap = js.decode(s)

	local f = false
	if not fmap["Rules"] then
		luci.http.write_json({state = 1})
		return
	end
	
	local arr = {}
	for _, v in ipairs(fmap["Rules"]) do
		if v["Name"] == map["Name"] then 
			f = true
		else
			table.insert(arr, v)
		end
	end
	fmap["Rules"] = arr
	if f == true then
		save_file(path, fmap)
		luci.http.write_json({state = 0})
	else
		luci.http.write_json({state = 1})
	end
end
