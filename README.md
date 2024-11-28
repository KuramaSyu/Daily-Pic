This project aims to add a nice extension to MacOS, providing a user friendly UI to set the desktop background.
By default the desktop background will be the image of the day from Bing. The project is written in Swift to provide an as native experience as possible.

### UI Example:
[![image.png](https://i.postimg.cc/yxzsTBRW/image.png)](https://postimg.cc/47wDJDBT)

### Features:
- next, previous, first and last image
- makeing favorites
- shuffleing images
- shuffleing favorite images only
- save settings to make them persistant
- display and save metadata of image
  
### TODO:
- [x] Undo favorite
- [x] Implement Quit Button in Quick Settings
- [x] autostart with system
- [x] shuffle button
- [x] shuffle favorites only
- [x] Only load current image and unload old images, to prevent memory from going >600MiB
- [x] Check when going backwards when beeing in the last 7 days, if a day is missing -> download image + json
- [x] Start Bing task on Display Wake as well as when started. Set as Wallpaper automatically
- [x] Screen Event triggers resetting wallpaper to the newest instead of leaving it
- [ ] Delay start 5 minutes, display it in UI and set wallpaper only, if its the newest daily image which is new
- [x] manually set wallpaper when entering a new space
- [ ] Find way to downlaod json for images older than 7 days
- [ ] Add toggle to only show favorits
- [ ] Cleanup Code
- [x] remove Focus

### Install from Articats
- goto [Workflows](https://github.com/KuramaSyu/DailyPic/actions) and select the last successfull workflow
- scroll down to artifacts and download it
- in the downloaded zip goto the macos folder
- run the app - Apple will warn you that they can't check whether or not this App is secure
- Hence allow the App in the settings:
[![image.png](https://i.postimg.cc/15LvKRLX/image.png)](https://postimg.cc/kBvNJCMP)
