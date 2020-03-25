module("L_PluginBasic1", package.seeall) -- !!! Fix name

-- _PLUGIN_NAME: !!! Set this to the friendly name of your plugin

_PLUGIN_NAME = "Plugin Framework Basic"	-- !!! Set me!

-- _PLUGIN_IDENT: !!! Set this to the short name of your plugin. Generally,
--                this should match the filenames of the plugin files, without
--                the prefix and suffix... L_PluginBasic1.lua ==> PluginBasic1

_PLUGIN_COMPACT = "PluginBasic1"

-- _PLUGIN_REQUESTNAME: !!! Set this to name to be used in the "id" field of
--                      Luup requests for the plugin. Those requests would look
--                      like:
--                      http://vera-ip/port_3480/data_request?id=lr_PluginBasic1
-- Default is same as compact, which is usually good and needs no changes.
_PLUGIN_REQUESTNAME = _PLUGIN_COMPACT

-- MYTYPE: The URN of your plugin's own device type. This must match exactly the
--         device type specified your device file (D_.xml)

MYTYPE = "urn:schemas-YOURDOMAIN-NAME:device:PluginBasic:1"	-- !!! Set me!

-- MYSID: The URN of your plugin's own service. This must match the service
--        named in the device file (D_.xml)
MYSID = "urn:YOURDOMAIN-NAME:serviceId:PluginBasic1"	-- !!! Set me!


--[[ ======================================================================= ]]

-- !!! Declare your module-global data here, and require any other modules your
--     implementation may need.

local someDataIneed = {}
-- Load other modules/packages like this:
local json = require "dkjson"

-- Shortcuts, because we can.
D = function( msg, ... ) PFB.log( PFB.LOGLEVEL.DEBUG1, msg, ... ) end
L = function( msg, ... ) PFB.log( PFB.LOGLEVEL.NOTICE, msg, ... ) end



--[[ ======================================================================= ]]

--[[   P L U G I N   M O D U L E   I M P L E M E N T A T I O N   ------------]]

-- !!! Add your implementation functions HERE. Modify the others below as indicated.

-- Check the current version of firmware running. Return true if OK, false and
-- error message if not. Modify this function as needed to do the right thing
-- for your plugin.
function checkVersion( pdev )
	D("checkVersion(%1)", pdev)
	--[[
	if PFB.isOpenLuup() then
		return false, "This plugin does not run on openLuup"
	end
	--]]
	if luup.version_major < 7 then
		return false, "This plugin only runs under UI7 or above"
	end
	return true
end

-- One-time initializations. Once the device is configured, this is not run again.
function runOnce( pdev )
	D("runOnce(%1)", pdev)
end

-- This example function will be called when our watched state variable changes.
local function variableChanged( dev, sid, var, oldVal, newVal, pdev, a, b )
	L("variableChanged() called! extra arguments: %1, %2", a, b)
end

-- This example function will be called by the demo timer set below in start()
local function timerExpired( tid, a, b )
	L("timerExpired() called! task %3 arguments: %1, %2", a, b, tid)
	-- Just for fun, update our example variable
	PFB.var.set( "ExampleVariable", "Now "..os.date("%X") )
end

