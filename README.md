QtCooldown
==========

## Who?

Created by Ninix. Maintained by Lemtzas.

## What's this?
QtCooldown is an attempt to bring many features of the popular SexyCooldown and CoolLine addons for World of Warcraft into WildStar.  QtCooldown allows you to create up to six timelines on which you can display any of your currently active cooldowns as well as buffs or debuffs on yourself, your target, or your focus target.  By default, QtCooldown's timelines use a logarithmic scale, which means that timers which are expiring soon will move more quickly and are more spaced out than those with a long time remaining.  This allows you to quickly determine which abilities/auras will be ready soon even if there are many icons displayed on the bar.

QtCooldown includes many configuration options to allow you to customize it to your liking.  To display the configuration UI, use the **/qtc** or **/qtcooldown** slash command.  You may display up to six different bars on the screen at a time, and each bar has its own separate configuration for size, color, opacity, as well as which items are tracked or ignored.

You can create multiple configuration profiles on a single character, and then swap between these profiles using a macro with the **/qtc swapprofile** command.  This allows you to easily keep two sets of bars for each LAS, if you so desire.

## Features
* Track your own cooldowns, as well as buffs and debuffs on yourself, your target, your focus target, and any combination thereof
* Create up to six bars at a time, each with their own appearance and filtering.  You can keep one bar for just your cooldowns, one bar for keeping track of raid debuffs on yourself, and another bar for keeping track of DoTs on your current target.
* Create profiles to easily swap between bar configurations, allowing you to have one setup for each LAS, or one shared setup across all your characters
* Know immediately when an ability comes off cooldown with a configurable pulse animation that can be placed anywhere on the screen

## Known Issues and Limitations
* The API does not provide any way to see who applied a debuff to a target, so QtCooldown cannot display only your debuffs on your target.
* Likewise, the API does not provide any way to differentiate multiple instances of the same debuff on a target.  As a result, if you have multiple Spellslingers using Ignite on a target, only one of those Ignite icons will appear on your debuff bar.  I will attempt to implement a workaround for this in the next update.  Note that this **does not** interfere with Surged and un-Surged Ignite tracking, since those are technically considered two different spells by the API.

## Planned Additions
* Tracking of CC effects, separately from debuffs
* Internal cooldown tracking for AMP procs
* An API to allow other addons to add custom timers, for things like boss alerts
* Multiple bar textures
* ColorPicker support for bar/icon colors

###Update 2.0 Notice
Unfortunately settings from older versions of QtCooldown will not be carried over when installing v2.0, due to a completely rewritten and restructured settings/profiles system.  This is a one-time deal that shouldn't ever happen again.  Sorry for the convenience.

----

Changelog
=========

## v2.0

This is a major update involving a rewrite of most of the addon.  Because the config system has been completely rewritten, settings from previous versions of QtCooldown will not carry over, sorry!

* Added a brand new configuration UI.  You still access this UI via the /qtc command.
* Added support for up to six bars on-screen at a time.  Each of these bars has their own independent configuration.
* Added support for buff and debuff tracking.  You can track buffs and/or debuffs for yourself, your target, or your focus target and any combination thereof on any bar.
* Added a profiles system.  You can share bar setups between characters, or have multiple setups on a single character (one for tanking and one for DPS, for example).
* Added a /qtc swapprofile command.  This allows you to swap the currently active profile from inside of a macro.
* Added more appearance options.  You can now change the bar color, the background opacity, disable the icon border, set the time label opacity, and apply color tints to differentiate cooldown and buff/debuff icons.
* Added maximum duration settings for each type of tracked item (cooldowns, buffs, debuffs).  Items with timers longer than the maximum duration will not be displayed on the bar.
* Added pulse animation settings.  You can now change the size of the pulse, the duration on the animation, and you can move the pulse anywhere on the screen.
* Added blacklist and whitelist options.  You can set an independent blacklist/whitelist for each bar and each type of tracked item (cooldowns, buffs, debuffs).
* Removed the UI redraw and tracker timer options.  The addon now updates tracked items every half-second, and redraws the UI every 0.02 seconds.
* Improved pulse animation.  The animation now grows from the middle instead of the top-left corner.  It also runs independently of QtCooldown's own UI code so it should animate more smoothly.
* Improved performance while bars are empty
* Improved handling of situations where cooldowns are reset (Warrior innate, Stalker innate when leaving combat) or shortened (Trigger Fingers)
* Improved performance/reduced stutter when changing limited action sets
* Fixed a number of small bugs/hiccups (but probably introduced just as many since this is a huge update)
* Thanks to Nisus of <Fuccboi Extraordinaire> for helping me test some warrior stuff!
