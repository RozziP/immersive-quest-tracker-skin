# Immersive Quest Tracker Skin

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

### Custom tracker appearance

With the [EllesmereUI settings patch](scripts/EllesmereUI-9.8.6-QuestTrackerConfig.patch) applied, open **EllesmereUI → Quest Tracker → Immersive Quest Tracker Skin** with **Custom Quest Tracker** enabled.

- **Merge Quest Headers** shows a single **Quests** header with the quest count and collapse button.
- **Immersive Border** frames the sides and bottom. The main header supplies the top trim and extends slightly past the sides. Choose **Bronze Tooltip**, **Silver Dialog**, or **Gold Dialog**, then adjust the edge width and offset in UI units. Positive offsets move the border outward and negative offsets move it inward.

Each toggle is off by default and saved per EUI profile.

From the game's `Interface/AddOns` directory, run `git apply --ignore-space-change <path-to-patch>` and reload the UI. The patch applies to clean EllesmereUI 9.8.6 and 9.8.8 installs. An EllesmereUI update can overwrite the patched settings file.
