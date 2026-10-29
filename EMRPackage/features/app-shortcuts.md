# App shortcuts

Top-level feature label: triangular emr icon followed by **App shortcuts**. Individual app/game/website names are untagged.

Feature ID: `apps-games-launcher`; individual action ID: `emr.app.<saved-UUID>`.

Each chosen app or website gets its own side icon in the opened Dynamic Island. Open
**Settings → Dynamic Island → Layout → App shortcuts** and add shortcuts one at a time:

1. Choose **Add from CrossOver → app — bottle** for a discovered wrapper.
2. Or choose **Add App or Game…** and select one installed `.app`.
3. Or choose **Add Website…**, enter an HTTP/HTTPS URL and optional name, then **Add**.
4. The new icon uses the first free side slot. Choose Left, Right or Bottom
   beside its name; click its island icon to launch the exact app or open the saved URL in the default browser.

CrossOver's wrapper owns the bottle and command. No shell command is constructed.
Discovery reads wrappers under the current user's `~/Applications/CrossOver` folder
and displays their `CXHelperAppBottleName`. A game needs a macOS launcher wrapper;
Windows executables and shortcuts are not imported directly. Apps elsewhere can be
selected through the app picker.

Use up/down controls to reorder shortcuts, or remove an entry without uninstalling it.
The layout editor also supports moving buttons and selecting saved shortcuts with +.
There are three slots per side, including hidden section buttons. If none is free,
an added shortcut is saved as Not placed; remove an unused button and choose a side.
Existing buttons are not replaced automatically.

App entries use local bookmarks and fallback paths under `notchLauncherEntries`.
Bookmarks can resolve moved apps; unavailable apps report an error rather than
running another command. Duplicate selections do not create extra entries. Up to
100 app/website shortcuts can be saved, with up to nine total side-button slots across three sides.
Nothing launches automatically at login or startup.

Each Mac chooses its own apps and websites. No maintainer app paths, bottle names, selections
or personal settings are shipped in source releases.

Website entries add an optional `website` URL to the existing saved entry model;
old app entries, bookmarks, IDs and layout action IDs remain compatible. Websites
never use app bookmarks or shell execution. Exact normalized duplicate URLs are
rejected; distinct pages can be saved separately. Empty website names use the host.

Icon discovery requests the origin homepage without the saved path/query, reads
[standard icon declarations](https://html.spec.whatwg.org/multipage/links.html#rel-icon)
and apple-touch-icon links, then tries the origin's favicon.ico/apple-touch-icon.png.
Relative icon links, a valid base URL, redirects, sizes and common HTML entities are
handled. A fresh ephemeral URLSession has no cookie store, credentials or URL cache.
Only HTTP/HTTPS resources are fetched; redirects, request duration, response bytes
and decoded raster dimensions are bounded. Icon hosts declared by the site may be
contacted, including a CDN. Unsupported or absent icons leave a working globe.

A normalized colour PNG (up to 128px) is cached under the integrated app's Caches folder
by entry UUID. A luminance-based light/dark backing keeps website logos visible
while preserving their colours. **Refresh icon** retries a failed fetch or updates the cached icon;
a failed refresh retains an existing icon. Removing the shortcut cancels its
pending result and removes its cached file. No websites are bundled by default.
