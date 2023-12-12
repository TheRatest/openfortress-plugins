
# Open Fortress Plugins

A collection of SourceMod plugins i made for Open Fortress dedicated servers (https://openfortress.fun)
## StripWeapons (1.2)
Removes all weapons (or only the pistol) from a player when they spawn
#### Removing all weapons will cause a player to have a model without animations (will cause t-posing)
```
of_stripweapons (def. 0) "Remove all weapons from a player when they spawn"
of_strippistol (def. 0) "Remove the pistol from a player when they spawn"
```
Associated server tag: "stripweapons"

## RocketSpeed (1.1)
Modify the rocket projectile speed
#### Settings the rocket speed to a value higher than 3 will cause issues!! (the rocket won't go in the right direction)
```
of_rocketspeed (def. 1) "Rocket projectile speed multiplier"
```
Associated server tag: "rocketspeed"

## WeaponTag (1.2)
Fun (hopefully) gamemode that forces people to use the weapon you kill them with.
(e.g. if someone kills you with a rocket launcher you'll be forced to use only the rocket launcher until you frag someone)
```
of_weapontag_enabled (def. 0) "Enable the gamemode that forces people to use the weapon you kill them with"
of_weapontag_frags (def. 1) "Amount of frags required to untag someone after they've been tagged"
of_weapontag_can_tag_while_tagged (def. 0) "Amount of frags required to untag someone after they've been tagged"
of_weapontag_debug (def. 0) "An extra option to clutter up the server console (print useless stuff)"
```
Associated server tag: "weapontag"

## Installation
1. Compile the plugins using a SourcePawn compiler (there should be one or more in /addons/sourcemod/scripting)
  OR
1. Download the compiled plugins from releases
3. Put them in your server plugins folder (/addons/sourcemod/plugins)
4. Verify that they're loaded on the server using "sm plugins list"
