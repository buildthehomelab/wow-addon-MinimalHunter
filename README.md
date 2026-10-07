# MinimalHunter

A clean, minimal UI for World of Warcraft 3.3.5a (WotLK), built around playing a hunter. Flat dark panels, 1px borders, Arial Narrow, no art. No libraries, no config window.

## Requirements

- A WoW 3.3.5a (12340) client. The addon runs entirely in the client, so it works on [AzerothCore](https://www.azerothcore.org) or any other 3.3.5a server.
- DragonUI turned off for the character (see Installation). The two addons take over the same frames.

## Installation

Copy the `MinimalHunter` folder into your `Interface/AddOns` folder (`World of Warcraft/Interface/AddOns/`), then enable it on the character select screen.

**Turn DragonUI off for this character.** Both addons take over the same bars and frames, so MinimalHunter stays inactive (and tells you why in chat) while DragonUI is enabled.

On the first login it turns on all four extra action bars in Interface Options if any were off. If a row is missing, `/reload` once.

## What you get

| Area | What it does |
| --- | --- |
| Action bars | Three rows of 12 centered at the bottom (main bar, bottom-left, bottom-right). The right and left side bars sit on the right edge and fade in on mouseover. Icons turn red when out of range, blue when out of mana and grey when unusable. Keybind labels are shortened (`S1`, `C3`, `M4`). |
| Pet bar | 10 small buttons above the action bars. They show only when you have a pet. |
| Unit frames | Player, target, target of target, focus and pet. Health is class-colored for players and reaction-colored for NPCs. Target shows level, elite/rare marker, raid icon and health %. The player frame border turns red in combat. |
| Target auras | Your own debuffs (Hunter's Mark, stings, Black Arrow…) with timers above the target. Enemy Magic and Enrage buffs that **Tranquilizing Shot** can remove appear top-right with a blue border. |
| Cast bars | Player cast bar with a latency zone. Target cast bar under the target frame, grey when the cast can't be interrupted. |
| Auto Shot timer | A thin bar under the cast bar that fills between Auto Shots. It turns grey when the next shot is ready. |
| Aspect watch | An icon left of the player frame shows your active aspect. Its border pulses red with no aspect in combat, or with Cheetah/Pack in combat (daze risk). It pulses yellow when you're in Viper with 90%+ mana. |
| Ammo | An icon with your ammo count. The number goes yellow under 400 and red (with a pulse) under 100. It hides with a thrown weapon equipped. |
| Pet happiness | A small dot beside the pet frame: green happy, yellow content, red unhappy. |
| Minimap | Square with a thin border. Mouse wheel zooms, right-click opens tracking (Track Beasts etc.), middle-click opens the calendar. The zone name shows on hover, and the clock sits along the bottom edge. |
| Other | Cooldown numbers on buttons and auras. A thin XP bar with rested XP (hover for numbers; it hides at max level). The micro menu and bags fade in on mouseover in the bottom-right corner. Chat button clutter is removed and chat scrolls with the mouse wheel (Shift jumps to top/bottom). |

Blizzard's party and raid frames, bags, tooltips and chat frames are left as they are.

## Commands

- `/mh unlock`: show movers. Drag to move; right-click a mover to reset that frame.
- `/mh lock`: hide movers. They also lock on their own when you enter combat.
- `/mh reset`: put every frame back in its default spot.

Positions are saved per character.

## Notes

- Keys: `B` opens bags, and the usual keys (`C`, `P`, `N`, `L`, `O`, `I`, `Y`…) open panels while the micro menu is hidden.
- Vehicles with their own UI use the Blizzard vehicle bar. The action bars hide until you leave the vehicle.
- Other addons' minimap buttons (LibDBIcon etc.) still orbit where the round minimap edge used to be.

## Troubleshooting

- **Nothing changes and chat says why:** [DragonUI](https://github.com/NeticSoul/DragonUI) is enabled. MinimalHunter stays inactive while it is, so turn DragonUI off for this character.
- **An action bar row is missing:** on the first login the addon turns on the extra action bars in Interface Options. If a row is still missing, `/reload` once.
- **A frame won't move:** `/mh unlock` shows the movers. They lock themselves when you enter combat, so unlock again afterwards.

## Credits

Author: [buildthehomelab](https://github.com/buildthehomelab)

## License

Released under the [MIT License](LICENSE).
