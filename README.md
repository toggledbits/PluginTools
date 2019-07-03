# PluginBasic - Template for Simple Vera/Luup Plugins

## Before You Begin
There are a few things you need to know before you dive in. **Please make sure you take the time to read and understand this section.** It's important. You'll bypass a lot of weird bugs and troublesome roadblocks if have the basic concepts I'm about to explain firmly under your belt.

### Services

The first thing you really need to understand is that all devices in Luup center around *services*. A service is a container for a capability or set of capabilities that are logically associated that the device has. For example, on-off (binary) switches implement the `urn:upnp-org:serviceId:SwitchPower1` service, which contains the `Target` and `Status` variables that hold the desired and current, respectively, state of the switch, and the `SetTarget` action, which is used to turn the switch on and off (and set the `Target` and `Status` variables accordingly). If we have a dimmer, it may also support the `urn:upnp-org:serviceId:Dimming1` service, which contains the state variables associated with brightness level (e.g. `LoadLevelTarget` and `LoadLevelStatus`) as well as the actions to control brightness (`SetLoadLevelTarget`) and other dimmer-like behaviors.  Elaborating on this further, our example device may also support the `urn:micasaverde-com:serviceId:EnergyMetering1` service, meaning it nows how to track and report its energy use (with the appurtenent state variables and actions). Services layer and are cumulative--every service named by a device means the device supports the added capabilities of that service.

Those funky `urn:upnp-org:blah blah blah` names are important, and you have to get them right. These names are actually called *service IDs*. Each service defines its own service ID. The devices name which services they support by enumerating a list of service IDs.

If you think about how a device can support multiple services, you may realize that it's possible for a service to define a state variable, for example, `Status`, that is such a common name that it's like to be used by another service as well. And that is true--this is exactly what happens. So, how does one keep them sorted out? The answer is that service ID--every state variable stored on a device is *not identified only by its name*, but rather by *the combination of service ID and state variable name*. This allows a device to have two different state variables named `Status`. The device further identifies them by knowing that one is associated with one service, and the other with another service. And in fact, if we want to refer to one of them, we have to use *both the service ID and variable name* to do so.

So another way to think of a service is to think of its as a namespace, since everything contained in the service (namespace) is isolated from other services (which have their own separate namespaces).

### Service IDs

You can see there's a rhythm to the structure of a service ID, and that's derived from UPnP. The specifics of that aren't really important to Vera Luup, and in fact, your service IDs can be anything, as long as they are unique, but we try to stick with convention and color inside the lines. So let's look at the structure of a service ID.

```
urn:upnp-org:serviceId:SwitchPower1
```

You can see that the service ID has four *elements*, each of which is separated by a colon (":"). The "urn" first element is a fixed string (never changes) that means *uniform resource name*, and it says that this string is a name for a well-known resource of some type. The second part, "upnp-org" is the *domain* that defines or contains the resource. It is actually a domain name with the dots changed to dashes, and it generally identifies the organization or entity that created and maintains the resource definition. Since binary switches are a standard UPnP thing, the "upnp-org" domain indicates that the service named here is a UPnP standard service (and maintained by upnp.org). The third element is the fixed string "serviceId" and says that this name (this URN) is the name of a UPnP service. Finally, the last element, "SwitchPower1" is the name of the service.

While the specific parts of the service ID have meaning, they aren't significant in Luup. The only thing that matters is that it's unique. You can have a service ID simply called "frodo" without any colons or the four elements, and that would work, it would just violate the "social convention" that we developers try to stick with.

And it turns out, that convention can be important. The four-element structure has that all important second part, the namespace domain. Without that, you and another develop could get into a big argument over whose plugin gets to define the "frodo" service. There's no argument, and no conflict, however, if you each define your service ID within the rules, because each of you will incorporate into your service ID a domain name, presumably one that own.

This is the first place where I think a lot of people go wrong in writing their own plugins: they borrow code from another plugin, and while they may change the service name in the service IDs to match their new plugin name, they don't change the domain name to something they own. This is how you end up with plugins and devices defining services in the `micasaverde-com`, which belongs to Micasaverde/eZLO/Vera. This is potentially dangerous, and must be avoided, as an ongoing practice of doing this increasingly leads to the chances that two plugins will try to use the same service ID. **YOU MUST USE YOUR OWN DOMAIN NAME TO CREATE YOUR OWN NAMESPACE FOR YOUR SERVICE IDS.** No exceptions. So, to create your own namespace, use your own domain name, and never a domain name that you don't own (and that includes upnp.org, micasaverde.com, futzle.com, etc.).

If you don't own a Internet domain name, no problem. I recommend you just use your Vera Community username with "-vera", such as "rigpapa-vera" (don't use that one--it's mine--this is just an example). So if I didn't own a domain name, I might have used this service for Reactor: `urn:rigpapa-vera:serviceId:Reactor1`.

