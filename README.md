# FS22 Field State Changer

Change the state of a field (plowed, cultivated, limed, fertilized, ...) instantly with a simple shortcut in Farming Simulator 22.

## Installation

1. Download this repository as a ZIP (green **Code** button → **Download ZIP**), or download the release ZIP if there is one.
2. Make sure the ZIP contains `modDesc.xml`, `icon_fieldStateChanger.dds` and the `scripts` folder **directly at the top level**, not inside an extra subfolder. If GitHub added an extra folder, unzip it and zip those files again.
3. Rename the ZIP to `FS22_FieldStateChanger.zip`.
4. Put the ZIP in your FS22 mods folder:
   `Documents\My Games\FarmingSimulator2022\mods`
5. Start the game, open (or create) a savegame and enable **Field State Changer** in the mod selection.

## Changing a field with the shortcut

1. Load your savegame as the **host** (or in single player). The mod only changes fields for the host.
2. Get out of your vehicle. The shortcut only works **on foot**.
3. Walk onto a field that **your farm owns**.
4. Press **Left ALT + F**.
5. A menu opens with the field number. Choose the new state:

   | Option | What it does |
   |---|---|
   | Plowed | Plows the whole field |
   | Cultivated | Cultivates the whole field |
   | Stubble tillage | Disc harrow / stubble tillage |
   | Rolled | Rolls the field |
   | Mulched (stubble shredded) | Shreds the stubble |
   | Limed | Applies lime |
   | Fertilized (max) | Fertilizes to the maximum level |
   | Remove weeds | Removes all weeds |
   | Ready to sow | Plow + lime + fertilize + cultivate + remove weeds in one go |

6. Confirm. A notification in the top of the screen tells you the field was changed.

> You can change the shortcut in **Settings → Controls**. Look for **Change field state**.

## Using the console (optional)

With the console you can also change fields you are not standing on, or many fields at once.

1. Enable the developer console. Close the game and open
   `Documents\My Games\FarmingSimulator2022\game.xml`, then set:
   ```xml
   <development>
       <controls>true</controls>
   </development>
   ```
2. Start the game and load your savegame.
3. Press the **~** key (tilde, next to the 1) twice to open the console in command mode.
4. Type `fscStates` and press Enter to see all states.
5. Use `fscSetField <field> <state>`, for example:

   | Command | Result |
   |---|---|
   | `fscSetField 12 plowed` | Plows field 12 |
   | `fscSetField here cultivated` | Cultivates the field you are standing on |
   | `fscSetField owned ready` | Makes all your own fields ready to sow |
   | `fscSetField all limed` | Limes **every** field on the map, including fields you don't own |

   State names: `plowed`, `cultivated`, `stubbletillage`, `rolled`, `mulched`, `limed`, `fertilized`, `noweeds`, `ready`.

## Good to know

- The shortcut only works on fields you own. The console has no such check, so be careful with `all`.
- In multiplayer, only the host can change fields.
- If something doesn't work, look for lines that start with `[FieldStateChanger]` in
  `Documents\My Games\FarmingSimulator2022\log.txt`.