-- Do local initialization of plugin instance data and get things rolling.
function start( pdev )
	D("start(%1)", pdev)

	if PFB.VERSION < 20022 then
		return false, "Please update PFB", _PLUGIN_NAME
	end

	-- Initialize your implementation local data here.
	someDataIneed = {}
	PFB.var.init( "Enabled", "1" )
	PFB.var.init( "ExampleVariable", "Initial Value" )

	-- Get your plugin rolling!

	-- Example: Make sure we're Enabled...
	if PFB.var.getNumeric( "Enabled", 1 ) == 0 then
		PFB.log( PFB.LOGLEVEL.WARN, "Disabled by configuration; aborting startup." )
		PFB.var.set( "ExampleVariable", "Disabled" )
		return true, "Disabled"
	end

	-- Here's an example of how to set watch on a device state variable. When
	-- the variable changes, the handleWatch() function above will be called.
	-- We watch our own variable, just because we know the device and variable exist.
	PFB.watch.set( pdev, MYSID, "ExampleVariable", variableChanged, "a1", "b2" )

	-- Set the variable to make the watch fire (see logged message that the
	-- variableChanged() function emits when it gets called).
	PFB.var.set( "ExampleVariable", "Started at "..os.date("%X"), pdev, MYSID )

	-- Here's how we get a function to run every five seconds (interval timer)
	local timerId = PFB.delay.interval( 5, timerExpired, "interval", "argument2" )
	PFB.log( "notice", "The interval task is %1", timerId )

	-- Here's how to get a function called once time in 60 seconds from now.
	-- This version uses a closure (an anonymous function). We pass the plugin
	-- device number as an argument through to the function.
	local onceId = PFB.delay.once( 60,
		function( tid, dev )
			PFB.log( 'notice', "Dev #%1 at 60 seconds after startup.", dev )
			PFB.delay.cancel( tid )
			-- Call our action just for fun
			luup.call_action( MYSID, "Example", { newValue=os.time(), force=1 }, dev )
		end,
		pdev
	)
	PFB.log( "notice", "The 60 second task is %1", onceId )

	-- Here's the "real" way (no shortcuts) to log something at various levels.
	PFB.loglevel = PFB.LOGLEVEL.DEBUG2 -- Set log level so we see all below
	PFB.log( PFB.LOGLEVEL.debug2, 'This is a debug2 level message' )
	PFB.log( PFB.LOGLEVEL.debug1, 'This is a debug1 level message' )
	PFB.log( PFB.LOGLEVEL.info, 'This is an info level message' )
	PFB.log( PFB.LOGLEVEL.notice, 'This is a notice level message' )
	PFB.log( PFB.LOGLEVEL.warn, 'This is a warn level message' )
	PFB.log( PFB.LOGLEVEL.err, 'This is an err level message' )
	PFB.loglevel = PFB.LOGLEVEL.DEFAULT -- Set log level so we see all below

	-- New-style request handlers
	PFB.request.register( "action", "test",
		function( dev, parms, output_format ) PFB.log( PFB.LOGLEVEL.notice, "request handler for action=test" ) end )
	PFB.request.register( "action", "clear",
		function( dev, parms, output_format ) PFB.log( PFB.LOGLEVEL.notice, "request handler for action=clear" ) end )

	-- If nothing else has gone wrong...
	L("Startup complete/successful!")
	return true
end

-- Required function to handle Luup requests (can be empty, but don't remove).
-- This function should return two values: string result and MIME type; the
-- string will be the response body, and the MIME type will be returned in the
-- Content-Type header. You can return anything you want, but the most common
-- are probably plain text (MIME text/plain), HTML (text/html), JSON data
-- (application/json), and XML (text/xml or application/xml).
function handleRequest( request, parameters, outputformat, pdev )
	D("handleRequest(%1,%2,%3,%4)", request, parameters, outputformat, pdev)
	-- Example code to handle http://your-vera-ip/port_3480/data_request?id=lr_PluginBasic&action=say&text=something
	if parameters.action == "say" then
		-- Return text as JSON-formatted response.
		return '{ "text": ' .. tostring(parameters.text) .. ' }', "application/json"
		-- or if we load the dkjson package and make it do the formatting of a Lua table:
		-- local json = require "dkjson"
		-- return json.encode( { text=parameters.text } ), "application/json"
	else
		return "ERROR\nInvalid request (2)", "text/plain"
	end
end



--[[ ======================================================================= ]]

--[[   P L U G I N   A C T I O N   I M P L E M E N T A T I O N   ------------]]

--[[
	!!! Put your action implementation functions down here. These should be
	    called from the implementation file's <action> tag for the action.
		Remember to return appropriate values for the type of action execution.
		<run> should return boolean true/false, <job> should return status
		and timeout (0 if you're not sure what that means).
		See http://wiki.micasaverde.com/index.php/Luup_Lua_extensions#function:_job_watch
--]]

-- Here's an example action implementation. It just does some nonsense thing
-- (sets the ExampleVariable variable to whatever). Note that the function is
-- not "local", so it can be seen from I_PluginBasic1.xml
function actionExample( pdev, parms )
	D("actionExample(%1,%2)", pdev, parms)
	L("The Example action has been invoked! Parameters=%1", parms)
	-- Use: luup.call_action( "urn:YOURDOMAIN-NAME:serviceId:PluginBasic1", "Example", { newValue="23" }, n )
	PFB.var.set( "ExampleVariable", parms.newValue )
end
