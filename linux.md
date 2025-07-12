# My Linux Setup Guide

unplug the hdds

loadkeys de-latin1

followed installation guide (https://wiki.archlinux.org/title/Installation_guide) until

## 1.9 "Partition the disks"
where used part table
  512 MB efi system partition
  rest   linux x86-64 root

then followed dm-crypt guide (https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system) section 2 "LUKS on a partition"

## 2.1 "Preparing the disk"
  - skipped

## 2.2 "Preparing non-boot partitions"
replaces installation guide 1.10 "Format the partitions"

instead of
  cryptsetup -v luksFormat DEVICE

I followed guide dm-crypt encryption options (https://wiki.archlinux.org/title/Dm-crypt/Device_encryption#Encryption_options_for_LUKS_mode)
This says the above is equivalent to
  cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --hash sha256 --iter-time 2000 --key-size 256 --pbkdf argon2id --use-urandom --verify-passphrase device

I used
  cryptsetup -v -s 512 -h sha512 --sector-size 4096 luksFormat DEVICE

then followed guide and did
  cryptsetup open DEVICE root

  mkfs.ext4 /dev/mapper/root

  mount /dev/mapper/root /mnt

## 2.3 "Preparing the boot partition"
followed exactly, mounted also executed
  mount --mkdir ESPPART /mnt/boot

## 2.4 "Mounting the devices"
nothing to do

!! went back to installation guide

## 1.11 "Mount the file systems"
already done

## 2

## 2.1 "Select the mirrors"
was fine with default

## 2.2 "Install essential packages"
I did
```bash
  pacman -Sy
  pacman -S archlinux-keyring
  pacstrap -K /mnt base linux linux-firmware gvim networkmanager base-devel cmake openssh
```
  ( did not install amd-ucode as I had already done this previously )

## 3

## 3.1 "fstab"
  genfstab -U /mnt >> /mnt/etc/fstab

## 3.2 "chroot"
  arch-chroot /mnt

## 3.3 "Time"
  ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
  hwclock --systohc

## 3.4 "Localization"
  vim /etc/locale.gen
    en_US.UTF-8
  locale-gen
  vim /etc/locale.conf
    LANG=en_US.UTF-8
  vim /etc/vconsole.conf
    KEYMAP=de-latin1

## 3.5 "Network configuration"
  vim /etc/hostname
    joseph-desktop

!! went back to dm-crypt guide

## 2.5 "Configuring mkinitcpio"
replaces installation guide "3.5 Initramfs"

used udev with
  vim /etc/mkinitcpio.conf
    HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)
  mkinitcpio -P

!! went back to installation guide

## 3.7 "Root password"

  passwd ...

## 3.8 "Boot Loader"
used systemd-boot following guide (https://wiki.archlinux.org/title/Systemd-boot)
didn't need to install anything, already included
using kernel parameters from dm-crypt guide
  bootctl install
  vim /boot/loader/loader.conf
    default arch.conf
    timeout 3
    console-mode max
    editor no
  vim /boot/loader/entries/arch.conf
    title Arch Linux
    linux /vmlinuz-linux
    initrd /initramfs-linux.img
    options cryptdevice=UUID=device-UUID:root root=/dev/mapper/root
  cp /boot/loader/entries/arch.conf /boot/loader/entries/arch-fallback.conf
  vim !$
    initrd /initramfs-linux-fallback.img

## Post setup:
had to enable NetworkManager
login as root into tty
  systemctl enable NetworkManager
relogin

had to install sudo

create user
  useradd -m joseph -G sudo
or
  useradd -m joseph
  usermod -aG sudo joseph
set password
  passwd joseph

install sudo
allow sudo group to run sudo
  EDITOR=/bin/vim visudo
    Defaults editor=/usr/bin/vim
    %sudo ALL=(ALL:ALL) ALL

install important packages
  pacman -S git
  pacman -S ly

enable
  systemctl enable ly

install wm
  pacman -S xorg xorg-xinit i3 i3status
    (selecting all and ttf-liberation)

install yay
login as non-root
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si

install nice programs
  pacman -S arandr autorandr xbanish xss-lock network-manager-applet
  pacman -S resticprofile

install texlive,zathura,visual-studio-code

set correct keyboard layout in x11
	localectl set-x11-keymap de pc105 nodeadkeys

install nvidia
	!!! borks

  needed to set kernel parameters (in /boot/loader/entries/arch.conf)
    options ... nvidia-drm.modeset=1 nvidia_drm.fbdev=0
  use
    options ... debug loglevel=7
  to get more information

install
    pacman -S pulseaudio pavucontrol

install config files with sym links
    install st from my fork


TODO:
  systemd-resolved!
  wireguard
