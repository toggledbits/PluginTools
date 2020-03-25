--[[ ------------------------------------------------------------------

	Basic Plugin Framework - rigpapa (www.toggledbits.com)
	This is the implementation for basic (single-instance, not
	parent-child) plugins.

	***** DO NOT MAKE ANY CHANGES IN THIS FILE *****

------------------------------------------------------------------ --]]

luup.log("RUNNING L_PluginBasicImpl1.lua",2)
for k,v in pairs(_G) do luup.log( k.."="..tostring(v),2) end

--[[ =============================================================== --]]

PFB = {}
PFB.VERSION = 20085
PFB.SIGNATURE = "23b685bc-3d2e-11ea-85f9-035ca9e8fad3"

-- Our local (global) inits
local pluginWatches = {}
local pluginTimers = {}
local pluginRequests = {}
local pluginNextTID = 0
local pluginMasterSerial = 0
local pluginFlags = { debug=false }

if not unpack then unpack = table.unpack end

--[[ ===== LOGGING ===== --]]

PFB.logging = {}

local logLevels = { ERR=1, ERROR=1, WARN=2, WARNING=2, NOTICE=3, INFO=4, DEBUG1=5, DEBUG2=6,
					DEBUG3=7, DEBUG4=8, DEBUG5=9, DEBUG6=10,
					err=1, ['error']=1, warn=2, warning=2, notice=3, info=4, debug1=5, debug2=6,
					debug3=7, debug4=8, debug5=9, debug6=10,
					DEFAULT=4, default=4,
					[1]='err', [2]='warn', [3]='notice', [4]='info', [5]='debug1', [6]='debug2',
					[7]='debug3', [8]='debug4', [9]='debug5', [10]='debug6'
				}

PFB.LOGLEVEL = logLevels -- synonym
PFB.logLevel = PFB.LOGLEVEL.DEFAULT

-- Used for output of tables to debug stream
local function dump( t, seen )
	if t == nil then return "nil" end
	seen = seen or {}
	local sep = ""
	local str = "{ "
	for k,v in pairs(t) do
		local val
		if type(v) == "table" then
			if seen[v] then val = "(recursion)"
			else
				seen[v] = true
				val = dump(v, seen)
			end
		elseif type(v) == "string" then
			val = string.format("%q", v)
		else
			val = tostring(v)
		end
		str = str .. sep .. k .. "=" .. val
		sep = ", "
	end
	str = str .. " }"
	return str
end

-- Write a message to the log
local function L(level, msg, ...) -- luacheck: ignore 212
	if type(level) == "string" then level = logLevels[level] or logLevels.NOTICE end
	if (level or logLevels.NOTICE) <= (PFB.logLevel or logLevels.DEFAULT) then
		local str
		local ll = level == logLevels.ERR and 1 or ( level == logLevels.WARN and 2 or 50 )
		if type(msg) == "table" then
			str = tostring(msg.prefix or pluginFlags.module._PLUGIN_NAME) .. ": " .. tostring(msg.msg or msg[1])
			ll = msg.level or ll
		else
			str = string.format( "%s[%s]: %s", tostring(pluginFlags.module._PLUGIN_NAME), logLevels[level] or '?', tostring(msg) )
		end
		str = string.gsub(str, "%%(%d+)", function( n )
				n = tonumber(n, 10)
				if n < 1 or n > #arg then return "nil" end
				local val = arg[n]
				if type(val) == "table" then
					return dump(val)
				elseif type(val) == "string" then
					return string.format("%q", val)
				elseif type(val) == "number" and math.abs(val-os.time()) <= 86400 then
					return tostring(val) .. "(" .. os.date("%x.%X", val) .. ")"
				end
				return tostring(val)
			end
		)
		luup.log(str, ll)
	end
end

local function P(msg, ...) if pluginFlags.debug then L('notice', {msg=msg,prefix="[\27[34;1mPlugin".."Bas".."ic\27[0m]"},...) end end -- luacheck: ignore 212

PFB.log = L
PFB.logging.log = L
PFB.logging.dump = L

--[[ ===== STATE VARIABLES ===== ==]]

PFB.var = {}

