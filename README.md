
# Open Fortress Plugins

A collection of SourceMod plugins i made for Open Fortress dedicated servers (https://openfortress.fun)

## WeaponTag (1.41)
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

## Map Dependent Frag Limit (1.0)
Lets you assign a frag limit to a map
| ConVar                         | Description                                           | Default Value                       | Acceptable Values     | Notes |
|--------------------------------|-------------------------------------------------------|-------------------------------------|-----------------------|-------|
| of_mapfraglimit_enabled        | Enable map dependent frag limit                       | 0                                   | 0 or 1                |       |
| of_mapfraglimit_announce       | Announce the frag limit for the map in chat           | 1                                   | 0 or 1                |       |
| of_mapfraglimit_announce_delay | How many seconds to wait before announcing the change | 30                                  | Any reasonable number |       |
| of_mapfraglimit_file           | The 2nd config file path                              | cfg/sourcemod/mapfraglimit-maps.cfg | Any file path         |       |

The 2nd config file must have the map names and their respective frag limits
2nd config file example:
```
dm_skate 10
dm_gump 20
dm_doomspire_alt2 15
dm_crossfire 25
```

```
of_mapfraglimit_reload "Reload the 2nd config for this plugin" (Admin command)
```

## RocketSpeed (1.1)
Modify the rocket projectile speed
| ConVar         | Description                        | Default Value | Acceptable Values | Notes                               |
|----------------|------------------------------------|---------------|-------------------|-------------------------------------|
| of_rocketspeed | Rocket projectile speed multiplier | 1             | 0-3               | Values higher than 3 cause problems |
Associated server tag: "rocketspeed"

## Entity Classname Logger (1.0)
Prints out a list of all current entities
```
sm_printentities "Print out all entity classnames to the server console"
```

## Installation
1. Compile the plugins using a SourcePawn compiler (there should be one or more in /addons/sourcemod/scripting) ***OR*** Download the compiled plugins from one of the releases (doesn't need to be the latest one, it's just that they have more features & bugfixes)
2. Put them in your server plugins folder (/addons/sourcemod/plugins)
3. Download translations if needed (put in /addons/sourcemod/translations)
4. Verify that they're loaded on the server using "sm plugins list"