## Lua

Vera plugins are (currently) written in Lua, specifically Lua 5.1. A lot of people gripe about this, but I think this is one of best choices Vera made in implementation--it's a very well-defined, lightweight language with a lot of capability, and it's high-performing on even legacy Vera's modest processors.

To write plugins for Vera, you need to know Lua. If you don't know Lua, it would help if you're fluent in C/C++, Python, or JavaScript. These languages are close enough, and your fluency with them likely has given you a base not just in writing code, but in thinking logically and algorithmically. If that's not you, though, I'll be honest: don't try to write a plugin for Vera. The learning curve is steep, and long. The language, really, is the least of it. If you don't have a good base and are comfortable writing code to solve problems, the relatively dismissive "just write a plugin" will burn you to the ground.

OK. Ready to begin? Let's get to the meat of it...

## First Steps

This section will cover what you need to do to give the template files the correct identities--those of you and your plugin. **Follow these instructions carefully and do the steps in exactly the order presented. Do not deviate.**

**THIS IS A GOOD TIME TO BACK UP YOUR VERA.** Small mistakes in these steps can lead to a configuration that reloads continuously, or other nasty things. If you don't have a backup to fall back on, you will have to rely on your own knowledge and/or Vera support for recovery. I cannot help you remotely.

### Step One: Decide on a Name

The first step is to decide on a name for your plugin. It's a good idea to search the Vera plugin marketplace (apps.mios.com) to see if there's an existing plugin with the name you would like to use. If so, you need to choose another name.

### Step Two: Identify Your Namespace

The namespace is the domain part of service IDs, device types, etc. Typically, as stated above, the namespace is taken from the Internet domain name associated with the author or responsible party. For example, if I owned the domain "example.com", then I would use "example-com" as the namespace. This is the recommended approach.

If you don't own an Internet domain name, you can make a namespace by using your Vera Community username with "-vera" appended, for example "johndoe-vera". The namespace doesn't need to actually exist as an object or entity somewhere on the internet, it's just a string that attempts to be unique enough that we don't have collisions between plugin developers. This approach, or an actual domain name you own, is sufficient for that purpose.

