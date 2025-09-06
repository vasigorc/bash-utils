#! /usr/bin/bash

# Fixing Nvidia installation for CUDA initialization on POP!_OS 22.04. Courtesy of Eric Todd (System76)
# Unfortunately this gets reset every time with automatic updates from POP!_OS
sudo apt purge ~nnvidia
sudo apt clean
sudo apt update
sudo dpkg --configure -a
sudo apt install nvidia-settings -y
apt search nvidia | egrep -i driver | egrep -v "xserver|utils|modules|vaapi|extra|common|binary|graphics"
sudo apt install nvidia-driver-570-server -y
reboot

# It may be worth starting NVIDIA's persistence daemon to prevent
# CUDA from unloading when it's not being used
sudo systemctl start nvidia-persistenced.service
sudo systemctl enable nvidia-persistenced.service
# The last command prints this
# The unit files have no installation config (WantedBy=, RequiredBy=, Also=,
# Alias= settings in the [Install] section, and DefaultInstance= for template
# units). This means they are not meant to be enabled using systemctl.
#
#  Possible reasons for having this kind of units are:
#  • A unit may be statically enabled by being symlinked from another unit's
#    .wants/ or .requires/ directory.
#    • A unit's purpose may be to act as a helper for some other unit which has
#      a requirement dependency on it.
#      • A unit may be started when needed via activation (socket, path, timer,
#        D-Bus, udev, scripted systemctl call, ...).
#        • In case of template units, the unit is meant to be enabled with some
#          instance name specified.
#
