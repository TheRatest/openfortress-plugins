
# Open Fortress Plugins

A collection of SourceMod plugins i made for Open Fortress dedicated servers (https://openfortress.fun)

## Killstreaks (1.3)
Keep track of players' killstreaks and announce the highest killstreak each round

| ConVar                                  | Description                                                                    | Default Value | Acceptable Values     | Notes                                 |
|-----------------------------------------|--------------------------------------------------------------------------------|---------------|-----------------------|---------------------------------------|
| of_killstreaks_enabled                  | Enable this plugin                                                             | 1             | 0 or 1                |                                       |
| of_killstreaks_server                   | Count the server's kills                                                       | 0             | 0 or 1                |                                       |
| of_killstreaks_announce_progress_amount | The amount of frags required to announce a killstreak                          | 5             | Any reasonable number | Announces each N frags, not just once |
| of_killstreaks_announce_progress        | Announce killstreaks every N frags                                             | 1             | 0 or 1                |                                       |
| of_killstreaks_announce_interrupt       | Announce killstreaks getting interrupted (when someone with a killstreak dies) | 1             | 0 or 1                |                                       |
| of_killstreaks_announce_end             | Announce the highest killstreaker at the end of the round                      | 1             | 0 or 1                |                                       |
| of_killstreaks_announce_console         | Announce killstreaks to the server console                                     | 1             | 0 or 1                |                                       |

#### Server commands:
```
of_killstreaks_reset "Set everyone's killstreak back to 0" (Admin command)
```

Associated server tag: "killstreaks"

## Map Dependent Frag Limit (1.3)
Lets you assign a frag limit to a map
#### You can use this plugin in conjunction with [Dynamic Frags](https://github.com/Tholp1/Dynamic-Frags), but if you do, make sure you aren't setting *sm_dynamicfrags_basefrags* in your config files!
| ConVar                         | Description                                           | Default Value                       | Acceptable Values     | Notes |
|--------------------------------|-------------------------------------------------------|-------------------------------------|-----------------------|-------|
| of_mapfraglimit_enabled        | Enable map dependent frag limit                       | 0                                   | 0 or 1                |       |
| of_mapfraglimit_announce       | Announce the frag limit for the map in chat           | 1                                   | 0 or 1                |       |
| of_mapfraglimit_file           | The 2nd config file path                              | cfg/sourcemod/mapfraglimit-maps.cfg | Any file path         |       |

The 2nd config file must have the map names and their respective frag limits
2nd config file example:
```
dm_skate 10
dm_gump 20
dm_doomspire_alt2 15
dm_crossfire 25
```
#### Server commands:
```
of_mapfraglimit_reload "Reload the 2nd config for this plugin" (Admin command)
```

Associated server tag: "mapfraglimit"

## Don't make the jumppads slow me down! (1.0)
Modifies all of the jumppads to add to the player's velocity instead of resetting it

| ConVar              | Description                                                                          | Default Value | Acceptable Values | Notes |
|---------------------|--------------------------------------------------------------------------------------|---------------|-------------------|-------|
| of_jumppad_only_add | Modifies all of the jumppads to add to the player's velocity instead of resetting it | 1             | 0 or 1            |       |

Associated server tag: none

## WeaponTag (1.51)
Fun (hopefully) gamemode that forces people to use the weapon you kill them with.
(e.g. if someone kills you with a rocket launcher you'll be forced to use only the rocket launcher until you frag someone)
#### If you're tagged you won't have a weapon pullout animation on spawn
#### You can drop the forced weapon if the server allows it, which is silly... so don't allow dropping weps on your server ig
| ConVar                            | Description                                                                                                    | Default Value | Acceptable Values | Notes                               |
|-----------------------------------|----------------------------------------------------------------------------------------------------------------|---------------|-------------------|-------------------------------------|
| of_weapontag_enabled              | Enable the gamemode that forces people to use the weapon you kill them with                                    | 0             | 0 or 1            |                                     |
| of_weapontag_frags                | Amount of frags required to untag someone after they've been tagged                                            | 1             | 1-50              |                                     |
| of_weapontag_can_tag_while_tagged | Whether can tagged players tag others                                                                          | 0             | 0 or 1            | To prevent infinite weapon loops    |
| of_weapontag_refresh_weapon       | If someone that's already tagged dies again, their forced weapon gets updated to the one they were killed with | 1             | 0 or 1            |                                     |
| of_weapontag_stripweapons         | Remove other weapons on spawn if tagged                                                                        | 1             | 0 or 1            |                                     |
| of_weapontag_tint_weapon          | Change the tagged player's weapon color to red                                                                 | 1             | 0 or 1            |                                     |
| of_weapontag_distort              | Change a tagged player's render fx to look a bit like a hologram                                               | 1             | 0 or 1            | Isn't really that visible...        |
| of_weapontag_servertag            | Apply a 'weapontag' tag to the server                                                                          | 1             | 0 or 1            | Do people even look at server tags? |
| of_weapontag_debug                | An extra option to clutter up the server console (print useless stuff)                                         | 0             | 0 or 1            |                                     |

Associated server tag: "weapontag"

## StripWeapons (1.2)
Removes all weapons (or only the pistol) from a player when they spawn
| ConVar          | Description                                      | Default Value | Acceptable Values | Notes           |
|-----------------|--------------------------------------------------|---------------|-------------------|-----------------|
| of_stripweapons | Remove all weapons from a player when they spawn | 0             | 0 or 1            | Causes t-posing |
| of_strippistol  | Remove the pistol from a player when they spawn  | 0             | 0 or 1            |                 |

Associated server tag: "stripweapons"

## RocketSpeed (1.2)
Modify the rocket projectile speed
| ConVar         | Description                        | Default Value | Acceptable Values | Notes                               |
|----------------|------------------------------------|---------------|-------------------|-------------------------------------|
| of_rocketspeed | Rocket projectile speed multiplier | 1             | 0-3               | Values higher than 3 cause problems |

Associated server tag: "rocketspeed"

## Entity Classname Logger (1.0)
Prints out a list of all current entities
#### Server commands:
```
sm_printentities "Print out all entity classnames to the server console"
```

## Installation
1. Compile the plugins using a SourcePawn compiler (there should be one or more in /addons/sourcemod/scripting) ***OR*** Download the compiled plugins from one of the releases (doesn't need to be the latest one, it's just that they have more features & bugfixes)
2. (If you're compling) If you don't already have morecolors.inc, add it to your /addons/sourcemod/scripting/include from [here](https://github.com/DoctorMcKay/sourcemod-plugins/blob/master/scripting/include/morecolors.inc)
3. Put the compiled plugins in your server plugins folder (/addons/sourcemod/plugins)
4. Download the translations file (put in /addons/sourcemod/translations)
5. Verify that they're loaded on the server using "sm plugins list"

   #### If you have any issues or suggestions, feel free to message me on Discord (@ratest) or make an issue on this repo
