# Latest

This is Latest, a small utility app for the Mac. Latest is a free and open source app for macOS that checks if all your apps are up to date. Get a quick overview of which apps changed and what changed and update them right away. Latest currently supports apps downloaded from the Mac App Store and apps that use Sparkle for updates, which covers most of the apps on the market.

Latest is developed in my freetime, so occasional updates may happen. Take a look at the [Issues][1] section to see what's coming. If you have an idea for a new feature, or encounter any bugs, feel free to open a new issue. 
I am thankful for contributions. Check out the section below for more information.

![][image-1]

## Installation
There are multiple ways to install the app.

### Download the App
The easiest way to install Latest is to [download][2] the latest release as an app. You unzip the download by double clicking on it (if that does not happen automatically) and then move the `Latest.app` into the `Applications` folder.

If you would like to check out earlier versions, head over to the [Releases][3] page to browse the history of Latest.

### Homebrew Cask
Latest can also be installed via [Homebrew Cask][4]. If you have not installed Homebrew, follow the simple instructions [here][5].
After that, run `brew install --cask latest` to install the current version of Latest.

### Build from Source
[![Build Status][image-2]][6]

**To build Latest, Xcode 11 and Swift 5 is required.**

You can build Latest directly on your machine. To do that, you have to download the source code by cloning the repository: `git clone --recurse-submodules git@github.com:mangerlahn/Latest.git`.

Then you can open the `Latest.xcodeproj` and hit *Build and Run*. Make sure that the `Latest` scheme is selected. Latest uses submodules to organize its dependencies. If the project is not building, make sure submodules are initialized correctly. To update them, call `git submodule update --init --recursive`.

## Contribution
I am thankful for all contributions. Take a look at the [Issues][7] section to see what you can do. If you have your own idea and it does not appear in the issues list, please add it first. I don't think that I would reject any pull request, but it is useful to know about your idea earlier. Imagine two people have the same idea at the same time and both put a lot of work into that just to find out that someone else has made the same when it's too late.  

I would like to assign every issue to the person working on that particular thing, so if you would like to implement something, leave a small note in the issue. I will assign the issue to you and its yours.

## Donation
As mentioned above, Latest is free for you to use. I work on the app in my free time. If you would like to support the development by donating, you can do so [here][8].

[1]:	https://github.com/mangerlahn/latest/issues
[2]:	https://max.codes/latest/Latest.zip
[3]:	https://github.com/mangerlahn/Latest/releases
[4]:	https://github.com/Homebrew/homebrew-cask
[5]:	https://brew.sh
[6]:	https://travis-ci.org/mangerlahn/Latest
[7]:	https://github.com/mangerlahn/latest/issues
[8]:	https://max.codes/latest/donate

[image-1]:	./latest.png
[image-2]:	https://travis-ci.org/mangerlahn/Latest.svg?branch=master