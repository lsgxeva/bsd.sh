#!/bin/sh
#
# Copyright (c) 2008 Rene Maroufi, Stephan A. Rickauer
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
# REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
# INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
# LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
# OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.
#
# This script creates a cpio backup of modified files in /etc, /var and /root.

#
### Functions go first
#

sub_backup() {
   find /etc /var /root -newer /etc/timemark ! -type s ! -type p | cpio -o > /mnt/sys.cio
}

sub_check() {
    if [ -n "$(mount | grep '/mnt ')" ]
    then
        echo "Something is already mounted on /mnt!" >&2
        echo "Please umount /mnt first and then try again!" >&2
        exit 1
    fi
}

sub_umount() {
   echo -n "Attempting to unmount ${device} ... "
   umount /mnt \
       && echo done || echo failed
}

sub_bsdmount() {
    echo -n "Attempting to mount BSD partition ${device} ... "
    mount /dev/"${device}"a /mnt \
        && echo done || echo failed
}

sub_msdosmount() {
   echo -n "Attempting to mount MSDOS partition ${device} ... "
   mount_msdos /dev/"${device}"i /mnt \
       && echo done || echo failed
}

#
### Main
#

sub_check

echo "This program overwrites previously written backup data!"
echo -n "Storage device to write the backup data on (e.g. sd1)? "

read device

disklabel "${device}" 2>/dev/null | grep MSDOS | grep i: >/dev/null \
    && fs=msdos

disklabel "${device}" 2>/dev/null | grep 4.2BSD | grep a: >/dev/null \
    && fs=bsd

if [ "$fs" ]; then
    sub_$fs\mount
else
    echo "Can't find usable partition on device!" >&2
    exit 3
fi

sub_backup
sub_umount
