# Change Log

## 20022

* BREAKING CHANGE: The majority of the framework implementation has been moved to a Lua file called `L_PFB_xxx.lua`, where *xxx* is the compact name of your plugin. It is provided as `L_PFB_PluginBasic1.lua`, and must be renamed. This keeps each plugin's copy of the framework separate, in case they rely on different version. Having the majority of the implementation in this Lua file further isolates the code--you should not be making *any* changes in this file at all--and makes debugging and development easier (working in Lua code embedded in the XML implementation file is problematic).
* BREAKING CHANGE: Timer callbacks now receive the timer task ID as their first argument.
* The `PFB.watch.set()` function now accepts `nil` for the variable name; the watches will match all variables in the named service. It also supports `nil` for *both* variable and service, which triggers watch callbacks for any variable modified on a device.
* The new `PFB.request.register()` function adds the ability to create a specific request handler for a matched parameter. For example, `PFB.request.register( "action", "test", runTestAction )` will dispatch any request to the plugin where the "action" parameter contains the value "test" to the `runTestAction()` function (which the user must define).
* The `PFB.isOpenLuup()` function is now deprecated.
* The `PFB.platform.isOpenLuup()` is now available as a replacement for the now-deprecated `PFB.isOpenLuup()` function.
* The `PFB.platform.getInstallPath()` will return the directory path (always with a trailing "/") in which the plugin is installed. For Vera systems, this is usually "/etc/cmh-ludl/"; it varies for openLuup.
* Documentation fixes in support of all of the above.
* Documentation fix, credit to @Vpow: Lua files should be given the "Miscellaneous file" role in the App Marketplace. If given "Lua file" role, they are run at startup right after startup and scene Lua are loaded.