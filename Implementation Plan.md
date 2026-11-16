# Immersive Quest Tracker implementation plan

Immersive Quest Tracker applies the WoW Forever appearance to the quest tracker selected in EllesmereUI. The first target is WoW Forever 1.60.1 build 70938 (interface 16001) with EllesmereUI 9.8.6. The Blizzard renderer is the pixel-for-pixel comparison target. The custom renderer uses Forever art and keeps its configurable layout and quest tools.

## 1. Use EllesmereUI's existing tracker toggle

- Honor EUI's **Custom Quest Tracker** toggle and its reload prompt. In custom mode, keep EUI's interactions and options. Use Blizzard's All Objectives and Quests header templates, the Forever font and drop shadow by default, and Blizzard's focus icon dimensions and pixel snapping. Custom row spacing, wrapping, and grouping follow EUI's layout.
- In Blizzard mode, show the stock master header and hide EUI's optional filter shortcut. Use Blizzard's stock header button hit area. Filtering is available in EUI settings. Preserve the native tracker fonts and pixel snapping when EUI applies global styling. [EUI header behavior](https://github.com/EllesmereGaming/EllesmereUI/blob/46616092c2899441335de2fd48e8b09ff460cbb8/EllesmereUIQuestTracker/EllesmereUIQuestTracker_Skin.lua#L380)
- Apply the appearance automatically. Each EUI profile keeps its saved appearance and renderer preference. On upgrade, restore any appearance values that version 0.1.0 still owns in the saved profiles.
- Keep the Blizzard tracker frame, section headers, buttons, fonts, colors, anchors, and timers. Use the same Blizzard Edit Mode layout and settings in the stock and skinned captures. EUI Unlock Mode position, visibility, and quest-tool settings can affect what appears in a capture, so match them to the stock setup when measuring the skin. [Forever tracker templates](https://github.com/BigWigsMods/WoWUI/blob/4ca67b2307a27f4954848cc786e6d23d0c7bc007/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerContainer.xml) · [EUI renderer selection](https://github.com/EllesmereGaming/EllesmereUI/blob/46616092c2899441335de2fd48e8b09ff460cbb8/EllesmereUIQuestTracker/EllesmereUIQuestTracker.lua#L119)

## 2. Compare the renderers in game

For a local test, copy `addon/ImmersiveQuestTracker` into the Forever client's `Interface/AddOns` and start the client with both addons enabled. The appearance applies at login. Use `/iqt` to check whether the companion attached to EUI.

1. Make an EUI test profile and keep a single character in a stationary scene with tracked quests. Capture Blizzard stock with EUI disabled. Enable the EUI tracker and companion, turn off **Custom Quest Tracker**, reload, and capture again. Keep the same character, quest watch list, camera, viewport, locale, UI scale, and Edit Mode tracker rect and settings. Use lossless PNG captures. In the stock comparison, disable EUI behaviors that would change the watch list or visibility between captures.
2. Use the same crop coordinates in both screenshots. Include room for the full header and artwork, the quest item buttons, and the timer when applicable. Compare the PNGs using the script below. The output shows stock, the skinned tracker, and changed pixels from left to right. A settled state passes when the changed-pixel count is zero.
3. Repeat for empty, expanded, and collapsed states, multiple sections, wrapped objectives, focused and completed quests, a long list at its height limit, quest items with charges or cooldowns, and a timed quest. Match the timer value and cooldown phase for exact comparison. Check hover, pressed, tooltips, and animated states separately at equivalent moments. Confirm that the mouse and secure actions work after login, after reload, and through combat transitions.

```powershell
pwsh -NoProfile -File scripts/Compare-TrackerScreenshots.ps1 -StockPath stock.png -PresetPath preset.png -X 1400 -Y 190 -Width 350 -Height 620 -OutputPath tracker-comparison.png
```

Run the comparison script in PowerShell 7 on Windows. The crop coordinates above are examples in screen pixels. Use the actual capture's tracker rect and surrounding control area.

## 3. Retain EUI quest tools

| Feature | Implementation and test |
| --- | --- |
| Sort, filter, and auto-track zone quests | Enable Experimental Quest Tools in EUI's native tracker settings and exercise the existing watch-list integration. Check transitions across zones, filters, and combat. |
| Auto-accept and turn-in, progress sounds and announcements, Wowhead links, and quest-item hotkey | Exercise the existing EUI integrations on the native renderer. Verify watch progress, item use and cooldown, and configured modifier behavior. |
| Visibility rules, position, and profile switching | Use the existing EUI controls. Test switching profiles with the companion enabled, then disable it and reload to check each profile's saved style. Check recovery when a visibility rule clears. |
| Focus, map, tracked recipes, item buttons, and timers | Use native widgets where they provide the action. Verify the equivalent interaction and confirm the stock widget's appearance. |
| Custom-only features such as pinning, per-quest collapse, custom details, zone grouping, and quest audio row buttons | Turn on **Custom Quest Tracker** in EUI and reload. Verify that its options are editable and its features still work with the companion enabled. Zone grouping and other layout controls can produce a different layout from the Blizzard renderer. |

[EUI tracking options](https://github.com/EllesmereGaming/EllesmereUI/blob/46616092c2899441335de2fd48e8b09ff460cbb8/EllesmereUIOptions/EUI_QuestTracker_Options.lua#L658) · [EUI custom row API](https://github.com/EllesmereGaming/EllesmereUI/blob/46616092c2899441335de2fd48e8b09ff460cbb8/PLUGINS_API.md#L308)

The expanded Blizzard view in v0.2.2 passed a live pixel comparison at 0.64 UI scale. Zone grouping and collapse passed a live check on the custom renderer in v0.3.0. The live v0.3.1 custom view showed blank header labels, a clipped collapse button, and different turn-in styling. Version 0.3.2 addresses those issues. A matched-scale stock versus custom capture is still pending.
