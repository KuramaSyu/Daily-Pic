This project aims to add a nice extension to MacOS, providing a user friendly UI to set the desktop background.
By default the desktop background will be the image of the day from Bing. The project is written in Swift to provide an as native experience as possible.

### UI Example:
[![image.png](https://i.postimg.cc/Y9Zq3CmC/image.png)](https://postimg.cc/Hc0gWH2q)


### TODO:
- [x] Undo favorite
- [x] Implement Quit Button in Quick Settings
- [x] autostart with system
- [x] shuffle button
- [x] shuffle favorites only
- [ ] Only load current image and unload old images, to prevent memory from going >600MiB
- [ ] Check when going backwards when beeing in the last 7 days, if a day is missing -> download image + json
- [ ] Start Bing task on Display Wake as well as when started. Set as Wallpaper automatically

~~Set Wallpaper for every space instead of just one~~
- [ ] -> not possible with SwiftUI, manually set it when entering a new space
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
