# Terminals

This directory is designed to hold set-up configurations/scripts/instructions for setting-up terminals/terminal emulators.

## Kitty

Blasting fast, feature-rich, GPU based terminal emulator with great TMUX integration.

⚠️ Note, that in order to correctly display some of the dev icons and fonts, you will need to install a [Nerd Font](https://www.nerdfonts.com/).

Copy the [`./kitty.conf`](./kitty.conf) to `~/.config/kitty/` (on Linux) to make Kitty pick-up your nerd font. The attached
configuration file is configured to use JetBrainsMono NL, find and replace the corresponding item to name the nerd font that you installed if different.

### kitty-catpuccin

In order to be able to use the same theme in NeoVim and in terminal, follow first instructions
from this GitHub repository: <https://github.com/catppuccin/kitty/tree/main>

Then copy [`./kitty.conf`](./kitty.conf) to `~/.config/kitty/` (on Linux).

## tmux

Structured cheat sheets for using tmux terminal multiplexer are given in [tmux folder](./tmux/)

- [Core Concepts and Navigation](./tmux/1-CoreConceptsNavigation.md)
- [Advanced Window Management](./tmux/2-AdvancedWindowManagement.md)
- [Configuration and Customization](./tmux/3-ConfigurationAndCustomization.md)
- [Plugins and Power Features](./tmux/4-PluginsAndPowerFeatures.md)

This directory also contains custom [tmux.conf](./tmux/.tmux.conf) file.
