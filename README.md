# Immersive Quest Tracker Skin

<p><img src="branding/icon.png" width="96" height="96" alt="Immersive Quest Tracker Skin icon"></p>

Give EllesmereUI’s quest tracker the stock WoW Forever look, with Blizzard-style headers, quest icons, and a dark bronze Quest Details window.

## What it does

- Brings back the familiar **All Objectives** and **Quests** headers, quest typography, and quest markers.
- Works with both tracker modes in EllesmereUI. Use **Custom Quest Tracker** for features like zone grouping, pinning quests, and the standalone Quest Details window.
- In custom mode, left-click opens a tracked quest in the Quest Log out of combat by default. Ctrl-click still expands or collapses objectives, and you can pick a different action under **Quest Click**.
- Choose **Open Quest Details** under **Quest Click** to use the dark bronze popup with objectives, rewards, and quest actions.

## Getting started

Install the addon and enable **EllesmereUI Quest Tracker**. The skin applies automatically when you log in. Type `/iqt` to check which tracker mode the skin is using.

For a manual install, unzip the release into `_forever_/Interface/AddOns` so that `ImmersiveQuestTracker` is directly inside `AddOns`. Restart the game after installing.

Built for **WoW Forever 1.60.1**. Requires **EllesmereUI** with its Quest Tracker module enabled. Developed against EllesmereUI 9.8.6. [EllesmereUI on CurseForge](https://www.curseforge.com/wow/addons/ellesmereui)

### Custom tracker appearance options

The following options are available in this repository's version of the skin. They require **Custom Quest Tracker** and the separate [EllesmereUI settings patch](scripts/EllesmereUI-9.8.6-QuestTrackerConfig.patch); installing the skin alone does not add the controls. After applying the patch and reloading, open **EllesmereUI → Quest Tracker → Immersive Quest Tracker Skin**.

- **Merge Quest Headers** replaces the separate headers with one **Quests** header containing the quest count and collapse button. It is off by default.
- **Immersive Border** frames the sides and bottom of the tracker. The header supplies the top trim and extends slightly past the sides. It is off by default.
- **Border Style** selects **Bronze Tooltip** (default), **Silver Dialog**, or **Gold Dialog**.
- **Border Width** sets the edge size from 2 to 24 UI units (default 12). The edge is reduced as needed to fit the tracker, including when collapsed.
- **Border Offset** moves the sides and bottom from -6 to 16 UI units (default 0). Positive values move the border outward; negative values move it inward.

Border style, width, and offset are available while Immersive Border is enabled. These settings are saved per EllesmereUI profile.

The border stays fully opaque when changing background opacity or using background hover fade. It follows the tracker's overall visibility along with the headers.

To install the controls, download the patch from the repository and, from the game's `Interface/AddOns` directory, run `git apply --ignore-space-change <path-to-patch>` with Git installed. Replace `<path-to-patch>` with the downloaded patch's path, then reload the UI. The patch applies to clean EllesmereUI 9.8.6 and 9.8.8 installs. An EllesmereUI update can overwrite the patched settings file, requiring the patch to be reapplied.
