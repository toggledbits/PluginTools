# Plugin Framework Basic - Template for Simple Vera/Luup Plugins

This document corresponds to framework version 19184.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Before You Begin (DO NOT SKIP THIS SECTION)](#before-you-begin-do-not-skip-this-section)
  - [Services](#services)
  - [Service IDs](#service-ids)
  - [Defining Your Own Namespace](#defining-your-own-namespace)
  - [Lua](#lua)
  - [Development Environment](#development-environment)
- [First Steps (Setting Up a New Plugin)](#first-steps-setting-up-a-new-plugin)
  - [Step One: Decide on a Name](#step-one-decide-on-a-name)
  - [Step Two: Identify Your Namespace](#step-two-identify-your-namespace)
  - [Step Three: Rename Files](#step-three-rename-files)
  - [Step Four: Global Change #1 -- Namespace](#step-four-global-change-1----namespace)
  - [Step Five: Global Change #2 -- Plugin Name](#step-five-global-change-2----plugin-name)
  - [Step Six: Other Code Changes and Checks](#step-six-other-code-changes-and-checks)
  - [Step Seven: Install and Run!](#step-seven-install-and-run)
  - [Step Eight: Check the LuaUPnP log](#step-eight-check-the-luaupnp-log)
- [Plugin Structure](#plugin-structure)
  - [Core Plugin/Device Definition Files](#core-plugindevice-definition-files)
  - [How Actions Work](#how-actions-work)
  - [Other Plugin Files](#other-plugin-files)
- [Creating Your Plugin](#creating-your-plugin)
  - [`start( dev )`](#start-dev-)
  - [`runOnce( dev )`](#runonce-dev-)
  - [`checkVersion( dev )`](#checkversion-dev-)
- [Getting To Work](#getting-to-work)
  - [Using State Variables in Your Plugin](#using-state-variables-in-your-plugin)
  - [Defining New Service Actions](#defining-new-service-actions)
  - [Implementing Service Actions](#implementing-service-actions)
- [Additional Framework Functions](#additional-framework-functions)
  - [Time Delays and Intervals](#time-delays-and-intervals)
  - [Device State Variable/Service Watches](#device-state-variableservice-watches)
  - [Request Handler](#request-handler)
  - [State Variable Handling](#state-variable-handling)
  - [Logging](#logging)
- [Reference](#reference)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Before You Begin (DO NOT SKIP THIS SECTION)
There are a few things you need to know before you dive in. **Please make sure you take the time to read and understand this section.** It's important. You'll bypass a lot of weird bugs and troublesome roadblocks if have the basic concepts I'm about to explain firmly under your belt.

### Services

The first thing you really need to understand is that all devices in Luup center around *services*. A service is a container for logically-related set set of capabilities that the device has. For example, on-off (binary) switches implement the `urn:upnp-org:serviceId:SwitchPower1` service, which contains the `Target` and `Status` variables that hold the desired and current, respectively, state of the switch, and the `SetTarget` action, which is used to turn the switch on and off (and set the `Target` and `Status` variables accordingly). If we have a dimmer, it may also support the `urn:upnp-org:serviceId:Dimming1` service, which contains the state variables associated with brightness level (e.g. `LoadLevelTarget` and `LoadLevelStatus`) as well as the actions to control brightness (`SetLoadLevelTarget`) and other dimmer-like behaviors.  Elaborating on this further, our example device may also support the `urn:micasaverde-com:serviceId:EnergyMetering1` service, meaning it nows how to track and report its energy use (with the appurtenent state variables and actions). Services layer and are cumulative--every service named by a device means the device supports the added capabilities of that service. So a typical dimmer supports these three services at least. If it's capable of RGB control, then there's another service added for that, and so on.

Those funky `urn:upnp-org:blah blah blah` names are important, and you have to get them right. These names are actually called *service IDs*. Each service is uniquely identified by its own service ID. Devices specify which services they support by enumerating those service IDs.

### Service IDs

Service IDs identify a single service that contain the service's resources. They are, in essence, a *namespace* for resources associated with a service. Egad. What does all that mean?

A namespace is simply an identifier (string) that is paired with another resource identifier (like a name or number) that helps more uniquely identify the resource and separate it from others in the same environment that may have the same name. For example, let's say you want to fly somewhere, and so you book Lufthansa flight 100 out of your local airport to where you're going. As it happens, Delta and United also have flights numbered 100 out of the same airport. On the day of your flight, you show up at the airport, late as usual, and hurriedly ask the Information Desk where flight 100 is boarding. What's the first question you will be asked in response? "What airline?" of course. Basically, "flight 100" is the resource name, but Delta, United, and Lufthansa are the namespaces that identify and separate all the "flight 100"'s so you can board the correct one. A resource is "owned" in a namespace, so to correctly identify the right resource, you need to refer to it *both* by its namespace (Lufthansa) and its specific resource name (flight 100). The goal of namespaces is to create something unique enough that when coupled with the other identifying element(s) (a name, for example), one single resource is uniquely identified from all of the possible same-named/numbered resources that may exist in the environment.

To show the importance of namespaces in Luup, say you had a heating/cooling thermostat and you need to query it for its current setpoint. It has two setpoints--one for heating and one for cooling--so querying for "CurrentSetpoint" alone is ambiguous--you need to tell it which you want! Likewise, a lot of different services have a variable called "Status" that they use for some purpose. It's a very descriptive but also very generic name. Imagine the confusion (and complete disaster) that could happen if all those services tried to control the same variable! Requiring that both the service ID and variable name be provided to query or set a variable removes this ambiguity.

So variables, actions, and other resources in Vera are usually not just identified by name alone, but by the combination of a name and another string, such as a service ID.

Taking a closer look at service IDs (and other namespaces in Vera), you can see there's a rhythm to their structure. They follow the UPnP standard (loosely). Let's look at a common one:

```
urn:upnp-org:serviceId:SwitchPower1
```

You can see that the service ID has four *elements*, each of which is separated by a colon (":"). The "urn" first element is a fixed string (never changes) that means [*uniform resource name*](https://en.wikipedia.org/wiki/Uniform_Resource_Name), saying this string is a name for a well-known resource of some type. The second part, "upnp-org", is the namespace part of the service ID. It is usually derived from an Internet domain name, with the dots changed to dashes, but can be anything as long as it uniquely identifies the organization or entity that created and maintains the resource definition. Since binary switches have a standard UPnP definition, UPnP.org owns the definition and so the "upnp-org" namespace is used here. The third element is the fixed string "serviceId" and says that this URN is the name of a UPnP service (not a device type or other identifier). Finally, the last element, "SwitchPower1" is the name of the service itself. 

> Really, elements one and three aren't necessary; it would be just as unique to use the shortcut `upnp-org:SwitchPower1`, since the "urn" and "serviceId" strings are repeated in all service IDs, so don't contribute to their uniqueness. But we don't do this because Vera would not see them as literally equal, and Vera uses the longer form. But for services that Vera doesn't define, we could in fact choose anything we want, because the specifics of the string's structure aren't actually significant to Vera/Luup, the string just needs to be unique.  You could have a service ID simply called "frodo" without any colons or the four elements, and that would work, it would just violate the "social convention" that we developers try to stick with by using the UPnP form.

### Defining Your Own Namespace

As a Vera developer, you will be in the position of creating new services. As such, you need a namespace--a string that identifies you alone, or at least has a low risk of being used by others in the Vera world--in which your new services can be defined. Ignoring this requirement is the first place where I think a lot of new Vera developers go wrong in writing their own plugins: they use someone else's plugin as a template to get started, and while they must change the service name in the service IDs to match their new plugin name, they don't change the namespace to something they own, so they are effectively highjacking someone else's namespace/domain. This is how you end up with third-party plugins and devices defining new services in the `micasaverde-com` namespace, which belongs to eZLO/Vera. It also seems a lot of early Vera developers copied code from @futzle as a starting point for their new plugins, and as a result many old plugins in the app marketplace use the "futzle-com" namespace--and because of this, *she has often been asked for support for plugins that she didn't write!* Never use a namespace/domain that you don't own (and that includes upnp-org, micasaverde-com, futzle-com, etc.) for your new work.

Here are two good, simple ways to create your own namespace: base it on an Internet domain name you own, or base it on your Vera Community user name.

The best-practice way to create your own namespace is to follow the UPnP convention Vera uses and use an Internet domain name that you own and plan on keeping indefinitely. So, if you happen to own "example.com", your UPnP namespace would be "example-com", and all of your service IDs and device types would use that as their second element (e.g. `urn:example-com:serviceId:SomeService1`).

If you don't own a Internet domain name, no problem. I recommend you just use your Vera Community username with "-vera", such as "rigpapa-vera" (don't use *that* one, of course--it's mine!--it's just an example). This also has the advantage of making it very easy for users to identify you as the developer of the plugin or responsible for a service definition they also may want to use, so you may want to use this approach even if you do own an Internet domain name.

### Lua

Vera plugins are (currently) written in Lua, specifically Lua 5.1. A lot of people gripe about this, but I think this is one of best choices Vera made in implementation--it's a very well-defined, lightweight language with a lot of capability, and it's high-performing on even legacy Vera's modest processors. At the end of the day, it's just a tool. How you use the tool is more important than what the tool is, IMO.

To write plugins for Vera, you need to know Lua. If you don't know Lua, learning it will be eased if you're fluent in C/C++, Python, or JavaScript. These languages are close enough, and your fluency with them likely has given you a base not just in writing code, but in thinking logically and algorithmically. The Vera development learning curve is steep and long, though, because the syntax of the language is really the easiest part. Much harder is learning the Luup library functions, and all of the particulars and nuances of how Luup operates and plugins execute in the Luup environment. Having a methodical approach to solving problems (as opposed to shot-gunning and just trying things until something appears to work) is also a big help. If that's not you, though, I'll be honest: don't try to write a plugin for Vera. You're gonna have a bad time.

There are a lot of good, free resources for Lua and learning Lua online, easily found by search. It is also easy to download and install Lua on Windows, Mac, or your Linux desktop, so you can play with it locally.

### Development Environment

There is a good integrated development environment out there that connects to Vera and openLuup (search for "ZeroBrane Studio" or query community user @akbooer on the Vera Community Forums). I personally just use a text editor (Notepad++) on my Windows desktop or Geany on Ubuntu; I find IDEs too constraining, but appreciate basic syntax highlighting.

I think it is *much* easier to develop plugins on openLuup than on Vera directly. It's a good enough emulation that only the outliers of Vera peculiarisms would be out of your reach (and then you can just do that part directly on Vera). Installed locally on your desktop or made reachable by NFS/Samba network share, you can edit your source files in place (you have to upload every change to Vera, unless you relish using `vi` or `nano` over an `ssh` terminal on the Vera directly), and Luup reloads (which you'll do a lot) are instantaneous. It is also much more forgiving of some things that are big landmines on Vera and can leave you in a hard reload loop or worse.

In particular, if you only have one Vera, and you use it to control your house or you do not have continuous local access to it, I strongly recommend you use openLuup for all development. It will make accidents less tragic.

> FYI, my development environment is openLuup running on an Ubuntu VM, a Windows desktop with Notepad++ for editing, and an Ubuntu laptop with openLuup and Geany for work on the road. I also have a Vera3 and VeraPlus separate from my "production" (spouse-facing) unit so I can test/reboot/crash/factory reset at will. Although my Veras are "burners" (I don't care what's on them and can wipe them to factory fresh at will), I still think backups are necessary and save time.

OK. Ready to begin? Let's get to the meat of it...

## First Steps (Setting Up a New Plugin)

This section will cover what you need to do to give the template files the correct identities--those of you and your plugin. **Follow these instructions carefully and do the steps in exactly the order presented. Do not deviate.**

**THIS IS A GOOD TIME TO BACK UP YOUR VERA.** Small mistakes in these steps can lead to a configuration that reloads continuously, or other nasty things. If you don't have a backup to fall back on, you will have to rely on your own knowledge and/or Vera support for recovery. I cannot help you remotely.

### Step One: Decide on a Name

The first step is to decide on a name for your plugin. It's a good idea to search the Vera plugin marketplace (apps.mios.com) to see if there's an existing plugin with the name you would like to use. If so, you need to choose another name.

### Step Two: Identify Your Namespace

I know you read the "Service IDs" and "Defining Your Own Namespace" sections above *thoroughly* and already have identified your namespace. What? No?!? Please go back and do it!

Your namespace should be used by all plugins you create. If you've created another plugin with a namespace you own, use the same namespace for this new plugin. Otherwise, create a brand new namespace for yourself as recommended above using either a domain name that you own as a base, or the "veracommunityusername-vera" approach I talked about earlier.

**What you must not do** is re-use "micasaverde-com", "upnp-org", "futzle-com" or any namespace belonging to another developer whose code you might be borrowing. Please be e a good developer-citizen.

### Step Three: Rename Files

Now that you have the names sorted. The first thing to do is rename all of the files.

Your chosen plugin name may have spaces or other characters that are not basic-filename-friendly, for example "Huawei Router Control". If that's the case, you'll need to create a "compact" version of the name to use for filenames and other things. Going with the example, you can just remove the spaces, creating "HuaweiRouterControl". You can also abbreviate or remove unnecessary words: "HuaweiRouterCtrl" or simply "HuaweiRouter". In any case, it must be free of spaces and all non-alphanumeric characters. Upper- and lowercase mix is fine, but all characters should be "low ASCII" (ASCII code < 128) and **no** international characters, Unicode, diacritical marks, etc. So basically, only upper- and lowercase A-Z and digits 0-9.

Once you have a compact form of your plugin name, rename all the plugin files, giving the compact form as a replacement for "PluginBasic" in the names. For example: `D_PluginBasic1.xml` becomes `D_HuaweiRouter1.xml`. The other files would become `D_HuaweiRouter1.json`, `I_HuaweiRouter1.xml`, `L_HuaWeiRouter1.lua`, and `S_HuaweiRouter1.xml`.

Notice that the example preserves the prefix (`D_`, `I_`, etc.), the "1" that precedes the suffix, and the suffix itself. It's very important that you keep that straight.

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
   * UPnP Implementation Filename: `I_xxxx1.xml` (use the filename you assigned when renaming the files)  
   **Check, check and double-check these filenames for correctness.** If you blow it, you could put your Vera in an endless reload Luup!
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

Take a look at the code in the Lua implementation module (`L_.xml`) and see if you can correlate the messages to their various sources.

## Plugin Structure

Now let's step back from the code for a bit and get back to some important background information: what is the structure of a plugin, and how does it hang together?

### Core Plugin/Device Definition Files

A plugin is a set of files that describe a device type and provide an implementation. The following are the files you will normally see defined, at a minimum, for any plugin:
* D_*pluginname*1.xml - This is called the *device file*, and it defines the device type associated with the plugin, and what service the device/plugin supports, among other details. It is really the "root" of the information tree for the device/plugin. It all starts with the device file.
* I_*pluginname*1.xml - This is called the *implementation file*, and it contains the startup code for the plugin, the code for all actions the plugin implements, and sometimes (not necessarily) the core code of the plugin implementation. Note that this is an XML file, but it contains code fragments. More on this later.
* S_*pluginname*1.xml - This is called the *service file*. Most plugins will define their own service(s), so is usually at least one service file (for the plugin device itself), and can be multiple if the plugin introduces a number of new services. Service files describe the state variables that belong to the service, and the actions that the service is defined to support.

So, starting from our "root"--the device file--let's take a look at the pieces. Here's the device file for PluginBasic. It defines the device type that all devices belonging to this plugin will use, and some other parameters.

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

When creating a plugin, you will need to create/modify a device file. The Plugin Framework gives you a template device file--you've already modified it if you've gone through the quick-start steps above.

The implementation file (`I_PluginBasic1.xml`) contains the implementation code of the plugin. It's an XML file, which unfortunately can make coding really difficult--most syntax highlighting editors will understand that the file is XML and highlight it using XML rules, but will not understand that the text inside the XML tags is code and highlight the interior text with code rules. There are also special characters that you can't use directly in XML (like \<, \>, \&) and need to be escaped, which is hard to remember, makes the code look terrible, and inhibits efforts to simply copy-paste code from outside.

The implementation file contains three important tags/sections: `startup`, `functions`, and `actionList`. The `startup` tag defines the name of the function that is called to start the plugin/device. The `functions` tag contains the code that defines that function and provides any other functions necessary. The `actionList` defines the implementation code for every action the device/plugin must perform.

Using the Plugin Framework, you will only have minimal need to modify the implementation file. Typically, you will only need to modify the `actionList` section, to add new actions to your plugin. You will not normally need to modify the `startup` and `functions` sections, and doing so may disrupt the operation of the framework. 

**WARNING: Do not modify any code/text in the `startup` or `functions` sections of the implementation file unless you really know what you are doing.**

The framework provides its own mechanism for you to have startup code and supporting implementation code outside of the implementation file, in a Lua (`L_.lua`) file where the problems of editing code inside XML will not be an issue for you. 

As part of setting up your plugin using the framework, you will create a *Lua module* containing your plugin's startup and implementation code. Your Lua module must contain a `start( startupDevice )` function and a few others, described below, as well as all other functions/code you need to define to complete your plugin.

### How Actions Work

When an action is invoked (for example, by the UI or `luup.call_action()` call), Luup will do the following:
1. Using the service ID, it will look to see if the action is defined in the declarations loaded from the related service file (`S_.xml`);
2. If the action is defined for the service, it will look in the device's implementation file (`I_.xml`) for an `action` tag in the `actionList` section that contains matching `serviceId` and `name` tags. 
3. If it finds a matching `action` in the implementation file, it runs the Lua fragments in its `run` and/or `job` tags.

At this point, you should know that the service file (`S_.xml`) defines the state variables and actions that the plugin itself defines and maintains. It would therefore be expected (by Luup) that the actions named in the service file have a corresponding implementation in the `actionList` of the implementation file (`I_.xml`). So hopefully you are now getting an idea of how interconnected these files are, and if you're a little confused, you are rightly so. It's just part of the learning curve, but don't worry, you'll get there.

### Other Plugin Files

There are a couple of other files in the PluginBasic package: `D_PluginBasic1.json` and `L_PluginBasic1.lua`. We'll cover these soon enough. For now, just know that the `D_.json` file contains the UI configuration to display the device's dashboard card and control panel interfaces, and the `L_.lua` file is a Lua module that contains the bulk of the plugin's implementation (this is where you will be doing the bulk of your work).

### Where Stuff Goes

The files of plugins that you install from the Vera App/Plugin Marketplace, AltAppStore, or upload directly using the Luup uploader (in UI7 at *Apps > Develop apps > Luup files) will all be found in `/etc/cmh-ludl/`. If you are using `scp` to transfer plugin files to your Vera, be sure they land in this directory **only**.

Vera's own device and service files live in `/etc/cmh-lu`. **This directory and the files in it are off-limits to you for modification!** But, you will need to read and study some of the files in that directory from time to time.

## Creating Your Plugin

In order to make the plugin do the work you want it to do, you will need to modify a few core functions in the Lua implementation module (`L_.lua`). This file is where all of your implementation code will go (except the "stubs" needed for any new actions you create--more on that later):

### `start( dev )`

You will always need to modify this function. It is called to initialize and start your plugin, so you need to modify it to contain whatever needs to be done to get the work started. All of your startup code should go in here. **Do not modify the `startup` or `functions` sections of `I_PluginBasic1.xml`.**

Your `start` function should return two values: a boolean (`true` or `false`) success code, and a message (or `nil`). If the first value returned is anything other than `false`, the framework assumes that your plugin code has started successfully and will clear the device error state and return a success indication to Luup. If the value is `false`, or if an error is thrown by your code, the device will enter error state and the message provided returned to Luup to be displayed as a device error.

```
-- All is well
return true

-- No, startup didn't go well at all
return false, "The auth information has not been set"
```

Your startup code must initialize all plugin-specific data. You can declare any module-global data you need at the top of the Lua file in the area indicated for this purpose. You may also load (using `require`) any other packages your code needs. The code will also need to place any watches on device state variables, or kick off any timer-based tasks, that it needs as part of its operation.

### `runOnce( dev )`

The `runOnce()` function is called the first time your plugin code runs in a new device. Use this for any one-time initializations you may need to perform. It will not be called again, unless the `Configured` state variable is set to anything other than "1" (digit one). The framework manages this state variable and decides whether or not `runOnce()` needs to be called, so do not call it directly from your own startup code, and do not manipulate `Configured` in any way.

### `checkVersion( dev )`

The `checkVersion()` function is expected to return a boolean (true/false) indicating that the current running Vera/Luup firmware is compatible with the plugin. If `false` is returned, the startup of the plugin will be aborted. If anything other than `false` is return, the plugin will be started.

## Getting To Work

Once your startup code returns, your plugin is sitting waiting for something to happen. You need to add code to react to things that your plugin needs to act on. These may include:
1. Time-based tasks, done by handling the expiration of interval timers;
2. Device-based events, done by handling changes in the state of devices you are monitoring;
3. Handling an HTTP request made to the Vera with the plugin identified as the target to answer the request;
3. Actions on the plugin device(s), for example, a request from the user/UI to perform some task the plugin is capable of performing.

If you don't do any of the above, your plugin basically runs at startup and does nothing else, so it's very rare that a plugin won't need to have code to handle at least one of the above conditions.

Note that with the exception of the time-based tasks, these events are all asynchronous--you have no idea when they are coming, you just handle them when they come up.

### Using State Variables in Your Plugin

State variables store data in a persistent fashion. The value of state variables is stored in a Luup structure called `user_data`, and this is periodically written to non-volatile storage.

You can create your own state variables as needed by your plugin.

1. When creating a new state variable, be sure to initialize it in your `runOnce()` or `start()` code.
1. Declare state variables that should be "public" (e.g. contain data that may be useful outside of the plugin) in your plugin's service file (`S_.xml`).
1. **DO NOT** create new state variables using other services--only create new variables in services you create and own as well, no matter what device you create it on. For example, it would be incorrect for your plugin to store some special data about a switch that it supervises in a new `MyData` variable in the `urn:upnp-org:serviceId:SwitchPower1` service--that is not a standard variable defined by the SwitchPower1 service. You can go ahead and use the `MyData` variable name, but use a service Id that's defined by your plugin instead.
   > It is *perfectly fine* for you to create a state variable using your own service ID on any device, even if that device is not part of your plugin or created by it. For example, if you write a plugin that controls lights in groups, you can write a state variable with your group number on every light in that group, even though those lights are Z-Wave (or other) devices not directly under your control. The key is to *not* use the device's service ID or any other service ID you don't own--that's hijacking.

### Defining New Service Actions

The service file (`S_.xml`) defines the actions of the related service. Since your plugin has its own service, that's the file in which you can declare your plugin-specific actions. By default, it contains only an example action called `Example`, and a framework action to set the debug/logging level called `SetLogLevel`.

If you want to create a new action in the plugin service, you must add its declaration in the plugin service's service file. The steps are pretty straightforward:
1. Decide on a name for the new action;
1. Declare the new action in the service file;
   * Must include the `name` tag with the action name; 
   * Must include the `argumentList` tag, and enumerate arguments the action takes (it can be empty if there are none);
   * Each `argument` in the `argumentList` must contain `name` and `direction` tags. It is recommended/best-practice to always use `relatedStateVariable` as well. the related variable *must* be declared in the `stateVariables` section of the service file. If there is no related state variable, the A_ARG_TYPE_nnnn variable may be used/added, where nnnn is the UPnP data type (e.g. string, boolean, i4, ui4, i2, ui2, i1, ui1, r4) of the argument.
1. Provide an implementation of the action (next section).

**Do not modify any service file in `/etc/cmh-lu` (the directory where Vera's defined services are kept), or the service file of any plugin you don't own.** For example, you must not create new actions for the `SwitchPower1` service; that's a standard service, and it's untouchable.

### Implementing Service Actions 

Your plugin must provide an implementation for all service actions it is capable of performing in services it declares. This includes all actions defined by the plugin's own service, but also may include other services named in the device file (D_.xml). For example, if your plugin declares that it *supports* the `urn:upnp-org:serviceId:SwitchPower1` service (that is, it can emulate the standard behaviors of a binary switch), it should provide an implementation for `SetTarget` (the most commonly-used action in that service), and any other actions of that service that it can perform.

To implement an action:
1. Make sure the service to which the action belongs is declared in the plugin's device file (D_.xml).
1. Find the service file in which the action is declared, to make sure you have the complete definition of the action. For Vera-defined service, you will find the service files in `/etc/cmh-lu` on your Vera.
1. Declare the implementation in the implementation file's `actionList` section. Add an `action` tag, and inside it, add a `serviceId` tag containing the full service ID of the action, a `name` tag containing the name of the action, and a `run` and/or `job` tag containing an implementation stub that hands control to a handler function you create in the Lua implementation file (`L_.lua`).
1. In the Lua implementation file (`L_.lua`), create a handler function for the action and provide the action implementation within in. By convention, the handler function should be called `actionXXX`, where XXX is the name of the action.

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
				return pluginModule.actionSetTarget( lul_device, lul_settings )
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

## Additional Framework Functions

The framework provides a set of utility functions under the `PFB` global object that you can call from your plugin's Lua module.

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

### State Variable Handling

The framework provides some convenience functions as alternatives to the Luup built-in `luup.variable_get()` and `luup.variable_set()`.

The `PFB.var.get( variableName [, dev [, serviceId]] )` function returns the value of the named state variable on the specified device from the specified service, and the timestamp of the last modification (two values returned). If the service is omitted or `nil`, the plugin's service ID is assumed; if the device is omitted or `nil`, the plugin device is assumed. So, it is possible to retrieve the value of a variable belonging to the plugin device in the plugin service using only one argument, for example `PFB.var.get( "DebugMode" )`. Note that since this function returns two values, extra care must be taken when attempting to wrap this function in other functions like `tonumber()` (the Luup standard function has the same issue). Specifically for the case where `tonumber()` is desirable, use `PFB.var.getNumeric()` below, instead.

The `PFB.var.getNumeric( variableName, defaultValue [, dev [, serviceId]] )` function returns the numeric value of a state variable. If the state variable is undefined, blank, or can't be converted to a number, the value of the `defaultValue` argument will be returned. For example, `PFB.var.getNumeric( 'Status', -1, 45, 'urn:upnp-org:serviceId:SwitchPower1' )` would get the value of the `Status` variable in the SwitchPower1 service from device 45, or if it doesn't exist, returns -1.

The `PFB.var.init( variableName, value [, dev [, serviceId]] )` function initializes the value of a state variable to the value given *if it does not exist*; if it exists, it is not modified. 

The `PFB.var.set( variableName, value [, dev [, serviceId]] )` function sets a state variable to the given value. If the state variable's current value is already equal to the target value, the variable is not changed, preserving the timestamp of the state variable, preventing modification of user_data as a result of the call, and preventing watches from triggering.

### Logging

Developing plugins will require that you write helpful diagnostic data someplace that you can get to it.

The `PFB.debug(msg, ...)` and `PFB.log(msg, ...)` functions both log messages to the LuaUPnP log. The former (`debug`) only writes the message if debug is enabled (the global variable `debugMode` is set `true`).

The message may contain references to additional arguments passed, identified by "%" followed by a number. When these are found in the message string, they are replaced with the text form of the indexed argument from the remaining arguments. They do not need to be used in order of the values passed. For example, `L("this is %1 and %2, or backwards %2 and %1", "alpha", "beta")` will log the string "this is alpha and beta, or backwards beta and alpha". The arguments can be any Lua data type; tables will be expanded into a human-readable pseudocode representation.

> TIP: Keep the non-debug logging of your plugin down to messages that may be useful to your customer: error and warning messages, or confirmations of actions that could be useful. It's pretty annoying to have a plugin that logs every message it sends or receives to a device or remote site by default, when debug is off. It needlessly clutters up the log file for the user and makes it harder for them to diagnose *any* issue they may be having on the system.

## Helpful Tools

jsonlint.com

XML Validator

jshint.com (or installed locally)

luacheck

## Best Practices for Plugin Implementation

TBD MORE -- the DO's and DO NOT's of writing plugin code

* You should not rely on everything in the system being up and running when your plugin starts. Very often, Z-Wave and other device initializations are still taking place. If your plugin relies on the state of Z-Wave or other devices, you should wait until the Z-Wave device indicates that the network is up and running, and/or the devices in question are ready.
* **DO NOT** modify any variable or replace any function in the `luup` global table.
* **DO NOT** create state variables in a service you don't own, unless it's a standard variable of the service.
* **DO NOT** assign any value to a state variable of a standard service other than the values allowed (these are sometimes specified in the service file's declaration of the variable).
* **DO NOT** name a service file the same as any Vera-standard service file in `/etc/cmh-lu`, or that of another plugin--this overrides the intended definition with whatever is in your file, and may cause unpredictable behavior of your Vera or devices. Give your service a different name, and use a different filename. With respect to conflicts with other plugins, this can be a hard rule to follow, and may require coordination with other developers.
* **DO NOT** use `luup.sleep()` if you can avoid it. Use the delay functions (in `PFB.timer` for example) to defer execution of your remaining code. Yes, this is more complicated, but using `luup.sleep()` has been shown to cause deadlocks for long intervals, and may have other side-effects.

## Releasing Your Plugin

**THIS SECTION IS VERY MUCH A WORK IN PROGRESS**

Before releasing your plugin, make sure that you've removed all debug code, and set any debug or testing flags to their off, upright and stowed position.

Do a clean install of your plugin on a system that doesn't already use it. If you don't have one, make a backup of your system, and then remove all plugin devices from your system. Do a reload and check the logs for plugin activity. Once you've confirmed that nothing related to the plugin is running anywhere, check *Apps > My apps* and make sure your plugin is not listed there; if it is, remove it. Finally, remove the plugin files from the system, and reload the system again. Check the log for error messages related to the plugin. This is your final check that you've forgotten to remove something.

### Github

### Vera App Marketplace

Log in at http://apps.mios.com/. This is an old UI5 subsystem, so if you still have your Vera UI5 login information, it's likely this will work here. Otherwise, you'll need to request an account with Vera Support.

Because this is an old "UI5" system, it's pretty long in the tooth, quirky, and has a few "gotchas". I'll flag these throughout.

Vera is apparently replacing this system, but I have no idea when the new marketplace will be released, or how it will work.

#### Creating a New Plugin

If you are updating an existing plugin, skip this section and proceed to "Uploading Your Plugin Files".

To create a new plugin: 

1. Choose "My Plugins" from the "My Account" menu.
1. Click the "Create plugin" link at the bottom of the page.
1. Enter the title and description of your new plugin. The title is the plugin name, as it will appear in the app marketplace.
1. Your "Instructions URL" can just be the URL of your Github repository.
1. Select the best matching category.
1. Make sure "Visibility" is set to "public"
1. Copy-paste the device type, friendly name, and (if applicable) model name from your device file (D_.xml) into the fields. Then enter device and implementation filenames. Double-check for accuracy. 
1. Click "Next". After a brief pause, the site should report "Plugin created" at the top of the page.
1. The site now leaves you on an editing page for some of the plugin details you've already entered, and a few new things, like "Auto update" and "Allow multiple". Set these as appropriate to your application and hit "Update" if you've changed anything.
1. Make a note of your plugin number, which appears both in the URL for the page and in the title bar of the page underneath the page header/navigation menus. 
   > I like to put this number into my Lua module as a local constant `_PLUGIN_ID`. I use it in reports or to help some of my automated scripts on my development systems.
1. Now go on to Uploading Your Plugin Files, below, skipping directly to step 3.

#### Uploading Your Plugin Files

In this section, you are going to add, update, and delete files in a list to make a releasable version. So this is a series of actions (adding, updating, and/or deleting files as much as necessary to get the file list and contents perfected), followed by a final "commit" step that commits the file list and contents as a "Version" that could be released.

1. Go to "My Plugins" in the top navigation
2. Find your plugin and click "Edit" to get to the "Edit plugin" page for your plugin.
3. Click the blue-boxed "Plugin files" link near the top of the page.
4. For each file in your plugin, either add the file if it is new, or update the file if it has been uploaded previously.

*To add a new file to the list:*

1. Scroll to the bottom of the "Plugin files" page and click "Choose file" in the "Add file" section.
2. Locate the file on your local system and select it.
3. Choose the "Role" for the file. Only your device file(s) (D_.xml) should receive the *Device file* role, and your implementation file (I_.xml) the *Implementation file* role. All service files (S_.xml) should receive the *Service file* role. All Lua files should receive the *Lua file* role. All JavaScript files should receive the *JavaScript* file role. Everything else can be *Miscellaneous*. You can correct these later (below) if you make a mistake.
4. Click the "Add file" button next to the role menu to upload the file. It will then appear on the list of plugin files at the top of the page.

*To remove a file from the list:*

1. To remove a file, hit the "Delete" button next to the file.

*To upload a new version of a listed file:*

1. Find the file in the "Plugin files" section.
2. Click the "Upload" button.
3. Locate the file on your local system and select it. **Take care that you choose the right file.** It is very easy to accidentally upload the wrong file because some have similar names, e.g. `D_MyPlugin1.xml` and `D_MyPlugin1.json`, and this will break your plugin and a lot of users if that error sneaks through and gets auto-updated to every user.

*Correcting the role of a listed file:*

If you entered the wrong role for a file, correct it in the "Plugin files" list and hit the "Update Roles" button at the bottom of the list.

*Committing The List*

Once you have uploaded all of your plugin files (new or updates), enter a comment at the bottom of the "Plugin files" section. I usually use something like the date and plugin version number ("2019-07-27 ver 1.4"). It isn't terribly important, apparently.

When ready, hit "Commit all". Then wait until the system comes back and tells you "All files committed." At this point, you have created a set of files as a "version" that is ready to made into a release candidate.

> NOTE: Backing this operation apparently is Subversion or a very similar versioning tool. So there's another layer of change management working behind the scenes in addition to what you may be doing with Github or whatever you use. Don't worry--this doesn't get in your way or change how you need to manage your code.

#### Creating a Release Candidate

You are now ready to create a *release candidate*. A release candidate is set of files that could be released--if they pass final QA (there will be more testing coming).

To make your release candidate:

1. Click the "Versions" link in the top of your plugin's "Edit plugin" page.
1. At the bottom of the page in the "Publish" section, enter the major and minor version number of this release, and any comment you wish to make with it.
1. Click "Publish" to create the release candidate. This will appear listed in the "Versions" section of page. 

#### Testing Your Release Candidate

Before you turn this version out onto the world, it's a good idea to test that it installs properly from the app store. Even though it isn't published, you can easily do this:

1. Go the the "Versions" tab of the "Edit plugin" page for your plugin, if you're not already there from the prior step.
1. Make note of the plugin ID of your plugin by looking at the page URL or the page header below the top navigation.
1. Find the "Versions" section of the "Versions" tab of the "Edit plugin" page, and there you will see a "Show files" button. 
1. Click the "Show Files" button for the version you want to test-install. This will open a page that lists the names of the files in the version. While this doesn't seem that useful, if you look at the URL for this page, you will see the parameter "PK_VERSION" and a number. Make note of this number.
1. On a browser with local access to your Vera, request the URL, replacing the capitalized parts with the matching data: http://YOUR-VERA-IP/port_3480/data_request?id=action&serviceId=urn:micasaverde-com:serviceId:HomeAutomationGateway1&action=CreatePlugin&PluginNum=YOURPLUGINID&Version=YOURPKVERSION 
This will install the plugin on your Vera as if it was a published plugin you had selected from the list in *Apps > Install apps* in the Vera UI.
1. When the install completes, which may take several minutes, hard-refresh your browser and test your plugin (again).

  > NOTE: There is an "Install" button in the "Versions" list, but this is tied to old UI5 behavior; it doesn't work for UI7 systems.

If your plugin appears to have installed correctly, proceed to "Requesting Approval" below.

If there was a problem with the installation of your plugin, such as a missing file or wrong version or contents for a file, go back to "Uploading Your Plugin Files" above and fix the broken file(s). You don't need to upload all of the files again, just the ones that were missing or mixed up. Continue through all other steps as documented (see NOTE below).

If you found a bug and had to correct code or XML/JSON data in your plugin files, no problem, make those fixes, and then head back to "Uploading Your Plugin Files" above and update the repaired files. Continue through all other steps that follow as documented (see NOTE below).

> NOTE: In both cases, when you come through to creating a release candidate again, you can use the same version number when you go to "Publish". Since many candidates can have the same major/minor numbers, I like to add a note in the comments so I can differentiate between the different release candidates: "RC1", "RC2", etc.

#### Requesting Approval

Once you have a stable release candidate (Version) that installs correctly and passes your final QA, you are ready to request approval from Vera to publish the release.

1. Go the "Versions" link in the plugin's "Edit plugin" page.
1. In the "Add release" section, enter "Platform" as "any" for now, and leave the compatible firmware fields blank. 
1. Set the "Dev", "Alpha", "Beta", and "RC" fields to the version/candidate you just tested.
1. Click "Add release". This will make a new entry in the "Releases" section.
1. Click the "Request approval" button in the "Releases" entry for your candidate.

Vera's current schedule for approving plugins (as of this writing) is *weekly*, on Monday mornings Romanian time (so overnight between Sunday and Monday in most of the US). Sometimes, particularly around holidays (both theirs and hours), they'll miss an approval cycle. I've found that you can email Vera Support or ping Sorin in the Community Forums and this usually gets someone to approve them pretty quickly.

> NOTE: I've only had a plugin approval denied once, and that really was just a question about some code that I left in to transmit trace data to my server to assist debugging. Although I knew the code was not a risk and probably could have argued for its approval as-is, I voluntarily removed that code and they approved it right away. I actually felt good knowing that they are watching and not just anything gets through. That said, do not count on them to flag things that may be functionally plainly incorrect; that's not really what they're looking for.

#### Editing Plugin Data

If you find you have an error in your plugin's metadata or just need to update/freshen your plugin description or icon:

1. Go to "My Plugins"
1. Click "Edit" on your plugin
1. Use the blue-boxed links at the top of the "Edit Plugin": "Plugin Info" and "UPNP"

### AltAppStore

## Reference
* `PFB.VERSION`  
   The current version of the Plugin Framework Basic
* `PFB.device`  
  The device number of the plugin instance currently running

* `PFB.log( level, message [, ... ] )`  
  Log a message to the log stream. The `level` argument can be selected from `PFB.LOGLEVEL`. The message is not logged if the `level` is less critical than the current value of `PFB.loglevel`. PFB log levels are *not* the same as Vera/Luup log levels. The `message` argument may contain position parameters, identified by a "%" character followed by a number; the corresponding extra argument (from among the ...) is inserted at that position in the output message. Note that all messages are logged to Luup's LuaUPnP.log (using `luup.log()`) at Vera/Luup level 50 except `warn` and `err` levels (see below), which are logged at Vera log levels 2 and 1 respectively; all of which by default are enabled in `/etc/cmh/cmh.conf`.
* `PFB.LOGLEVEL`  
  A table of constants for the various log levels. Includes (upper- and lowercase): ERR, WARN, NOTICE, INFO, DEBUG1, DEBUG2. These are used to pass to `PFB.log()` or set `PFB.loglevel`. The DEFAULT key is the default logging level for the framework (currently == INFO). These log levels are specific to the framework; they are *not* Vera log levels.
* `PFB.loglevel`  
  The current logging level. Messages less critical than this level will not be output to the log stream. The value is specific to the framework and related to `PFB.LOGLEVEL` above. This variable does *not* use the Vera/Luup log levels.
  
* `PFB.var.getVar( variableName [, device [, serviceId ] ] )`  
  Returns (two values) the current value and timestamp of the named state variable. May be called with 1-3 arguments; if `device` is omitted or `nil`, the plugin device is assumed. if `serviceId` is omitted or `nil`, the plugin's service is assumed.
* `PFB.var.getVarNumeric( variableName, defaultValue [, device [, serviceId ] ] )`  
  Returns the numeric value of the named state variable. If the state variable is not defined, or its value blank or non-numeric, the value of `defaultValue` is returned. The `device` and `serviceId` parameters are optional and default as they do in `getVar()`.
* `PFB.var.setVar( variableName, value [, device [, serviceId ] ] )`  
  Sets the value of the named state variable to the value given, and returns the prior value. The `device` and `serviceId` parameters are optional and default as they do in `getVar()`.
* `PFB.var.initVar( variableName, defaultValue [, device [, serviceId ] ] )`
  Like setVar, but does *not* set the state variable if it already exists. Used for one-time initialization, primarily.
  
* `PFB.timer.once( seconds, func [, ... ] )`  
  Run a one-time timer for the specified number of seconds; upon its expiration, call the *function reference* (not a string) provided in `func` with any remaining arguments passed through. Returns a timer ID, which may be used to cancel the timer before its expiration by calling `PFB.timer.cancel()`.
* `PFB.timer.interval( seconds, func [, ... ] )`  
  Like `PFB.timer.once()` in every respect, except that the timer recurs on the interval provided automatically until cancelled.
* `PFB.timer.cancel( timerID )`  
  Cancel the timer identified by `timerID`.
  
* `PFB.watch.set( device, serviceId, variableName, func [ , ... ] )`  
  Places a watch on the named state variable on the device. When it changes, the function (a *function reference*, not a string) will be called with the extra arguments passed through. If the `variableName` is `nil`, changes to any variable in the service on the device will trigger a call to the function/handler.
* `PFB.watch.cancel( device, serviceId, variableName [, func ] )  
  Cancel a watch on a device state variable. If `func` is specified, only the watch that calls the function (passed by reference) is cancelled; otherwise, all watches for the device/state are cancelled.

* `PFB.isOpenLuup()`  
  Returns `true` if running under openLuup, `false` otherwise.