-- Get variable value (easy to go directly to luup, here just for consistency)
PFB.var.get = function( var, dev, sid )
	return luup.variable_get( sid or pluginFlags.module.MYSID, var, dev )
end

-- Get numeric variable, or return default value if unset/empty/non-numeric
PFB.var.getNumeric = function( name, dflt, dev, sid )
	sid = sid or pluginFlags.module.MYSID
	dev = dev or PFB.device
	local s = luup.variable_get( sid, name, dev ) or ""
	return tonumber(s) or dflt
end

-- Initialize a variable if it does not already exist.
PFB.var.init = function( name, dflt, dev, sid )
	sid = sid or pluginFlags.module.MYSID
	dev = dev or PFB.device
	local currVal = luup.variable_get( sid, name, dev )
	if currVal == nil then
		luup.variable_set( sid, name, tostring(dflt), dev )
		return tostring(dflt)
	end
	return currVal
end

-- Set variable, only if value has changed.
PFB.var.set = function( name, val, dev, sid )
	sid = sid or pluginFlags.module.MYSID
	dev = dev or PFB.device
	val = (val == nil) and "" or tostring(val)
	local s = luup.variable_get( sid, name, dev )
	if s ~= val then
		luup.variable_set( sid, name, val, dev )
	end
	return s -- return old value
end

-- Delete a state variable. Newer versions of firmware do this by setting nil;
-- older versions require a request (not implemented here).
PFB.var.delete = function( name, dev, sid )
	sid = sid or pluginFlags.module.MYSID
	dev = dev or PFB.device
	if luup.variable_get( sid, name, dev ) then
		luup.variable_set( sid, name, nil, dev )
	end
end

--[[ ===== TIMERS ===== --]]

PFB.delay = {}

-- Find next timer to fire
local function findNextTimer()
	local mintimer
	for _,t in pairs( pluginTimers ) do
		if t.id ~= "master" and ( mintimer == nil or t.when < mintimer.when ) then mintimer = t end
	end
	P("findNextTimer() next is %1", mintimer)
	return mintimer
end

-- (Re)schedule next master tick
local function scheduleNextDelayRun()
	P("scheduleNextDelayRun()")
	local mintimer = findNextTimer()
	if mintimer then
		if pluginTimers.master and ( pluginTimers.master.when == 0 or mintimer.when >= pluginTimers.master.when ) then
			-- Master not waiting (execTimers is running) or next eligible later than current
			-- master tick, don't reschedule.
			P("scheduleNextDelayRun() in exec or new timer past master, not rescheduling")
			return
		end
		local delay = math.max( mintimer.when - os.time(), 0 )
		pluginMasterSerial = pluginMasterSerial + 1
		pluginTimers.master = { id="master", when=os.time()+delay, serial=pluginMasterSerial }
		P("scheduleNextDelayRun() master tick now serial %1 scheduled for %2; master=%3", pluginMasterSerial, delay, pluginTimers.master)
		luup.call_delay( '_DelayCb', delay, tostring( pluginMasterSerial) )
	end
	P("All current timers: %1", pluginTimers)
end

-- Schedule a function for delayed execution. Creates a new timer.
local function nulltimer() error"No function given to timer" end

