# Latest

This is Latest, a small utility app for the Mac. Latest is a free and open source app for macOS that checks if all your apps are up to date. Get a quick overview of which apps changed and what changed and update them right away. Latest currently supports apps downloaded from the Mac App Store and apps that use Sparkle for updates, which covers most of the apps on the market.

Latest is developed in my freetime, so occasional updates may happen. Take a look at the [Issues](https://github.com/mangerlahn/latest/issues) section to see what's coming. If you have an idea for a new feature, or encounter any bugs, feel free to open a new issue. 
I am thankful for contributions. Check out the section below for more information.

![](./latest.png)

## Installation 
There are multiple ways to install the app.

### Download the App
The easiest way to install Latest is to [download](https://max.codes/latest/Latest.zip) the latest release as an app. You unzip the download by double clicking on it (if that does not happen automatically) and then move the `Latest.app` into the `Applications` folder.

If you would like to check out earlier versions, head over to the [Releases](https://github.com/mangerlahn/Latest/releases) page to browse the history of Latest.

### Homebrew Cask
Latest can also be installed via [Homebrew Cask](https://github.com/Homebrew/homebrew-cask). If you have not installed Homebrew, follow the simple instructions [here](https://brew.sh).
After that, run `brew cask install latest` to install the current version of Latest.

### Build from Source 
[![Build Status](https://travis-ci.org/mangerlahn/Latest.svg?branch=master)](https://travis-ci.org/mangerlahn/Latest)

**To build Latest, Xcode 10 and Swift 4.2 is required.**

You can build Latest directly on your machine. To do that, you have to download the source code either by cloning the repository or downloading the zipped source code. 

Latest uses `Carthage` as its dependency manager. If you don't have Carthage installed, do so with `brew install carthage`.
Then navigate into the `Frameworks` folder and run `carthage update`. This will download and build the `Sparkle` dependency that is used to update Latest itself.

Then you can open the `Latest.xcodeproj` and hit *Build and Run*.

## Contribution
I am thankful for all contributions. Take a look at the [Issues](https://github.com/mangerlahn/latest/issues) section to see what you can do. If you have your own idea and it does not appear in the issues list, please add it first. I don't think that I would reject any pull request, but it is useful to know about your idea earlier. Imagine two people have the same idea at the same time and both put a lot of work into that just to find out that someone else has made the same when it's too late.  

I would like to assign every issue to the person working on that particular thing, so if you would like to implement something, leave a small note in the issue. I will assign the issue to you and its yours.

## Donation
As mentioned above, Latest is free for you to use. I work on the app in my free time. If you would like to support the development by donating, you can do so [here](https://max.codes/latest/donate).
