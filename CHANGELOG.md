# Unreleased
#### New and Improved:
- Latest can now be translated via [Weblate][1]
- Add Language Support for Korean (Thanks [이정희!][2])
- Add Language Support for Croatian (Thanks [Milo][3]!)
- Add Language Support for Slovak (Thanks [Marek][4]!)
- Add Language Support for Italian (Thanks [Christiano][5]!)
- Tweaked French Localisation (Thanks J. Lavoie!)
- Tweaked German Localisation

#### Now Fixed:
- Apps using DevMate should now correctly update though Latest

# 0.8
#### New and Improved:
- The Update All button returned to the toolbar. (Thanks [decodism][6]!)
- Icons of unsupported apps are now dimmed in the app list. (Thanks decodism!)
- Added an action to open apps right from app list.  

#### Now Fixed:
- Latest should be much more stable when apps are updated.
- Latest mistakenly showed updates for iPad versions of apps, fixed.
- The progress indicator on updates animates at normal speed on displays with high refresh rate.
- Fixed a crash when opening release notes that requested an unknown font.  

# 0.7.3
Version 0.7.3 fixes a crash that occurred when updating apps.

# 0.7.2
Version 0.7.2 provides smaller fixes and UI improvements:
- The source icon for each app is now displayed alongside the release notes instead of the app list.
- Tweaked the update button size and animations
- Fixes disabled "Update All" menu item
- Apps contained in other apps are no longer listed

# 0.7.1
Version 0.7.1 fixes a crash on launch that occurred for some people.

# 0.7
#### What's New:
- Refined interface with support for macOS Big Sur
- Runs natively on M1 Macs
- Adds Update checking support for iOS apps installed from the Mac App Store (M1 Macs only)
- Latest is now available in French (Thanks [Flavien][7]!)
- A little icon next to an app's name shows its source (Mac App Store or Web)
- Adds an option to display unsupported apps in the update list, they appear greyed out

#### Improvements:
- Apps in your User-Application folder are now checked as well
- Latest automatically quits when closing the window

#### Now Fixed:
- Some supported apps would not appear (Thanks [Simeon][8]!)
- The window would not maximize when minimized in the dock
- Fixed a crash when right-clicking insite the update list
- Fixed a crash when quitting Latest or updating apps while Latest is open

# 0.6.3
#### Now Fixed:
- Fixed a crash that occurred when searching for apps.

# 0.6.2
#### Improved:
- Better handling of empty selection in the update list
- Significant faster startup time for some users
- Apps are inserted faster into the list on update checks

#### Now Fixed:
- Fixed a crash that occurred after update checks.
- Minor interface and localisation fixes.

> Note: This update removes the ability to update apps from the Mac App Store directly in Latest. I plan to bring this feature back in one of the next updates.

# 0.6.1
#### Now Fixed:
- Fixed a crash that occurred after update checks.
- Minor interface and localisation fixes.

# 0.6
#### Whats New and Improved:
- Add ability to update apps within Latest! (#9)
- Add ability to ignore certain apps. (#17)

#### Now Fixed:
- Improvements to the update list and Touch Bar integration.
- Add link to website (#44) and donations page.

# 0.5
#### Whats New and Improved:
- Add search functionality to quickly browse apps by their name.
- Apps within the Setapp folder are ignored for now, as the update might not be available yet.

#### Now Fixed:
- Various graphics issues in the release notes

# 0.4.5
This is basically version 0.4.4, but there was an issue with codesigning so many people were not able to open the app. I am very sorry about that!

# 0.4.4
#### Now Fixed:
- Includes basic state restoration
- Fixes for the release notes in macOS Mojave

# 0.4.3
Version 0.4.3 slightly improves the way Latest handles offline situations and fixes a bug that caused apps in the update list to disappear after reload.

# 0.4.2
This update fixes some cases where the app could crash based on [\#25][9].

# 0.4.1
#### Now Fixed:
- Improvements to the Sparkle parser for better quality of information and filtering of unsupported apps (partly [\#27][10])
- The "Open All" button really opened all installed apps! ([\#26][11])

# 0.4
#### Whats new:
- Redesigned, uniform Release Notes ([\#3][12])
- Touch Bar Support ([\#20][13])
- Latest can show already installed updates ([\#15][14])
- Latest now searches subfolders for updates ([\#22][15])

#### Thats fixed:
- Apps will no longer disappear after reload ([\#21][16], [\#23][17])
- Some release notes failed to load ([\#24][18])

# 0.3.2
#### Now Fixed:
- Sparkle Apps deployed with DevMate are now supported
- Use a new version checker to hopefully cover more cases correctly
- Improvements to the checkers performance
- Fix stuck progress bar

# 0.3.1
- Latest can now update itself through Sparkle

# 0.3
- App reloads if an app gets updated
- Small UI tweaks

[1]:	https://hosted.weblate.org/engage/latest/
[2]:	https://github.com/MarongHappy
[3]:	https://github.com/milotype
[4]:	https://github.com/marxo126
[5]:	https://github.com/cverond
[6]:	https://github.com/decodism
[7]:	https://github.com/flavienbonvin
[8]:	https://github.com/sleifer
[9]:	https://github.com/mangerlahn/Latest/issues/25
[10]:	https://github.com/mangerlahn/Latest/issues/27
[11]:	https://github.com/mangerlahn/Latest/issues/26
[12]:	https://github.com/mangerlahn/Latest/issues/3
[13]:	https://github.com/mangerlahn/Latest/issues/20
[14]:	https://github.com/mangerlahn/Latest/issues/15
[15]:	https://github.com/mangerlahn/Latest/issues/22
[16]:	https://github.com/mangerlahn/Latest/issues/21
[17]:	https://github.com/mangerlahn/Latest/issues/23
[18]:	https://github.com/mangerlahn/Latest/issues/24