**What you must not do** is re-use "micasaverde-com" or "upnp-org", or the namespace belonging to another developer whose code you might be borrowing (famously, "futzle-com" has been widely abused by people who used @futzle's plugins as a starting point for their own). Using any namespace you don't control is a bad idea if only because it opens the risk of a collision in names with other people's work. Don't do it, please. Be a good developer-citizen.

### Step Three: Rename Files

Now that you have the names sorted. The first thing to do is rename all of the files.

Your chosen plugin name may have spaces or other characters that are not basic-filename-friendly, for example "Huawei Router Control". If that's the case, you'll need to create a "compact" version of the name to use for filenames and other things. Going with the example, you can just remove the spaces, creating "HuaweiRouterControl". You can also abbreviate or remove unnecessary words: "HuaweiRouterCtrl" or simply "HuaweiRouter". In any case, it must be free of spaces and all non-alphanumeric characters. Upper- and lowercase mix is fine, but all characters should be "low ASCII" (ASCII code < 128) and **no** international characters, Unicode, diacritical marks, etc. So basically, only upper- and lowercase A-Z and digits 0-9.

Once you have a compact form of your plugin name, rename all the plugin files, giving the compact form as a replacement for "PluginBasic" in the names. For example: `D_PluginBasic1.xml` becomes `D_HuaweiRouter1.xml`. The other files would become `D_HuaweiRouter1.json`, `I_HuaweiRouter1.xml`, `L_HuaWeiRouter1.lua`, and `S_HuaweiRouter1.xml`.

Notice that the example preserves the prefix (`D_`, `I_`, etc.), as well as the "1" that precedes the suffix, and the suffix itself. Very important that you keep that straight.

### Step Four: Global Change #1 -- Namespace

Now you're ready to make your first global change inside the files. It's simple. In all of the plugin files, change the string `YOURDOMAIN-NAME` (all caps as shown) to your selected namespace (from step 2 above). Make sure the new namespace string is all lowercase (so you are changing an all uppercase string to an all lowercase string).

After you've done all the files, move on.

### Step Five: Global Change #2 -- Plugin Name

Simple: *in each file*, global change the string "PluginBasic" to the compact name you used in step **three**. That is, change the search string to the same as that you used in all the filenames.

### Step Six: Other Code Changes and Checks

Make the following additional code changes in your L_ file (the Lua implementation module... more on that below):
* Change the definition of `_PLUGIN_NAME` to the friendly name of your plugin (spaces etc. OK here)
* Make sure `_PLUGIN_COMPACT` has the same *compact name* that was used in steps three and five above.

### Step Seven: Install and Run!

You can now install the template/skeleton and make it run. It won't do anything other than the canned/test/demo things that the framework ships with, but the fact that you can get the plugin started and doing those things demonstrates that you've made all of the changes correctly at least at the first level, and the system is able to run the code.

To install (Vera):
1. Using the upload at *Apps > Develop apps > Luup files*, or `scp` (which I happen to prefer), upload the files to your Vera. If using `scp`, place the files in `/etc/cmh-ludl/`. If using the UI-based uploader, drag all files as a group to the upload control. Alternately, you can upload one file at a time by click-and-pick, but you'll want to turn off "Restart luup after upload" until you get to the last file.
1. Create the first plugin device. Go to *Apps > Develop apps > Create device* and fill in the fields below; leave the rest blank. Then hit the "Create" button.
  * Description: The name of your plugin
  * UPnP Device Filename: `D_xxxx1.xml` (use the filename you assigned when renaming the files)
  * UPnP Implementation Filename: `I_xxxx1.xml1` (use the filename you assigned when renaming the files)
1. Go to *Apps > Develop apps > Test Luup code (Lua)* and enter and run: `luup.reload()`
1. Hard refresh your browser [How?](https://www.getfilecloud.com/blog/2015/03/tech-tip-how-to-do-hard-refresh-in-browsers/)

You should now see your device on the Devices list, in the "No Room" section. If everything is working as expected, it will be updating the displayed time about every 5 seconds.

### Step Eight: Check the LuaUPnP log

Examine the LuaUPnP log, which is `/var/log/cmh/LuaUPnP.log`. I don't recommend using `scp` to copy it, but you can `ssh` into your Vera and use the `less` command (e.g. `less /var/log/cmh/LuaUPnP.log`) to browse it. You can also browse it using a browser via local HTTP access: `http://your-vera-local-ip/cgi-bin/cmh/log.sh?Device=LuaUPnP` (this is my preferred method).

Search for the compact name and you'll pretty quickly find where the plugin starts. Here's what it looks like for the unmodified plugin framework:

```
50	07/03/19 14:32:41.083	luup_log:101: Using PluginFrameworkBasic 19184 (rigpapa) https://github.com/toggledbits/PluginTools <0x77136520>
50	07/03/19 14:32:41.083	luup_log:101: [notice] Plugin Framework Basic: starting device #101 <0x77136520>
50	07/03/19 14:32:41.088	luup_log:101: [notice] Plugin Framework Basic: variableChanged() called! extra arguments: "a1", "b2" <0x77136520>
50	07/03/19 14:32:41.093	luup_log:101: [debug2] Plugin Framework Basic: This is a debug2 level message <0x77136520>
50	07/03/19 14:32:41.093	luup_log:101: [debug1] Plugin Framework Basic: This is a debug1 level message <0x77136520>
50	07/03/19 14:32:41.093	luup_log:101: [info] Plugin Framework Basic: This is an info level message <0x77136520>
50	07/03/19 14:32:41.094	luup_log:101: [notice] Plugin Framework Basic: This is a notice level message <0x77136520>
02	07/03/19 14:32:41.094	luup_log:101: [warn] Plugin Framework Basic: This is a warn level message <0x77136520>
01	07/03/19 14:32:41.094	luup_log:101: [err] Plugin Framework Basic: This is an err level message <0x77136520>
50	07/03/19 14:32:41.112	luup_log:101: [notice] Plugin Framework Basic: Startup complete/successful! <0x77136520>
```

and then as the default implementation updates the time every five seconds, you'll see clusters like this:

```
50	07/03/19 14:32:46.102	luup_log:101: [notice] Plugin Framework Basic: timerExpired() called! arguments: "interval", "argument2" <0x74536520>
50	07/03/19 14:32:46.104	luup_log:101: [notice] Plugin Framework Basic: variableChanged() called! extra arguments: "a1", "b2" <0x74536520>
```

Take a look at the code in the Lua implementation module (`L_xxx1.xml`) and see if you can correlate the messages to their various sources.

## Plugin Structure

Now let's back off handling the code and get back to some important concept information.

A plugin is a small set of files that describe a device type and provide an implementation. The following are the files you will normally see defined, at a minimum, for a plugin:
* D_*pluginname*1.xml - This is called the *device file*, and it defines the device type associated with the plugin, and what service the device/plugin supports, among other details.
* I_*pluginname*1.xml - This is called the *implementation file*, and it contains the startup code for the plugin, the code for all actions the plugin implements, and sometimes (not necessarily) the core code of the plugin implementation.
* S_*pluginname*1.xml - This is called the *service file*, and it describes the plugin's own state variables and actions (those that it defines uniquely).

The device file, at a minimum, declares the device type for the plugin and what services the plugin devices provide. Here's the device file for PluginBasic:

```
<?xml version="1.0"?>
<!-- D_PluginBasic1.xml -->
<root xmlns="urn:schemas-upnp-org:device-1-0">
	<specVersion>
		<major>1</major>
		<minor>0</minor>
	</specVersion>
	<device>
		<deviceType>urn:schemas-YOURDOMAIN-NAME:device:PluginBasic:1</deviceType>
		<staticJson>D_PluginBasic1.json</staticJson>
		<friendlyName>PluginBasic</friendlyName>
		<manufacturer></manufacturer>
		<manufacturerURL></manufacturerURL>
		<modelDescription></modelDescription>
		<modelName></modelName>
		<handleChildren>0</handleChildren>
		<Category_Num>1</Category_Num>
		<Subcategory_Num>0</Subcategory_Num>
		<serviceList>
			<service>
				<serviceType>urn:schemas-YOURDOMAIN-NAME:service:PluginBasic:1</serviceType>
				<serviceId>urn:YOURDOMAIN-NAME:serviceId:PluginBasic1</serviceId>
				<SCPDURL>S_PluginBasic1.xml</SCPDURL>
			</service>
		</serviceList>
		<implementationList>
			<implementationFile>I_PluginBasic1.xml</implementationFile>
		</implementationList>
	</device>
</root>
```

The device file has to have the structure shown. Not all of the tags shown need to have values, but at a minimum, the `deviceType` tag must be provided, along with a `serviceList` tag containing `service` tags for each service the plugin supports, and an `implementationList` tag naming one `implementationFile`. If you look at the example above, you can see that the service list names one service (`PluginBasic1`) and, via the `SCPDURL` tag, points to `S_PluginBasic1.xml` as the file containing the definition of that service's state variables and actions.

So, the device file is really the "root" of a hierarchy pointing to other resources that make up the device/plugin definition.

The implementation file (`I_PluginBasic1.xml`) should contain the following top-level structure:

```
<?xml version="1.0" encoding="UTF-8"?>
<implementation>
	<functions></functions>
	<startup></startup>
	<actionList></actionList>
</implementation>
```

The `startup` tag's text content contains the *name* of the function that is used to initialize and start the plugin (not a call to it--just the name of it). The function itself should be defined in Lua code within the body of the `functions` tag. If you look at the default implementation file for PluginBasic, this is its `startup` tag:

```
<startup>startPluginBasicImpl</startup>
```

This declaration says that the plugin is started by having Luup call the function `startPluginBasicImpl`. Luup will call this function with a single argument: the device ID of the plugin device being started. The default declaration of the `startPluginBasicImpl` function looks like this:

```
<functions>
	-- -------------------------------------------------------------------------------------------------------------------------
	-- PluginBasic -- global change this to the name of your plugin (no spaces/specials) in all files.
	-- YOURDOMAIN-NAME -- global change this to your domain name in all files. If you don't have one, you can make up a personal
	--                    one, for example, johndoe-name. Should be all lower case. DO NOT USE micasaverde-com, upnp-org, futzle-com,
	--                    etc. as that is highjacking of others' namespace!
	-- -------------------------------------------------------------------------------------------------------------------------
	function startPluginBasicImpl(dev)

		luup.log( "PluginBasic luup startup " .. tostring(dev) )

		--[[
			Load and initialize the module that contains the core code.
			The pluginStart function will do the bulk of the work in getting
			things rolling.
		--]]
		PluginBasicModule = require("L_PluginBasic1")

		-- Register plugin request handler
		luup.register_handler("_RequestCb", "PluginBasic")
		
		-- Startup hand-off to module.
		return PluginBasicModule.pluginStart(dev)
	end
	
	...etc...
```

We'll ignore what this is actually doing at this moment. Just observe that the function is defined in the `functions` tag of the implementation file, and receives a single argument, which is the device number of the plugin device Luup wants started. The code of this function can do whatever it needs to do to make that happen, and we'll revisit that shortly.

The `actionList` section of the implementation file provides the implementation for all actions that the plugin supports, from its own service, and from any other associated service. Note that by the device file naming a service as being supported by the plugin, that does *not* provide a default implementation of any actions that service defines. Every action defined by a named service that the plugin supports must be implemented by the plugin. This is what allows the `SetTarget` action in the `SwitchPower1` service to function properly to turn on a light, even though one light might be a Z-Wave device and another is a WiFi-connected bulb, each requiring completely different steps to get them from "off" to "on".

At this point, you should know that the service file `S_PluginBasic1.xml` defines the state variables and actions that the plugin itself defines and maintains. It would therefore be expected (by Luup) that the actions named in the file have a corresponding implementation in the `actionList` of the implementation file. So hopefully you are now getting an idea of how interconnected these files are, and if you're a little confused, you are rightly so. It's just part of the learning curve, but don't worry, you'll get there.

There are a couple of other files in the PluginBasic package: D_PluginBasic1.json and L_PluginBasic1.lua. We'll cover these soon enough.

## Creating Your Plugin

In order to make the plugin do the work you want it to do, you will need to modify a few core functions in the Lua implementation module (`L_xxx1.lua`):

### start( dev )

You will always need to modify this function. It is called to initialize and start your plugin, so you need to modify it to contain whatever needs to be done to get the work started. All of your startup code should go in here. **Do not modify the startup code in `I_PluginBasic1.xml`.**

The function should return three values: a boolean (`true` or `false`) success code, and a message (or `nil`). If the first value returned is anything other than `false`, the framework assumes that your plugin code has started successfully and will clear the device error state and return a success indication to Luup. If the value is `false`, or if an error is thrown by your code, the device will enter error state and the message provided returned to Luup to be displayed as a device error.

Your startup code must initialize all plugin-specific data. You can declare any module-global data you need at the top of the Lua file in the area indicated for this purpose. You may also load (using `require`) any other packages your code needs.

### runOnce( dev )

The `runOnce()` function is called the first time your plugin code runs in a new device. Use this for any one-time initializations you may need to perform. It will not be called again, unless the `Configured` state variable is set to anything other than "1" (digit one). The framework manages this state variable and decides whether or not `runOnce()` needs to be called, so do not call it directly from your own startup code, and do not manipulate `Configured` in any way.

### checkVersion( dev )

The `checkVersion()` function is expected to return a boolean (true/false) indicating that the current running Vera/Luup firmware is compatible with the plugin. If `false` is returned, the startup of the plugin will be aborted. If anything other than `false` is return, the plugin will be started.

## Getting To Work

Once your startup code returns and startup completes, your plugin is sitting waiting for something to happen. You need to add code to react to things that your plugin needs to act on. These may include:
1. Time-based events, for example, handling the expiration of an interval timer;
2. Device-based events, for example, handling a change in the state of a device you are monitoring;
3. Handle an HTTP request made to the Vera with the plugin identified as the target to answer the request;
3. Actions, for example, a request from the user/UI to perform some task the plugin is capable of performing.

If you don't do any of the above, your plugin basically runs at startup and does nothing else, so it's very rare that a plugin won't need to have code to handle at least one of the above conditions.

## Additional Framework Functions

The framework provides a set of utility functions under the `PFB` global object that you can call from your module.

### Time Delays and Intervals

The `PFB.timer.once()` and `PFB.timer.interval()` functions call a function after a specified delay. In the case of the former, the call is made only once; in the case of the latter, the call is made repeatedly at the interval specified. Both functions have identical argument lists, further described below.

```
local function timerFinished( word, num )
	-- Stuff to do when the timer is done
end

PFB.timer.once( 5, timerFinished, "hello", 123 )
```

In the example above, you can see a prototypical function to handle the completion of a time interval, and the call to the timer function to call it after a five second delay. The timer function call takes at least two arguments: the time delay/interval in seconds, and the function reference to be called. Note that unlike `luup.call_delay()`, the function is specified by passing a function reference (basically, the function name without any parentheses or arguments). Any additional arguments to the timer call will be passed to the specified function; as we see in the above example, there is an additional string and numeric argument that will be passed and can be received the function.

Because these calls take a function reference rather than a string with a function name, the function used can be `local` in scope; it does not need to be global. In fact, it can even be a Lua closure (known as an anonymous function in JavaScript):

```
-- Turn the light on.
luup.call_action( 'urn:upnp-org:serviceId:SwitchPower1', 'SetTarget', { newTargetValue="1" }, 123 )
-- Turn the light off after five seconds.
PFB.timer.once( 5, function() 
	luup.call_action( 'urn:upnp-org:serviceId:SwitchPower1', 'SetTarget', { newTargetValue="0" }, 123 )
end )
```

Both functions will return a timer ID. There is only one purpose to this ID at this time: to cancel a timer. 

A timer can be cancelled by passing its timer ID to `PFB.timer.cancel( timerID )`.

You can run as many timers as you wish. The framework manages the scheduling of all of the timers and ensures that they are run as close to on time as Luup and the OS will permit. When two timers expire at the same time, their handler functions are run serially, and the order of their execution is non-deterministic (that is, there's no telling which will execute first). 

The use of these functions over the `luup.call_delay()/call_timer()` functions is highly recommended.

### Device State Variable/Service Watches

Your plugin can watch a state variable on a device, or all state variables in a service on a device, by calling `PFB.watch.set( dev, serviceId, variableName, func, ... )`. 
When the variable named on the specified device is changed, the framework will call the specified handler function (passed as a *function reference*, not a string containing the name). If there are arguments after the function reference, these "extra arguments" will be passed to the handler function later. If the `variableName` argument is omitted or `nil`, the watch handler will be called when *any* state variable in the named service on the device is modified.

Your handler function must accept the following arguments that will be passed to it: `watchedDevice, serviceId, variableName, oldVal, newVal,  dev, ...`. The first three arguments received are the device number, service ID, and name of the changed variable. The `oldVal` argument is the prior value of the variable, and `newVal` is the new/current value. The `dev` argument is the plugin device number. If any extra arguments were passed to `PFB.watch.set()`, they will be passed to the handler after `dev`.

Like the timer functions above, the fact that a function reference is used allows the handler function to be in any scope, it does not need to be a global as Luup's `luup.variable_watch` requires. And it can even be a closure.

### Request Handler

TBD

### Logging

Developing plugins will require that you write helpful diagnostic data someplace that you can get to it.

The `PFB.debug(msg, ...)` and `PFB.log(msg, ...)` functions both log messages to the LuaUPnP log. The former (`debug`) only writes the message if debug is enabled (the global variable `debugMode` is set `true`).

The message may contain references to additional arguments passed, identified by "%" followed by a number. When these are found in the message string, they are replaced with the text form of the indexed argument from the remaining arguments. They do not need to be used in order of the values passed. For example, `L("this is %1 and %2, or backwards %2 and %1", "alpha", "beta")` will log the string "this is alpha and beta, or backwards beta and alpha". The arguments can be any Lua data type; tables will be expanded into a human-readable pseudocode representation.

### State Variable Handling

The framework provides some convenience functions as alternatives to the Luup built-in `luup.variable_get()` and `luup.variable_set()`.

The `PFB.var.get( variableName [, dev [, serviceId]] )` function returns the value of the named state variable on the specified device from the specified service, and the timestamp of the last modification (two values returned). If the service is omitted or `nil`, the plugin's service ID is assumed; if the device is omitted or `nil`, the plugin device is assumed. So, it is possible to retrieve the value of a variable belonging to the plugin device in the plugin service using only one argument, for example `PFB.var.get( "DebugMode" )`. Note that since this function returns two values, extra care must be taken when attempting to wrap this function in other functions like `tonumber()` (the Luup standard function has the same issue). Specifically for the case where `tonumber()` is desirable, use `PFB.var.getNumeric()` below, instead.

The `PFB.var.getNumeric( variableName, defaultValue [, dev [, serviceId]] )` function returns the numeric value of a state variable. If the state variable is undefined, blank, or can't be converted to a number, the value of the `defaultValue` argument will be returned. For example, `PFB.var.getNumeric( 'Status', -1, 45, 'urn:upnp-org:serviceId:SwitchPower1' )` would get the value of the `Status` variable in the SwitchPower1 service from device 45, or if it doesn't exist, returns -1.

The `PFB.var.init( variableName, value [, dev [, serviceId]] )` function initializes the value of a state variable to the value given *if it does not exist*; if it exists, it is not modified. 

The `PFB.var.set( variableName, value [, dev [, serviceId]] )` function sets a state variable to the given value. If the state variable's current value is already equal to the target value, the variable is not changed, preserving the timestamp of the state variable, preventing modification of user_data as a result of the call, and preventing watches from triggering.

## Using State Variables in Your Plugin

State variables store data in a persistent fashion. The value of state variables is stored in a Luup structure called `user_data`, and this is periodically written to non-volatile storage.

You can create your own state variables as needed by your plugin.

1. When creating a new state variable, be sure to initialize it in your `runOnce()` or `start()` code.
1. Declare state variables that should be "public" (e.g. contain data that may be useful outside of the plugin) in your plugin's service file (`S_.xml`).
1. **DO NOT** create new state variables using other services--only create new variables in services you create and own as well, no matter what device you create it on. For example, it would be incorrect for your plugin to store some special data about a switch that it supervises in a new `MyData` variable in the `urn:upnp-org:serviceId:SwitchPower1` service--that is not a standard variable defined by the SwitchPower1 service. You can go ahead and use the `MyData` variable name, but use a service Id that's defined by your plugin instead.

## Defining New Service Actions

The service file (`S_.xml`) defines the actions of the related service. Since your plugin has its own service, that's the file in which you can declare your plugin-specific actions. By default, it contains only an example action called `Example`, and a framework action to set the debug/logging level called `SetLogLevel`.

If you want to create a new action in the plugin service, you must add its declaration in the plugin service's service file. The steps are pretty straightforward:
1. Decide on a name for the new action;
1. Declare the new action in the service file;
   * Must include the `name` tag with the action name; 
   * Must include the `argumentList` tag, and enumerate arguments the action takes (it can be empty if there are none);
   * Each `argument` in the `argumentList` must contain `name` and `direction` tags. It is recommended/best-practice to always use `relatedStateVariable` as well. the related variable *must* be declared in the `stateVariables` section of the service file. If there is no related state variable, the A_ARG_TYPE_nnnn variable may be used/added, where nnnn is the UPnP data type (e.g. string, boolean, i4, ui4, i2, ui2, i1, ui1, r4) of the argument.
1. Provide an implementation of the action (next section).

**Do not modify any service file in `/etc/cmh-lu` (the directory where Vera's defined services are kept), or the service file of any plugin you don't own.** For example, you must not create new actions for the `SwitchPower1` service; that's a standard service, and it's untouchable.

## Implementing Service Actions 

Your plugin must provide an implementation for all service actions it is capable of performing in services it declares. This includes all actions defined by the plugin's own service, but also may include other services named in the device file (D_.xml). For example, if your plugin declares that it *supports* the `urn:upnp-org:serviceId:SwitchPower1` service (that is, it can emulate the standard behaviors of a binary switch), it should provide an implementation for `SetTarget` (the most commonly-used action in that service), and any other actions of that service that it can perform.

To implement an action:
1. Make sure the service to which the action belongs is declared in the plugin's device file (D_.xml).
1. Find the service file in which the action is declared, to make sure you have the complete definition of the action. For Vera-defined service, you will find the service files in `/etc/cmh-lu` on your Vera.
1. Declare the implementation in the implementation file's `actionList` section. Add an `action` tag, and inside it, add a `serviceId` tag containing the full service ID of the action, a `name` tag containing the name of the action, and a `run` and/or `job` tag containing an implementation stub that hands control to a handler function you create in `L_PluginBasic1.lua`.
1. In `L_PluginBasic1.lua`, create a handler function for the action and provide the action implementation within in. By convention, the handler function should be called `actionXXX`, where XXX is the name of the action.

As an example, let's say our plugin can, among other things, emulate a binary switch to control its operation and report its status--it can act like a virtual switch. It will thus need to declare that it supports the `urn:upnp-org:serviceId:SwitchPower1` service, and implement the `SetTarget` action of that service, as well as handle the related state variables `Target` and `Status`.

The first thing we need to do is make sure that our plugin's device file declares our support of the "SwitchPower1" service, like this:

```
<?xml version="1.0"?>
<!-- D_PluginBasic1.xml -->
<root xmlns="urn:schemas-upnp-org:device-1-0">
	...etc..
	<device>
		...etc...
		<serviceList>
			<service>
				<serviceType>urn:schemas-YOURDOMAIN-NAME:service:PluginBasic:1</serviceType>
				<serviceId>urn:YOURDOMAIN-NAME:serviceId:PluginBasic1</serviceId>
				<SCPDURL>S_PluginBasic1.xml</SCPDURL>
			</service>
			...other services if any...
			<service>
				<serviceType>urn:schemas-upnp-org:service:SwitchPower:1</serviceType>
				<serviceId>urn:upnp-org:serviceId:SwitchPower1</serviceId>
				<SCPDURL>S_SwitchPower1.xml</SCPDURL>
			</service>
		</serviceList>
		...etc...
```

Now at step 2, if we look at the declaraction of `SetTarget` in Vera's service file `/etc/cmh-lu/S_SwitchPower1.xml`, we see that the action is declared thus:

```
    <action>
    <name>SetTarget</name>
      <argumentList>
        <argument>
          <name>newTargetValue</name>
          <direction>in</direction>
          <relatedStateVariable>Target</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
```

So that tells us two important things about our implementation: (1) the action must receive and handle a single argument called `newTargetValue`, and (2) whatever else our implementation needs to do, we need to make sure write the value of `newTargetValue` to the `Target` state variable (declared related) on the device.

With that in mind, on to step 3... declaring our action implementation in the plugin's implementation file. In the `actionList` section, add the following:

```
		 <action>
			<serviceId>urn:upnp-org:serviceId:SwitchPower1</serviceId>
			<name>SetTarget</name>
			<run>
				return _fpm.actionSetTarget( lul_device, lul_settings )
			</run>
		</action>
```

When you start out writing plugins, I recommend that every action implementation you place in the implementation file (`I_.xml`) be exactly and only as shown above. Remember that the `serviceId` needs to match that of the action named in `name`. The Lua code in the `run` section just calls the module's function to do the actual work, following my practice that as little as is necessary is done in the implementation file. The framework global variable `_fpm` used above is a reference to your loaded Lua module--this is how you access your functions within it.

Finally, for step 4, we just need to provide the "real" implementation of the action in the Lua module (`L_.lua`). Notice that the function name matches that in the `run` section of the implementation file, and that the function is **not** `local`--this must be, so that the implementation file can access it (it would be hidden/inaccessible if it was declared `local`).

```
function actionSetTarget( dev, arguments )
	setVar( "Target", arguments.newTargetValue, dev, "urn:upnp-org:serviceId:SwitchPower1" )
	if arguments.newTargetValue == "0" then
		-- Do whatever needs to be done to turn "off"
		-- Success? Make sure Status is updated to reflect new state
		setVar( "Status", "0", dev, "urn:upnp-org:serviceId:SwitchPower1" )
	else
		-- Do whatever needs to be done to turn "on"
		-- Success? Make sure Status is updated to reflect new state
		setVar( "Status", "1", dev, "urn:upnp-org:serviceId:SwitchPower1" )
	end
end
```

Note that our implementation prototype above also takes care of setting the `Status` variable of the SwitchPower1 service. This variable stores the actual state of the device. The `Target` is the desired state, and `Status` is updated when the device actually makes it into that target state. This is part of the "contract" of how SwitchPower1 is normally implemented on Vera. When you provide implementations for services, you will likely need to understand and uphold many of these "contract" details, which, unfortunately, are in large part not documented--you'll learn by doing. Sometimes, you will simply need to study the behavior of similar devices carefully to discover the "right" way your implementation should work. The Vera Community is an excellent resourcing for moving your knowledge ahead in these areas as well.

At this point, you should have a pretty good idea of how this all hangs together. The device file (`D_.xml`) tells Luup which services the device supports. Luup goes out and reads the service files (`S_.xml`) for each of those services to understand the specific state variables and actions the services provide. When an action is invoked, Luup makes sure the service and action are part of the device's declared support, and if so, goes to the device's implementation file's `actionList` to find the action implementation and execute it. If any part of this chain is broken, the LuaUPnP log file will contain errors saying that the action isn't supported by the device.

> NOTE: A common error that causes an action to be reported "not supported" when it appears everything is wired properly is a mispelling or change in capitalization of a name somewhere. Check every single reference, service Id, and name from the device file through the implementation and plugin module. It only takes a one-character difference to make the whole thing unravel.

## Reference
* `PFB.VERSION`  
   The current version of the Plugin Framework Basic
* `PFB.device`  
  The device number of the plugin instance currently running

* `PFB.log( level, message, ... )`  
  Log a message to the log stream. The `level` argument can be selected from `PFB.LOGLEVEL`. The message is not logged if the `level` is less critical than the current value of `PFB.loglevel`. The message argument may contain position parameters, identified by a "%" character followed by a number; the corresponding extra argument (from among the ...) is inserted at that position in the output message.
* `PFB.LOGLEVEL`  
  A table of constants for the various log levels. Includes (upper- and lowercase): ERR, WARN, NOTICE, INFO, DEBUG1, DEBUG2. These are used to pass to `PFB.log()` or set `PFB.loglevel`. The DEFAULT key is the default logging level for the framework (currently == INFO).
* `PFB.loglevel`  
  The current logging level. Messages less critical than this level will not be output to the log stream.
  
* `PFB.var.getVar( variableName [, device [, serviceId ] ] )`  
  Returns (two values) the current value and timestamp of the named state variable. May be called with 1-3 arguments; if `device` is omitted or `nil`, the plugin device is assumed. if `serviceId` is omitted or `nil`, the plugin's service is assumed.
* `PFB.var.getVarNumeric( variableName, defaultValue [, device [, serviceId ] ] )`  
  Returns the numeric value of the named state variable. If the state variable is not defined, or its value blank or non-numeric, the value of `defaultValue` is returned. The `device` and `serviceId` parameters are optional and default as they do in `getVar()`.
* `PFB.var.setVar( variableName, value [, device [, serviceId ] ] )`  
  Sets the value of the named state variable to the value given, and returns the prior value. The `device` and `serviceId` parameters are optional and default as they do in `getVar()`.
* `PFB.var.initVar( variableName, defaultValue [, device [, serviceId ] ] )`
  Like setVar, but does *not* set the state variable if it already exists. Used for one-time initialization, primarily.
  
* `PFB.timer.once( seconds, func, ... )`  
  Run a one-time timer for the specified number of seconds; upon its expiration, call the *function reference* (not a string) provided in `func` with any remaining arguments passed through. Returns a timer ID, which may be used to cancel the timer before its expiration by calling `PFB.timer.cancel()`.
* `PFB.timer.interval( seconds, func, ... )`  
  Like `PFB.timer.once()` in every respect, except that the timer recurs on the interval provided automatically until cancelled.
* `PFB.timer.cancel( timerID )`  
  Cancel the timer identified by `timerID`.
  
* `PFB.watch.set( device, serviceId, variableName, func, ... )`  
  Places a watch on the named state variable on the device. When it changes, the function (a *function reference*, not a string) will be called with the extra arguments passed through. If the `variableName` is `nil`, changes to any variable in the service on the device will trigger a call to the function/handler.
* `PFB.watch.cancel( device, serviceId, variableName [, func ] )  
  Cancel a watch on a device state variable. If `func` is specified, only the watch that calls the function (passed by reference) is cancelled; otherwise, all watches for the device/state are cancelled.

* `PFB.isOpenLuup()`  
  Returns `true` if running under openLuup, `false` otherwise.
