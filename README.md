This project aims to add a nice extension to macOS, providing a user-friendly UI to set the desktop background.
By default, the desktop background will be the image of the day from Bing. The project is written in Swift to provide an as native experience as possible.

## UI Example:
[![image.png](https://i.ibb.co/Fwm0ZG2/image.png)](https://i.ibb.co/Fwm0ZG2)

## Install
1. go to [Releases](https://github.com/KuramaSyu/AuroraWalls/releases) and download the last verison (named `AuroraWalls.arm.zip`)
2. Unzip it and drag AuroraWalls into Applications
3. run the app - **A warning will appear** -> click **"Done"**:
<img src="https://i.postimg.cc/3wd5Mxvn/image.png" width="200">

4. Go to `Settings`, search `GateKeeper`, click in `Open Anyway`:
<img src="https://i.postimg.cc/pXJJvQQL/image.png" width="400">

## Features:
- next, previous, first and last image
- making favorites
- shuffling images
- shuffling favorite images only
- save settings to make them persistent
- display and save metadata of image
- reveal new image after 5 minutes, to show the last image a last time
  


## TODO:
- [x] Undo favorite
- [x] Implement Quit Button in Quick Settings
- [x] autostart with system
- [x] shuffle button
- [x] shuffle favorites only
- [x] Only load current image and unload old images, to prevent memory from going >600MiB
- [x] Check when going backwards when being in the last 7 days, if a day is missing → download image + json
- [x] Start Bing task on Display Wake as well as when started. Set as Wallpaper automatically
- [x] Screen Event triggers resetting wallpaper to the newest instead of leaving it
- [x] Delay start 5 minutes, display it in UI and set wallpaper only, if it's the newest daily image which is new
- [x] manually set wallpaper when entering a new space
- [x] Find way to download JSON for images older than 7 days → up to 14 days
- [ ] Add toggle to only show favorites
- [ ] Cleanup Code
- [x] remove Focus
- [ ] when image reveal is triggered, cancel methods from downloading the image again
- [ ] don't download when using limited bandwidth Wi-Fi
- [x] fix reveal when in sleep during reveal
- [x] fix crashes when deleting images 


## Build it yourself
- git clone this repo
- 
    ```bash
    xcodebuild -scheme "Aurora Walls" -configuration Release clean build -derivedDataPath ./build
    ```
