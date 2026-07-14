MANGOSBOT 2.0 FOR WOW 2.4.3

Mangosbot is a modular in-game manager for the exact Bartcraft
CMaNGOS/playerbots core. It provides a compact team roster, hireling
management, pinned selected-bot controls, whole-group commands, guided
class/spec packages, and searchable access to all 756 scanned strategies.

QUICK START

1. Restart WoW after updating the addon.
2. Press F11 or enter /bot to open the team roster.
3. Click a bot row to open its pinned control window.
4. Use Setup for safe class/spec packages.
5. Use Strategies to search and toggle individual strategies.
6. Use Status to inspect exact confirmed CO/NC state and failures.
7. Enter /bot group for the whole-party/raid command bar.

SLASH COMMANDS

/bot             Toggle roster
/bot group       Toggle group command bar
/bot hirelings   Toggle hireling browser
/bot refresh     Refresh roster and hirelings
/bot status      Open the pinned bot window
/bot selftest    Run in-client diagnostics

SAFETY RULES

- Strategy changes always target the pinned selected bot.
- Group action buttons broadcast to the whole party or raid.
- Strategy controls wait for the core reply before showing confirmed state.
- CO and NC controls are available independently for every usable compatible strategy; catalog families are recommendations.
- BLOCKED placeholder/alias entries remain reference-only.
- The required non-combat default strategy is protected from removal.
- Guided packages configure AI only and never change talents.

REFERENCE DATA

The supplied CSV, SQLite, XLSX, and SQL files are development references.
The shipped addon uses generated Lua data and does not read those files at
runtime. The original monolithic addon is preserved under Legacy/ and is not
loaded by Mangosbot.toc.

See docs/in-game-acceptance.md for the exact-core verification checklist.
