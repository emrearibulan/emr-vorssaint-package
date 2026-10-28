# App shortcuts

Top-level feature label: **App shortcuts -emr**. Individual app/game names are untagged.

Feature ID: `apps-games-launcher`; individual action ID: `emr.app.<saved-UUID>`.

Each chosen app gets its own side icon in the opened Dynamic Island. Open
**Settings → Dynamic Island → Layout → App shortcuts -emr** and add apps one at a time:

1. Choose **Add from CrossOver → app — bottle** for a discovered wrapper.
2. Or choose **Add App or Game…** and select one installed `.app`.
3. The new icon uses the first free side slot. Choose Left, Right or Bottom
   beside its name; click its island icon to launch the exact app.

CrossOver's wrapper owns the bottle and command. No shell command is constructed.
Discovery reads wrappers under the current user's `~/Applications/CrossOver` folder
and displays their `CXHelperAppBottleName`. A game needs a macOS launcher wrapper;
Windows executables and shortcuts are not imported directly. Apps elsewhere can be
selected through the app picker.

Use up/down controls to reorder apps, or remove an entry without uninstalling it.
The layout editor also supports moving buttons and selecting saved apps with +.
There are three slots per side, including hidden section buttons. If none is free,
an added app is saved as Not placed; remove an unused button and choose a side.
Existing buttons are not replaced automatically.

Entries use local bookmarks and fallback paths under `notchLauncherEntries`.
Bookmarks can resolve moved apps; unavailable apps report an error rather than
running another command. Duplicate selections do not create extra entries. Up to
100 apps can be saved, with up to nine total side-button slots across three sides.
Nothing launches automatically at login or startup.

Each Mac chooses its own apps. No maintainer app paths, bottle names, selections
or personal settings are shipped in source releases.
