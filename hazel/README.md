[Hazel](https://www.noodlesoft.com/) watches folders and executes actions (including your scripts) when conditions are matched. These are the Hazel rules I am currently using, and they can be imported into Hazel for customization. Hazel v5 was recently released as a standalone app, but it appears these [can still be imported](https://www.noodlesoft.com/kb/hazel-5-faq/).

### Desktop
- Watches `~/Desktop`. Creates `~/Desktop/Workbench` and moves here non-directory files added >7 days ago and not opened in the last 2 days.

### Downloads
- Watches `~/Desktop/Downloads`.
- Applies blue color to newly added items for 1 day
- Makes `~/Downloads/DMGs` and moves there DMGs added more than 1 week ago.
- Creates `~/Downloads/ Downloads Offload` and moves there non-directory files neither created nor opened in the last 6 months. These could be moved off to an external drive when attached (I use a [Keyboard Maestro](https://www.keyboardmaestro.com/) mounted volume trigger).
- Some file type sorting rules, off by default.

### Setapp
[Setapp](https://setapp.com/) provides lots of high-quality Mac (and iOS) apps under a subscription service. It uses `Setapp.app` to manage apps installed in `~/Setapp/`, so I use this Hazel rule to generate a list of installed Setapp apps whenever a new app is added. The list output is `~/.dotfiles/setapp-install.txt`. The rule simply runs an embedded form of `~/.dotfiles/setapp-install.sh`, so you can do this without Hazel as well.