-- Run eligible timers
local function execTimers( lcbparm )
	P("execTimers(%1)", lcbparm)
	pluginTimers.master.when = 0 -- flag not waiting
	local run = {}
	local now = os.time()
	for _,v in pairs( pluginTimers ) do
		if v.id ~= "master" and v.when and v.when <= now then
			table.insert( run, v.id )
		end
	end
	-- Sort by time
	table.sort( run, function( a, b ) return pluginTimers[a].when < pluginTimers[b].when end )
	P("execTimers() found %1 eligible timers to run: %2", #run, run)
	for _,id in ipairs( run ) do
		local v = pluginTimers[id]
		local st = os.time()
		local due = v.when
		v.when = nil -- clear to mark
		P("execTimers() running timer %1 due %2 late %3", v.id, due, os.time()-due)
		local success, err = pcall( v.func or nulltimer, v.id, unpack( v.args or {} ) )
		if not success then L('err', "Timer task %1 failed: %2", v.id, err) end
		if v.interval then
			local rt = os.time() - st
			if rt >= v.interval then L('warn', "Interval task %1 took longer to execute (%2s) than interval (%3s)", v.id, rt, v.interval) end
			while due <= now do due = due + v.interval end -- improve: use maths
			v.when = due
		elseif v.when == nil then
			pluginTimers[v.id] = nil -- wasn't rescheduled, remove
		end
	end
	local nextTimer = findNextTimer()
	if not nextTimer then
		-- Nothing more to run. Remove master tick.
		pluginTimers.master = nil
		return
	end
	-- Schedule next delay for next task.
	pluginTimers.master.when = nextTimer.when
	local delay = math.max( nextTimer.when - os.time(), 0 )
	if delay == 0 then
		-- Watch out for runaway timer processes. If caller schedules improperly, we can
		-- end up beating the system to death. Don't allow it.
		pluginTimers.master.shortcycle = ( pluginTimers.master.shortcycle or 0 ) + 1
		if pluginTimers.master.shortcycle >= 10 then
			L('err', "Problem! %1 consecutive timer runs with no delay!", pluginTimers.master.shortcycle)
			if pluginTimers.master.shortcycle >= 50 then error "Too many short cycles; aborting timer processing" end
		end
	else pluginTimers.master.shortcycle = nil end
	luup.call_delay( '_DelayCb', delay, lcbparm )
end

-- _DelayCb is the callback function that will dispatch to the module
function _DelayCb( parm )
	P("_DelayCb(%1)", parm)
	if tonumber( parm ) ~= pluginMasterSerial then
		P("_DelayCb() another timer sequence has started (that's OK); serial expected %1 got %2", pluginMasterSerial, parm)
		return
	end
	execTimers( parm )
end

PFB.delay.once = function( seconds, func, ... ) -- luacheck: ignore 212
	local pid
	if type(seconds) == "string" and type(func) == "number" then
		arg = arg or {}
		pid = seconds
		seconds = func
		func = table.remove(arg, 1)
		P("pluginTimer(%1,%2,%3,...)", pid, seconds, func)
	else
		seconds = tonumber(seconds) or error "Invalid (non-numeric) timer delay"
		pid = string.format("d-%x",  pluginNextTID )
		P("pluginTimer(%1,%2,...) new pid %3", seconds, func or nulltimer, pid)
	end
	if seconds < 0 then seconds = 0 end
	pluginNextTID = pluginNextTID + 1
	pluginTimers[pid] = { id=pid, when=os.time()+seconds, func=func or nulltimer, args=arg }
	scheduleNextDelayRun()
	return pid
end

-- Reschedule a timer. If an interval timer, the interval is reset. Otherwise, the next run is set
-- for the provided number of seconds.
PFB.delay.reschedule = function( pid, seconds, ... )
	if pluginTimers[pid] == nil then error("No timer "..tostring(pid)) end
	if pluginTimers[pid].interval then
		local delta = seconds - pluginTimers[pid].interval
		pluginTimers[pid].interval = seconds
		if ( pluginTimers[pid].when or 0 ) > 0 then
			pluginTimers[pid].when = pluginTimers[pid].when + delta
		end
	else
		pluginTimers[pid].when = os.time()+seconds
	end
	-- Caller can optionally supply new arguments for next call
	if arg and #arg then
		pluginTimers[pid].args = arg
	end
	scheduleNextDelayRun()
	return pid
end

PFB.delay.get = function( pid )
	return pluginTimers[pid]
end

-- Set up an interval on a recurring timer.
PFB.delay.interval = function( seconds, func, ... )
	P("pluginInterval(%1,%2,...)", seconds, func)
	local pid = PFB.delay.once( seconds, func, ... )
	pluginTimers[pid].interval = seconds
	return pid
end

PFB.delay.cancel = function( delayId )
	pluginTimers[tostring(delayId)] = nil
end

--[[ ===== STATE VARIABLE WATCH ===== --]]

PFB.watch = {}

-- Place watch on a device state variable
PFB.watch.set = function( dev, sid, var, func, ... )
	P("addDeviceWatch(%1,%2,%3)", dev, sid, var)
	if var and not sid then error("Watch of variable without serviceId is not supported") end
	local key = string.format( "%s/%s/%s", tostring(dev), tostring(sid or "*"), tostring(var or "*") )
	P("addDeviceWatch() key is %1", key)
	if not ( pluginWatches[key] or pluginWatches[string.format("%d/%s/*", dev, sid)] ) then
		P("addDeviceWatch() adding system watch for %1", key)
		luup.variable_watch( "_WatchCb", sid, var, dev )
		pluginWatches[key] = {}
	end
	local fkey = string.format( "%d:%s", PFB.device, tostring(func) )
	P("addDeviceWatch() subscribing %1 to %2", fkey, key)
	pluginWatches[key][fkey] = { dev=PFB.device, func=func, args=arg }
end

-- Remove watch on device state variable
PFB.watch.clear = function( dev, sid, var, func )
	P("clearDeviceWatch(%1,%2,%3,%4)", dev, sid, var, func)
	local key = string.format( "%s/%s/%s", tostring(dev), tostring(sid or "*"), tostring(var or "*") )
	local del = {}
	for fkey,v in pairs( pluginWatches[key] or {} ) do
		if v.dev == PFB.device and ( func==nil or func==v.func ) then
			table.insert( del, fkey )
		end
	end
	for _,v in ipairs( del ) do pluginWatches[key][v] = nil end
end

-- _WatchCb is the callback function that will dispatch to the module
function _WatchCb( dev, svc, var, oldVal, newVal )
	P("_WatchCb(%1,%2,%3,%4,%5)", dev, svc, var, oldVal, newVal)
	local function dispatchWatch( key )
		for fkey,d in pairs( pluginWatches[key] or {} ) do
			P("_WatchCb() dispatching watch %3 event %1 to %2", fkey, d.dev, key)
			local success,err = pcall( d.func, dev, svc, var, oldVal, newVal, d.dev, unpack( d.args or {} ) )
			if not success then
				L(logLevels.err, "Plugin's watch handler failed for %2/%3/%4: %1", err, dev, svc, var)
			end
		end
	end
	dispatchWatch( string.format( "%d/%s/%s", dev, svc, var ) )
	dispatchWatch( string.format( "%d/%s/*", dev, svc ) )
	dispatchWatch( string.format( "%d/*/*", dev ) )
end

--[[ ===== PLATFORM FUNCTIONS ===== --]]

PFB.platform = {}

PFB.platform.isOpenLuup = function()
	if pluginFlags.openluup == nil then
		pluginFlags.openluup = false
		for _,v in pairs( luup.devices ) do
			if v.device_type == "openLuup" and v.device_num_parent == 0 then
				pluginFlags.openluup = true
			end
		end
	end
	return pluginFlags.openluup
end

PFB.platform.gettInstallPath = function()
	if not pluginFlags.installPath then
		if PFB.platform.isOpenLuup() then
			local loader = require "openLuup.loader"
			if loader.find_file then
				-- This may be a bit ropey. Is AltAppStore always installed on openLuup? Need to ask akbooer
				installPath = loader.find_file( "D_AltAppStore.xml" ):gsub( "D_AltAppStore.xml$", "" )
			end
		else
			pluginFlags.installPath = "/etc/cmh-ludl/"
		end
	end
	return pluginFlags.installPath
end

--[[ ===== ACTIONS ===== --]]

function _ActionSetDebug( pdev, parms )
	P("actionSetDebug(%1,%2)", pdev, parms )
	PFB.logLevel = (parms.debug or 0) ~= 0 and logLevels.debug2 or logLevels.DEFAULT
	pluginFlags.debug = (parms.debug or 0) ~= 0
end

function _ActionSetLogLevel( pdev, parms )
	P("actionSetLogLevel(%1,%2)", pdev, parms)
	PFB.logLevel = tonumber( parms.NewLogLevel ) or logLevels[parms.NewLogLevel] or logLevels.DEFAULT
	PFB.var.set( pluginFlags.module.MYSID, "LogLevel", PFB.logLevel, pdev )
end

local function pluginStartupFailure( dev, msg )
	luup.set_failure( 1, dev )
	return false, msg or "Startup failed", pluginFlags.module._PLUGIN_NAME
end

function _Start( dev )
	local pluginName = luup.attr_get( "model", dev ) or ""
	assert( pluginName ~= "", "Plugin attribute 'model' is not set to plugin base name" )
	pluginModuleName = "L_" .. pluginName
	_, pluginFlags.module = pcall( require, pluginModuleName )
	assert( pluginFlags.module._PLUGIN_NAME, "Plugin implementation module does not define `_PLUGIN_NAME'" )
	assert( pluginFlags.module._PLUGIN_COMPACT, "Plugin implementation module does not define `_PLUGIN_COMPACT'")
	assert( pluginFlags.module.MYSID, "Plugin implementation module does not define `MYSID'")

	L('notice', "starting %2 device #%1", dev, pluginFlags.module._PLUGIN_NAME)

	PFB.var.init( "LogLevel", logLevels.DEFAULT, dev, pluginFlags.module.MYSID )
	PFB.logLevel = PFB.var.getNumeric( "LogLevel", logLevels.DEFAULT, dev, pluginFlags.module.MYSID )
	PFB.device = dev
	pluginWatches = {}
	pluginTimers = {}

	if PFB.var.set("Configured", "1") ~= "1" then
		P("one-time initialization for %1", dev)
		PFB.var.init( "DebugMode", 0 )
		if pluginFlags.module.runOnce then
			local ok,err = pcall( pluginFlags.module.runOnce, dev )
			if not ok then
				L({level=logLevels.err,msg="Plugin's runOnce() function failed: %1"}, err)
				return pluginStartupFailure( dev )
			end
		end
	end

	if PFB.var.getNumeric( "DebugMode", 0 ) ~= 0 then
		PFB.logLevel = logLevels['debug1']
		L(logLevels['debug1'], "Plugin debug enabled by state variable DebugMode")
	end
	L('debug1', "Using PluginFrameworkBasic %1 (rigpapa) https://github.com/toggledbits/PluginTools",
		PFB.VERSION)

	-- Check firmware version
	if pluginFlags.module.checkVersion then
		local ok,err,msg = pcall( pluginFlags.module.checkVersion, dev )
		if not ok then
			L(logLevels['err'], "Plugin checkVersion() failed: %1", err)
			return pluginStartupFailure( dev )
		end
		if not err then
			L(logLevels['err'], msg or "This plugin does not run on this firmware.")
			return pluginStartupFailure( dev )
		end
	end

	-- Register plugin request handler
	luup.register_handler("_RequestCb", pluginFlags.module._PLUGIN_REQUESTNAME or pluginFlags.module._PLUGIN_COMPACT)

	local success,ret,msg,name = pcall( pluginFlags.module.start, dev )
	if not success then
		L(logLevels['err'], "Plugin start() function failed: %1", ret)
		return pluginStartupFailure( dev )
	end
	name = name or pluginFlags.module._PLUGIN_NAME
	if ret == false then
		return ret, msg or "Didn't start", name
	end
	luup.set_failure( 0, dev )
	return true, "", name
end

--[[ ===== HTTP REQUESTS ===== --]]

PFB.request = {}

-- _RequestCb is the request handler; hands off to module function
function _RequestCb( req, parms, of )
	P("_RequestCb(%1,%2,%3)", req, parms, of)
	-- Built-in handler for turning debug on and off.
	if parms.debug then
		local n = tonumber( parms.debug )
		if n then
			pluginFlags.debug = n ~= 0
		else
			pluginFlags.debug = not pluginFlags.debug
		end
		return '{"debug":'..tostring(pluginFlags.debug)..',"PFB":'..PFB.VERSION..'}','application/json'
	elseif parms.PFBdump then
		return dump( { timestamp=os.time(), PFB=PFB,
			pluginWatches=pluginWatches, pluginTimers=pluginTimers, pluginRequest=pluginRequests,
			pluginFlags=pluginFlags } ),
			"text/plain"
	end
	for k,v in pairs( pluginRequests ) do
		P("_RequestCb() checking %1,%2",k,v)
		local var,val = k:match("^([^=]+)%=(.*)$")
		P("_RequestCb() checking if %1=%2 in parms, parms[%1]=%3", var, val, parms[var])
		if parms[var] == val then
			local success,r1,r2 = pcall( v.func, v.dev or PFB.device, parms, of, unpack(v.args or {}) )
			if not success then
				L('err','Request handler for %1 failed: %2', k, r1)
			end
			return ( r1 ~= nil ) and tostring(r1) or "OK\nRequest handler succeeded but returned no response data", r2 or "text/plain"
		end
	end
	-- Legacy behavior
	if pluginFlags.module.handleRequest then
		if type( pluginFlags.module.handleRequest ) ~= "function" then return "ERROR\r\nRequest handler not implemented for "..pluginFlags.module._PLUGIN_NAME, "text/plain" end
		return pluginFlags.module.handleRequest( req, parms, of, PFB.device )
	end
	return "ERROR\nPlugin request handler not implemented", "text/plain"
end

PFB.request.register = function( var, value, func, dev, ... )
	P("registerRequestHandler(%1,%2,%3,%4,%5)", var, value, func, dev, arg)
	dev = dev or PFB.device
	local key = string.format("%s=%s", tostring(var or "?"), tostring(value or ""))
	P("registerRequestHandler() key=%1", key)
	pluginRequests[key] = { dev=dev, func=func, args=arg }
end

--[[ ===== JOBS ===== --]]

PFB.job = {}

PFB.job.watch = function( devnum, jobnum, func, ... )
	P("pluginJobWatch(%1,%2,%3,...)", devnum, jobnum, func)
	local key = tostring( "%s;%s;%s", tostring(devnum), tostring(jobnum), tostring( func ) )
	if not next(pluginJobs or {}) then
		pluginJobs = {}
		luup.job_watch( '_JobCb' ) -- no device filter
	end
	pluginJobs[key] = { id=key, device=devnum, jobnum=jobnum, func=func, args=arg }
end
PFB.job.clear = nil -- TBD
PFB.job.register = nil -- TBD

local function _JobCb( jbt ) -- luacheck: ignore 211
	P("_JobCb(%1)", jbt)
	for _,d in pairs( pluginJobs or {} ) do
		if ( d.device==nil or d.device==jbt.device_num ) then
			local s,e = pcall( d.func, tonumber(jbt.notes) or nil, jbt, unpack( d.args or {} ) )
			if not s then
				L('err', "Job watch handler threw an error: %1; job data=%2", e, jbt)
			end
		end
	end
end

--[[ =====  COMMS ===== --]]

function _IncomingCb( dev, data ) -- luacheck: ignore 211
	P("_IncomingCb(%1,%2)", dev, data)
	if pluginFlags.module.handleIncomingData then
		local success,err = pcall( pluginFlags.module.handleIncomingData, data, dev, PFB.device )
		if not success then
			L('err', 'Plugin handleIncomingData() function failed: %1', err)
		end
	end
end

--[[ ===== IMPLEMENTATION ===== --]]

PFB.impl = {}

PFB.impl.dispatchAction = function( action, dev, params )
	local func = pluginFlags.module['action'..action]
	if func then
		local success,r1,r2 = pcall( func, dev, params or {} )
		if not success then
			L('err', "Function action"..tostring(action).." threw an error or returned an invalid status: %1", r1)
			return -- invalid return values
		end
		return r1, r2
	end
	L('err', "Function action"..tostring(action).." not found in plugin module or may be declared local")
	-- return nothing
end
PFB.impl.pluginDispatchAction = PFB.impl.dispatchAction -- legacy/deprecated to 2.0

--[[ ===== UPDATE WIP ===== --]]

local function pluginCheckForUpdate( guser, grepo, channelInfo, force )
	local gu = pcall( require, "GitUpdater" )
	if type(gu) ~= "table" then
		return false
	end
	if channelInfo == nil then channelInfo = gu.getBranchChannel( "master" ) end
	return gu.checkForUpdate( guser, grepo, channelInfo, force )
end

local function pluginDoUpdate( guser, grepo, uInfo )
	local gu = pcall( require, "GitUpdater" )
	if type(gu) ~= "table" then
		return false
	end
	if uInfo == nil then
		local status
		status, uInfo = gu.checkForUpdate( guser, grepo, gu.getBranchChannel( "master" ), false )
		if not status then return false end
	end
	return gu.doUpdate( uInfo )
end

local function installSubsystem( ident, mmod )
	if PFB[ident] == nil then PFB[ident] = mmod end
	return mmod
end
