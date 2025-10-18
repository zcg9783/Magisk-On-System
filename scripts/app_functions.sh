##################################
# Magisk app internal scripts
##################################

# $1 = delay
# $2 = command
run_delay() {
  (sleep $1; $2)&
}

# $1 = version string
# $2 = version code
env_check() {
  for file in busybox magiskboot magiskinit util_functions.sh boot_patch.sh; do
    [ -f "$MAGISKBIN/$file" ] || return 1
  done
  if [ "$2" -ge 25000 ]; then
    [ -f "$MAGISKBIN/magiskpolicy" ] || return 1
  fi
  #if [ "$2" -ge 25210 ]; then
    #[ -b "$MAGISKTMP/.magisk/device/preinit" ] || [ -b "$MAGISKTMP/.magisk/block/preinit" ] || return 2
  #fi
  grep -xqF "MAGISK_VER='$1'" "$MAGISKBIN/util_functions.sh" || return 3
  grep -xqF "MAGISK_VER_CODE=$2" "$MAGISKBIN/util_functions.sh" || return 3
  return 0
}

# $1 = dir to copy
# $2 = destination (optional)
cp_readlink() {
  if [ -z $2 ]; then
    cd $1
  else
    cp -af $1/. $2
    cd $2
  fi
  for file in *; do
    if [ -L $file ]; then
      local full=$(readlink -f $file)
      rm $file
      cp -af $full $file
    fi
  done
  chmod -R 755 .
  cd /
}

