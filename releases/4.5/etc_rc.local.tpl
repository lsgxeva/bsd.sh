#	$OpenBSD: rc.local,v 1.39 2006/07/28 20:19:46 sturm Exp $

# Site-specific startup actions, daemons, and other things which
# can be done AFTER your system goes into securemode.  For actions
# which should be done BEFORE your system has gone into securemode
# please see /etc/rc.securelevel.

echo -n 'starting local daemons:'

# Add your local startup actions here.

echo '.'

# BSDanywhere should always run on low memory systems. However, if
# we find enough memory, we can offer some performance improvements.
sub_mfsmount() {

    # convert into mb due to ksh's 32 bit limit
    physmem=$(echo $(sysctl -n hw.physmem) / 1048576 | bc )

    if [ $physmem -gt 512 ]
    then
        echo -n "Preload free memory to speed up BSDanywhere? (N/y) "
        read doit
        if [ "$doit" == "y" ] || [ "$doit" == "Y" ] || [ "$doit" == "yes" ] || [ "$doit" == "Yes" ]
        then

            mount_mfs -s 300000 swap /mfs
            mkdir -p /mfs/usr/local/

            echo -n 'Memory preload:'
            for i in bin sbin; do
                echo -n " /$i";            /bin/cp -rp /$i /mfs/
                echo -n " /usr/$i";        /bin/cp -rp /usr/$i /mfs/usr/
                echo -n " /usr/local/$i";  /bin/cp -rp /usr/local/$i /mfs/usr/local/
            done
            echo .

            perl -pi -e 's#^(PATH=)(.*)#$1/mfs/bin:/mfs/sbin:/mfs/usr/bin:/mfs/usr/sbin:/mfs/usr/local/bin:/mfs/usr/local/sbin:$2#' /root/.profile
            perl -pi -e 's#^(PATH=)(.*)#$1/mfs/bin:/mfs/sbin:/mfs/usr/bin:/mfs/usr/sbin:/mfs/usr/local/bin:/mfs/usr/local/sbin:$2#' /home/live/.profile
        fi
    fi
}

# Ask for setting the time zone.
sub_timezone() {
   while :
   do
      echo -n "What timezone are you in? ('?' for list) "
      read zone
         if [ "${zone}" ]
         then
         if [ "${zone}" = "?" ]
         then
            ls -F /usr/share/zoneinfo
         fi
         if [ -d "/usr/share/zoneinfo/${zone}" ]
         then
            ls -F "/usr/share/zoneinfo/${zone}"
            echo -n "What sub-timezone of ${zone} are you in? "
            read subzone
            zone="${zone}/${subzone}"
         fi
         if [ -f "/usr/share/zoneinfo/${zone}" ]
         then
            echo -n "Setting local timezone to ${zone} ... "
            rm /etc/localtime
            ln -sf "/usr/share/zoneinfo/${zone}" /etc/localtime
            echo "done"
            return
         fi
      else
         echo "Leaving timezone unconfigured."
         return
      fi
   done
}

# Ask for setting the keyboard layout and pre-set the X11 layout, too.
sub_kblayout() {
    echo "Select keyboard layout *by number*:"
    select kbd in $(kbd -l | grep -v encoding | egrep '^[a-z]{2,2}.?[swapctrlcaps|declk|dvorak|iopener|nodead]*.?[dvorak|iopener]*$')
    do
       # validate input
       echo $kbd | egrep -q '^[a-z]{2,2}.?[swapctrlcaps|declk|dvorak|iopener|nodead]*.?[dvorak|iopener]*$'
       if [ "$?" = '0' ]; then

          # set console mapping
          /sbin/kbd "$kbd"
          echo "$kbd" > /etc/kbdtype
          break

       fi
    done
}

# Find all real network interfaces and offer to run dhclient/rtsol on
# each. Also offer to synchronize the time using a default ntpd.conf.
sub_networks() {
   echo -n "Auto configure the network? (Y/n) "
   read net
   if [ -z "$net" ] || [ "$net" = "y" ] || [ "$net" = "Y" ] || [ "$net" = "yes" ] || [ "$net" = "Yes" ]
   then
      for nic in $(ifconfig | awk -F: '/^[a-z]+[0-9]: flags=/ { print $1 }' | egrep -v "lo|enc|pflog")
      do
          echo -n "Configure $nic for dhcp? (Y/n) "
          read if
          if [ -z "$if" ] || [ "$if" = "y" ] || [ "$if" = "Y" ] || [ "$if" = "yes" ] || [ "$if" = "Yes" ]
          then
              ifconfig "$nic" up
              dhclient "$nic"
              rtsol "$nic"
              echo "dhcp NONE NONE NONE" > /etc/hostname.$nic
              echo "rtsol" >> /etc/hostname.$nic
          fi
      done

      echo -n "Synchronize time with default servers? (Y/n) "
      read ntp
      if [ -z "$ntp" ] || [ "$ntp" = "y" ] || [ "$ntp" = "Y" ] || [ "$ntp" = "yes" ] || [ "$ntp" = "Yes" ]
      then
          ntpd -s &
          echo "ntpd_flags=" >> /etc/rc.conf.local
      fi
   fi
}

# Always ask for the keyboard layout first, otherwise subsequent
# questions may have to be answered on an unset (=us) layout.
if [ ! -f /tmp/restore ]
then
    sub_kblayout
    sub_timezone
    sub_networks
fi
sub_mfsmount
