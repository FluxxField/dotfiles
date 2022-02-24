# Onedark themed dotfiles
<img width="832" alt="Screen Shot 2022-02-24 at 2 15 57 PM" src="https://user-images.githubusercontent.com/39966609/155600895-de46ad3f-f730-4552-aa2b-a1c7df5a8849.png">

<img width="299" alt="Screen Shot 2022-02-24 at 2 15 36 PM" src="https://user-images.githubusercontent.com/39966609/155600858-b4b1835e-73b6-4b7c-890b-4dfd8600963c.png">

## Requirments
* iTerm2

## Installation
Warning: Please do not blindly use my settings unless you know what is involved. Use at your own risk

### Using Git
Clone this repo down wherever you would like. I personally keep mine in `~/github/dotfiles`
```
git clone https://github.com/FluxxField/dotfiles.git
```

cd into the dir and run the setup script to install brew and all of the packages that are needed
```
cd dotfiles && source setup.sh
```

Once the setup script is done, run the extract script to grab the dotfiles and add them to your $HOME dir
```
source extract.sh
```

### iTerm2 theme 
* `iTerm2` > `Preferences` > `Profiles` > `Colors`
* Open the `Color Presents` dorp-down in the bottom right corner
* Select `Import` from the list
* Select the `One Dark Pro.itermcolors` file
* Select the `One Dark Pro` from `Color Presets`

### iTerm2 font
* `iTerm2` > `Preferences` > `Profiles` > `Text`
* Open the `Font` drop-down and select `Victor Mono`
* Check `Use ligatures` and `Use a different font for non-ASCII text`
* Open the `Non-ASCII Font` drop-down and select `Hack Nerd Font`
* Check `Use ligatures` 