# $1 = install dir
fix_env() {
  # Cleanup and make dirs
  rm -rf $MAGISKBIN/*
  mkdir -p $MAGISKBIN 2>/dev/null
  chmod 700 /data/adb
  cp_readlink $1 $MAGISKBIN
  rm -rf $1
  chown -R 0:0 $MAGISKBIN
}

# $1 = install dir
# $2 = boot partition
direct_install() {
#  echo "- Flashing new boot image"
#  flash_image $1/new-boot.img $2
#  case $? in
#    1)
#      echo "! Insufficient partition size"
#      return 1
#      ;;
#    2)
#      echo "! $2 is read only"
#      return 2
#      ;;
#  esac
#
#  rm -f $1/new-boot.img
#  fix_env $1
#  run_migrations
#
  return 0
}

# $1 = mount mode
mount_system() {
  local slot="$(getprop ro.boot.slot_suffix)"

  mount -o "${1},remount" / 2>/dev/null
  mount -o "${1},remount" /system 2>/dev/null

  for block in "/dev/block/by-name/system" "/dev/block/mapper/system${slot}"; do
    if [ -b "$block" ] || [ -L "$block" ]; then
      blockdev --set${1} "$block" 2>/dev/null
      mount -o "remount,${1}" "$block" /system 2>/dev/null
      break
    fi
  done
  return 0
}

run_installer() {
  # Default permissions
  umask 022

  [ "$(id -u)" = "0" ] || exit 1

  if mount | grep -q 'rootfs' || [ -e /sbin ]; then
    export MAGISKTMP=/sbin
  else
    export MAGISKTMP=/debug_ramdisk
  fi

  local files_dir_sys=/system/etc/magisk

  ui_print "- Extracting Magisk files"
  mount_system rw

  rm -rf "$files_dir_sys"
  mkdir -p "${files_dir_sys}/chromeos/"

  ls magisk* *.sh init-ld busybox stub.apk | while read file; do
    cp -f "./${file}" "${files_dir_sys}/${file}"

    if [ ! -f "${files_dir_sys}/${file}" ]; then
      restore_system
      abort "! Unable to write system partition"
    fi
  done

  cp -r ./chromeos/* "${files_dir_sys}/chromeos/"

  set_perm_recursive "$files_dir_sys" 0 0 0750 0750

  rm -rf "$(pwd)"

  cat << 'END' > /system/etc/setup-magisk.sh
#!/system/bin/sh
# Magisk On System
# Core: Setup Magisk tmpfs script

# Default permissions
umask 022

exec > /dev/null 2>&1

files_dir_sys=/system/etc/magisk
mods=/data/adb/modules

# Load utility functions
BOOTMODE=true
. "${files_dir_sys}/util_functions.sh"

mount_tmpfs() {
  mv magisk magisk.tmp
  mount -t tmpfs -o 'mode=0755' magisk "$@"
  mv magisk.tmp magisk
}

mount_sbin() {
  mount_tmpfs /sbin
  chcon u:object_r:rootfs:s0 /sbin
}

[ -n "$(magisk -v)" ] && exit 1

cd /

rm -rf "$MAGISKBIN"
mkdir -p "$MAGISKBIN"

cp -r "$files_dir_sys"/* "$MAGISKBIN"

chmod 755 -R "$MAGISKBIN"
chown 0:0 -R "$MAGISKBIN"

# Setup bin overlay
# from live_setup.sh
if mount | grep -q rootfs; then
  # Legacy rootfs
  MAGISKTMP=/sbin

  mount -o rw,remount /
  rm -rf /root
  mkdir /root /sbin 2>/dev/null
  chmod 750 /root
  ln /sbin/* /root

  mount -o ro,remount /
  mount_sbin
  ln -s /root/* /sbin
elif [ -e /sbin ]; then
  # Legacy SAR
  MAGISKTMP=/sbin
  mount_sbin

  block="$(mount | grep ' / ' | awk '{ print $1 }')"
  [ "$block" = "/dev/root" ] && block=/dev/block/vda1
  mkdir -p /dev/sysroot
  mount -o ro "$block" /dev/sysroot

  for file in /dev/sysroot/sbin/*; do
    [ ! -e "$file" ] && break

    if [ -L "$file" ]; then
      cp -af "$file" /sbin
    else
      file_sbin="/sbin/$(basename "$file")"

      touch "$file_sbin"
      mount -o bind "$file" "$file_sbin"
    fi
  done

  umount -l /dev/sysroot
  rm -rf /dev/sysroot
else
  # Android Q+ without sbin
  MAGISKTMP=/debug_ramdisk
  mount_tmpfs /debug_ramdisk
fi

if [ ! -L /cache ] && ! mount | grep -q ' /cache '; then
  mount -t tmpfs -o 'mode=0755' tmpfs /cache
fi

# Magisk stuffs
for dir in "device" "worker"; do
  mkdir -p "${MAGISKTMP}/.magisk/${dir}/"
done

mount_tmpfs "${MAGISKTMP}/.magisk/worker/"
mount --make-private "${MAGISKTMP}/.magisk/worker/"

cd "$files_dir_sys"

touch "${MAGISKTMP}/.magisk/.config"

for file in "magisk" "magisk32" "magiskpolicy" "stub.apk"; do
  cp "./${file}" "${MAGISKTMP}/${file}"
  set_perm "${MAGISKTMP}/${file}" 0 0 0755
done

cd "$MAGISKTMP"
ln -s magisk resetprop
ln -s magiskpolicy supolicy
ln -s magisk su

cd /

# SELinux stuffs
if [ -d /sys/fs/selinux/ ]; then
  apply_cmd="--live --magisk"

  if [ ! -e /sys/fs/selinux/policy ]; then
    for sepolicy_file in /sepolicy /sepolicy_debug /sepolicy.unlocked /system/etc/selinux/precompiled_sepolicy /vendor/etc/selinux/precompiled_sepolicy /odm/etc/selinux/precompiled_sepolicy; do
      [ -f "$sepolicy_file" ] || continue
      apply_cmd="--load ${sepolicy_file} ${apply_cmd}"
      break
    done
  fi

  ls "$mods" | while read modid; do
    modpath="${mods}_update/${modid}"
    [ -d "$modpath" ] || modpath="${mods}/${modid}"

    [ -f "${modpath}/disable" ] && continue
    [ -f "${modpath}/remove" ] && continue
    [ -f "${modpath}/sepolicy.rule" ] || continue

    apply_cmd="${apply_cmd} --apply ${modpath}/sepolicy.rule"
  done

  "${MAGISKTMP}/magiskpolicy" ${apply_cmd}
fi

exit 0
END

  set_perm /system/etc/setup-magisk.sh 0 0 0750

  local exec_sectx="$(id -Z)"
  [ -z "$exec_sectx" ] && local exec_sectx="u:r:init:s0"

  cat << END > /system/etc/init/magisk.rc
on post-fs-data
    exec ${exec_sectx} 0 0 -- ${files_dir_sys}/busybox sh -o standalone /system/etc/setup-magisk.sh
    exec u:r:magisk:s0 0 0 -- ${MAGISKTMP}/magisk --post-fs-data

on property:vold.decrypt=trigger_restart_framework
    exec u:r:magisk:s0 0 0 -- ${MAGISKTMP}/magisk --service

on nonencrypted
    exec u:r:magisk:s0 0 0 -- ${MAGISKTMP}/magisk --service

on property:sys.boot_completed=1
    exec u:r:magisk:s0 0 0 -- ${MAGISKTMP}/magisk --boot-complete

on property:init.svc.zygote=stopped
    exec u:r:magisk:s0 0 0 -- ${MAGISKTMP}/magisk --zygote-restart
END

  set_perm /system/etc/init/magisk.rc 0 0 0644

  mount_system ro

  if [ -n "$(magisk -v >&2)" ]; then
    ui_print "! Magisk daemon is running"
    ui_print "- Welcome to Magisk On System"
    return 0
  fi

  ui_print "- Launch Magisk daemon"
  cd /
  sh /system/etc/setup-magisk.sh

  for trigger in "post-fs-data" "service" "boot-complete"; do
    sleep 0.5s
    "${MAGISKTMP}/magisk" --${trigger} >&2
  done

  sleep 0.5s
  echo $(magisk -v)
  ui_print "- Welcome to Magisk On System"
  return 0
}

run_uninstaller() {
  # Default permissions
  umask 022

  if echo ${MAGISK_VER} | grep -q '\.'; then
    local PRETTY_VER=${MAGISK_VER}
  else
    local PRETTY_VER="${MAGISK_VER}(${MAGISK_VER_CODE})"
  fi
  print_title "Magisk ${PRETTY_VER} Uninstaller"

  ui_print "- Removing modules"
  magisk --remove-modules -n

  ui_print "- Removing Magisk files"
  rm -rf \
  /cache/*magisk* /cache/unblock /data/*magisk* /data/cache/*magisk* /data/property/*magisk* \
  /data/Magisk.apk /data/busybox /data/custom_ramdisk_patch.sh /data/adb/*magisk* \
  /data/adb/post-fs-data.d /data/adb/service.d /data/adb/modules* \
  /data/unencrypted/magisk /metadata/magisk /metadata/watchdog/magisk /persist/magisk /mnt/vendor/persist/magisk

  ui_print "- Restoring system partition"
  restore_system
 
  if [ -d /system/etc/magisk/ ]; then
    abort "! Unable to restore system partition"
  fi

  return 0
}

restore_system() {
  mount_system rw

  rm -rf \
  /system/etc/magisk/ \
  /system/etc/init/magisk.rc \
  /system/etc/setup-magisk.sh

  mount_system ro
  return 0
}

# $1 = uninstaller zip
#run_uninstaller() {
#  rm -rf /dev/tmp
#  mkdir -p /dev/tmp/install
#  unzip -o "$1" "assets/*" "lib/*" -d /dev/tmp/install
#  INSTALLER=/dev/tmp/install sh /dev/tmp/install/assets/uninstaller.sh dummy 1 "$1"
#}

# $1 = boot partition
restore_imgs() {
#  local SHA1=$(grep_prop SHA1 $MAGISKTMP/.magisk/config)
#  local BACKUPDIR=/data/magisk_backup_$SHA1
#  [ -d $BACKUPDIR ] || return 1
#  [ -f $BACKUPDIR/boot.img.gz ] || return 1
#  flash_image $BACKUPDIR/boot.img.gz $1
  restore_system
}

# $1 = path to bootctl executable
post_ota() {
#  cd /data/adb
#  cp -f $1 bootctl
#  rm -f $1
#  chmod 755 bootctl
#  if ! ./bootctl hal-info; then
#    rm -f bootctl
#    return
#  fi
#  SLOT_NUM=0
#  [ $(./bootctl get-current-slot) -eq 0 ] && SLOT_NUM=1
#  ./bootctl set-active-boot-slot $SLOT_NUM
#  cat << EOF > post-fs-data.d/post_ota.sh
#/data/adb/bootctl mark-boot-successful
#rm -f /data/adb/bootctl
#rm -f /data/adb/post-fs-data.d/post_ota.sh
#EOF
#  chmod 755 post-fs-data.d/post_ota.sh
#  cd /
  return 0
}

# $1 = APK
# $2 = package name
adb_pm_install() {
  local tmp=/data/local/tmp/temp.apk
  cp -f "$1" $tmp
  chmod 644 $tmp
  su 2000 -c pm install -g $tmp || pm install -g $tmp || su 1000 -c pm install -g $tmp
  local res=$?
  rm -f $tmp
  if [ $res = 0 ]; then
    appops set "$2" REQUEST_INSTALL_PACKAGES allow
  fi
  return $res
}

check_boot_ramdisk() {
  # Create boolean ISAB
  #ISAB=true
  #[ -z $SLOT ] && ISAB=false
  ISAB=false

  # If we are A/B, then we must have ramdisk
  $ISAB && return 0

  # If we are using legacy SAR, but not A/B, assume we do not have ramdisk
  if $LEGACYSAR; then
    # Override recovery mode to true
    #RECOVERYMODE=true

    # Override system mode to true
    SYSTEMMODE=true
    return 1
  fi

  return 0
}

check_encryption() {
  if $ISENCRYPTED; then
    if [ $SDK_INT -lt 24 ]; then
      CRYPTOTYPE="block"
    else
      # First see what the system tells us
      CRYPTOTYPE=$(getprop ro.crypto.type)
      if [ -z $CRYPTOTYPE ]; then
        # If not mounting through device mapper, we are FBE
        if grep ' /data ' /proc/mounts | grep -qv 'dm-'; then
          CRYPTOTYPE="file"
        else
          # We are either FDE or metadata encryption (which is also FBE)
          CRYPTOTYPE="block"
          grep -q ' /metadata ' /proc/mounts && CRYPTOTYPE="file"
        fi
      fi
    fi
  else
    CRYPTOTYPE="N/A"
  fi
}

printvar() {
  eval echo $1=\$$1
}

run_action() {
  local MODID="$1"
  cd "/data/adb/modules/$MODID"
  sh ./action.sh
  local RES=$?
  cd /
  return $RES
}

##########################
# Non-root util_functions
##########################

mount_partitions() {
  [ "$(getprop ro.build.ab_update)" = "true" ] && SLOT=$(getprop ro.boot.slot_suffix)
  # Check whether non rootfs root dir exists
  SYSTEM_AS_ROOT=false
  grep ' / ' /proc/mounts | grep -qv 'rootfs' && SYSTEM_AS_ROOT=true

  LEGACYSAR=false
  grep ' / ' /proc/mounts | grep -q '/dev/root' && LEGACYSAR=true
}

get_flags() {
  KEEPVERITY=$SYSTEM_AS_ROOT
  ISENCRYPTED=false
  [ "$(getprop ro.crypto.state)" = "encrypted" ] && ISENCRYPTED=true
  KEEPFORCEENCRYPT=$ISENCRYPTED
  if [ -n "$(getprop ro.boot.vbmeta.device)" -o -n "$(getprop ro.boot.vbmeta.size)" ]; then
    PATCHVBMETAFLAG=false
  elif getprop ro.product.ab_ota_partitions | grep -wq vbmeta; then
    PATCHVBMETAFLAG=false
  else
    PATCHVBMETAFLAG=true
  fi
  #[ -z $RECOVERYMODE ] && RECOVERYMODE=false
  [ -z $SYSTEMMODE ] && SYSTEMMODE=false
  [ -z $VENDORBOOT ] && VENDORBOOT=false
}

run_migrations() { return; }

grep_prop() { return; }

#############
# Initialize
#############

app_init() {
  mount_partitions >/dev/null
  RAMDISKEXIST=false
  check_boot_ramdisk && RAMDISKEXIST=true
  get_flags >/dev/null
  run_migrations >/dev/null
  check_encryption

  # Dump variables
  printvar SLOT
  printvar SYSTEM_AS_ROOT
  printvar RAMDISKEXIST
  printvar ISAB
  printvar CRYPTOTYPE
  printvar PATCHVBMETAFLAG
  printvar LEGACYSAR
  #printvar RECOVERYMODE
  printvar SYSTEMMODE
  printvar KEEPVERITY
  printvar KEEPFORCEENCRYPT
  printvar VENDORBOOT
}

export BOOTMODE=true
