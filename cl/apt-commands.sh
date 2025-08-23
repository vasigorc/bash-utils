#! /usr/bin/bash

# Fixing Nvidia installation for CUDA initialization on POP!_OS 22.04. Courtesy of Eric Todd (System76)
sudo apt purge ~nnvidia
sudo apt clean
sudo apt update
sudo dpkg --configure -a
sudo apt install nvidia-settings -y
apt search nvidia | egrep -i driver | egrep -v "xserver|utils|modules|vaapi|extra|common|binary|graphics"
sudo apt install nvidia-driver-570-server -y
