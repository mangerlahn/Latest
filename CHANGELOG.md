# Unreleased Changes

# 0.10.3
Fixes a crash that may occur after updating to 0.10.2.

# 0.10.2
This update fixes more issues with the Homebrew check introduced in a recent update. Thank you for your continued reports, [please keep them coming][1]!

- Language support for:
	- Hebrew
	- Serbian (Thanks smudja)!
	- Various tweaks to other languages.


# 0.10.1
This update fixes many issues with the Homebrew check introduced in the last update. Sorry for the inconvenience and thanks for the numerous reports highlighting these issues. [Please keep them coming][2]!
 
- Improvements to update checking:
	- Fix many cases where an update would be shown for up to date apps
	- Fix using wrong app variant for version checking
	- Ignore certain apps with unclear version information
	- Ignore Safari web apps in update checks
	- Ignore apps without version information

- Various interface improvements:
	- Clarify which apps can be updated within Latest
	- Tweak interface when search did not find any apps

- Fixes a crash some people encountered that would occur when launching the app.

- Language support for:
	- Bulgarian (Thanks Desislav!)
	- Romanian (Thanks arsradu!)
	- Turkish (Thanks Hakan!)
- Tweaks for many languages, including Italian, Korean & Slovak (Thanks everyone!)


# 0.10
#### New and Improved:
- Added update checking via Homebrew Cask, which should allow for many more updates to be found
- The app list is now sorted by recently updated apps. Sort by app name can be restored via the main menu: View \> Sort By \> Name
- Improved messages when no release notes are available
- Interface improvements for macOS Sonoma

- Language support for:
	- Arabic (Thanks Hussain & Nas!)
	- Traditional Chinese (Thanks Pan!)
	- Filipino (Thanks Gean Paulo!)
	- Polish (Thanks Konrad!)
	- Portugiese (Brasilian) (Thanks Felipe!)
- Tweaks for many languages, including Czech, Italian and Swedish (Thanks Jiří, Francesco, Peeter and all the others!)

#### Bug Fixes:
- Fixed a crash when updating apps via context menu
- Fixed an UI crash when updating apps
- Fixed cases in which the update button would be hidden
- Attempt to fix app list being empty
- The Update All button now only updates apps within Latest (no other apps will be opened)
- Fixed loading of release notes for certain apps

# 0.9
#### New and Improved:
- Apps from the Mac App Store can be updated from within Latest
- Ignored Apps can be shown independent of installed apps
- Updates only show up if they are compatible with the installed operating system
- Show installed apps by default

- Language Support for Czech (Thanks Lubos!)
- Language Support for Hungarian (Thanks Barczi!)
- Language Support for Indonesian (Thanks Adrian!)
- Language Support for Norwegian Bokmål (Thanks Sander!)
- Language Support for Persian (Thanks Shayan!)
- Language Support for Swedish (Thanks Tygyh & Peter!)
- Language Support for Ukrainian (Thanks Ihor!)

#### Bug Fixes
- Tweaked Croatian localization (Thanks Milo!)
- Fixed empty app list when spotlight search is disabled (Thanks Mikhail!)
- Latest now remembers the width of the update list
- Fixed a crash with non-western arabic numerals in version numbers

# 0.8.3
- Language Support for Catalan (Thanks Maite!)
- Language Support for Dutch (Thanks Eitot!)
- Language Support for Greek (Thanks Efthymis!)
- Language Support for Spanish (Thanks Darío!)
- Language Support for Simplified Chinese
- Hopefully fixed some crashes around updating apps.

# 0.8.2
- Language Support for Portuguese (Thanks Filipe!)
- It should also fix a crash on launch occurring on macOS 10.13. Sorry about that!

# 0.8.1
#### New and Improved:
- Language Support for various languages like:
	- Croatian (Thanks Milo!)
	- Italian (Thanks Christiano!)
	- Korean (Thanks 이정희!)
	- Malay (Thanks Rosdi!)
	- Slovak (Thanks Marek!)
- Tweaked French Localization (Thanks J. Lavoie!)
- Tweaked German Localization
More langauges like Arabic, Catalan, Chinese, Indonesian and Norwegian are well on the way.

#### Now Fixed:
- Added a fallback to look for files manually if Spotlight is not available (Thanks mbarashkov!)
- Apps using DevMate should now correctly update though Latest
- Smaller UI fixes
# 0.8
#### New and Improved:
- The Update All button returned to the toolbar. (Thanks [decodism][3]!)
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
- Latest is now available in French (Thanks [Flavien][4]!)
- A little icon next to an app's name shows its source (Mac App Store or Web)
- Adds an option to display unsupported apps in the update list, they appear greyed out

#### Improvements:
- Apps in your User-Application folder are now checked as well
- Latest automatically quits when closing the window

#### Now Fixed:
- Some supported apps would not appear (Thanks [Simeon][5]!)
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
This update fixes some cases where the app could crash based on [\#25][6].

# 0.4.1
#### Now Fixed:
- Improvements to the Sparkle parser for better quality of information and filtering of unsupported apps (partly [\#27][7])
- The "Open All" button really opened all installed apps! ([\#26][8])

# 0.4
#### Whats new:
- Redesigned, uniform Release Notes ([\#3][9])
- Touch Bar Support ([\#20][10])
- Latest can show already installed updates ([\#15][11])
- Latest now searches subfolders for updates ([\#22][12])

#### Thats fixed:
- Apps will no longer disappear after reload ([\#21][13], [\#23][14])
- Some release notes failed to load ([\#24][15])

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

[1]:	https://github.com/mangerlahn/Latest/issues
[2]:	https://github.com/mangerlahn/Latest/issues
[3]:	https://github.com/decodism
[4]:	https://github.com/flavienbonvin
[5]:	https://github.com/sleifer
[6]:	https://github.com/mangerlahn/Latest/issues/25
[7]:	https://github.com/mangerlahn/Latest/issues/27
[8]:	https://github.com/mangerlahn/Latest/issues/26
[9]:	https://github.com/mangerlahn/Latest/issues/3
[10]:	https://github.com/mangerlahn/Latest/issues/20
[11]:	https://github.com/mangerlahn/Latest/issues/15
[12]:	https://github.com/mangerlahn/Latest/issues/22
[13]:	https://github.com/mangerlahn/Latest/issues/21
[14]:	https://github.com/mangerlahn/Latest/issues/23
[15]:	https://github.com/mangerlahn/Latest/issues/24