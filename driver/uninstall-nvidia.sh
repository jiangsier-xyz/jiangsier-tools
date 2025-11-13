#!/usr/bin/env bash

sudo nvidia-installer --uninstall  # interactive

sudo modprobe -r nvidia_uvm
sudo modprobe -r nvidia
sudo modprobe -r nvidia_drm
sudo modprobe -r nvidia_modeset

sudo systemctl stop nvidia-persistenced
sudo systemctl disable nvidia-persistenced

# reboot
sudo systemctl reboot
