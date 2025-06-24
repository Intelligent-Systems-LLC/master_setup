#!/usr/bin/env bash
#
# master_setup.sh author: Ygor Honesto
# git clone https://github.com/Intelligent-Systems-LLC/master_setup
# Usage: sudo ./master_setup.sh  ( defaults to the menu system )
# _______________________________
set -euo pipefail

# ─── Intelligent Systems CLI Banner ──────────────────────────────────────────

# Print the ASCII logo in red
echo -e "\e[37m"
cat << 'EOF'

 _____      _       _ _ _                  _   
|_   _|    | |     | | (_)                | |  
  | | _ __ | |_ ___| | |_  __ _  ___ _ __ | |_ 
  | || '_ \| __/ _ \ | | |/ _` |/ _ \ '_ \| __|
 _| || | | | ||  __/ | | | (_| |  __/ | | | |_ 
 \___/_| |_|\__\___|_|_|_|\__, |\___|_| |_|\__|
                           __/ |               
                          |___/                
 _____           _                             
/  ___|         | |                            
\ `--. _   _ ___| |_ ___ _ __ ___  ___         
 `--. \ | | / __| __/ _ \ '_ ` _ \/ __|        
/\__/ / |_| \__ \ ||  __/ | | | | \__ \        
\____/ \__, |___/\__\___|_| |_| |_|___/        
        __/ |                                  
       |___/                                   
                                                                                                                       
EOF

# Reset to default terminal colours
echo -e "\e[0m"

# Machine Information
user=$(id -un)
home=$(getent passwd "$user" | cut -d: -f6)
downloads="$home/Downloads"
documents="$home/Documents"
bin="$home/bin"

#VM Information
ha_version="15.2"
ha_name="homeassistant"
ha_url="https://github.com/home-assistant/operating-system/releases/download/$ha_version/haos_ova-$ha_version.vdi.zip"
ha_path=$documents
windows_name="windows"
windows_iso="$documents/26100.1742.240906-0331.ge_release_svc_refresh_CLIENTENTERPRISEEVAL_OEMRET_x64FRE_en-us.iso"
windows_url="https://go.microsoft.com/fwlink/?linkid=2289031&clcid=0x409&culture=en-us&country=us"
windows_path=$documents
vboxmanage="$(command -v VBoxManage || true)"


#Log Information

install_virtualbox() {
  echo "[+] Installing VirtualBox + Unzip + DKMS + headers"
  sudo apt update
  sudo apt install unzip
  sudo systemctl mask --now virtualbox.service || true
  sudo apt install -y virtualbox
  echo "[+] Adding $user to vboxusers"
  sudo usermod -aG vboxusers "$user"
  sudo apt install virtualbox-dkms linux-headers-$(uname -r)
  sudo apt install dkms
  echo "[+] Rebuilding kernel modules"
  sudo dpkg-reconfigure virtualbox-dkms
  echo "[+] Loading vboxdrv"
  sudo modprobe vboxdrv || echo "[!] modprobe vboxdrv failed (Secure Boot?)"
  ls -l /dev/vboxdrv
  echo "✔ Installed VirtualBox"
}

setup_homeassistant_vm() {
  echo "[+] Downloading Home Assistant OS"
  wget -q --show-progress -P "$documents" "$ha_url"
  unzip -q "$documents/haos_ova-$ha_version.vdi.zip" -d "$documents"
  rm -f "$documents/haos_ova-$ha_version.vdi.zip"

  echo "[+] Creating Home Assistant VM as $ha_name"
  #VM Creation Configuration
  VBoxManage createvm \
    --name "$ha_name" \
    --ostype Linux_64 \
    --register
  VBoxManage modifyvm $ha_name \
    --cpus 2 \
    --memory 12288 \
    --vram 16
  VBoxManage modifyvm $ha_name \
    --firmware efi \
    --audiocontroller hda
  VBoxManage storagectl $ha_name \
    --name "SATA Controller" \
    --add sata \
    --controller IntelAHCI
  VBoxManage storageattach $ha_name \
    --storagectl "SATA Controller" \
    --port 0 --device 0 \
    --type hdd \
    --medium $documents/haos_ova-$ha_version.vdi
  echo "✔ Created Home Assistant VM."
}

create_vmcontrol_units() {
  echo "[+] Deploying vm_control.sh"
  mkdir -p $bin
  cat > "$bin/vm_control.sh" << 'EOF'
#!/bin/bash

VM_NAME="homeassistant"
VBOXMANAGE="/usr/bin/VBoxManage"
LOGFILE="/var/log/vmcontrol/vm_control.log"

# Log header
echo "=== $(date +'%F %T') START vm_control.sh ==="

# Retrieve VM state
check_vm_state() {
  "$VBOXMANAGE" showvminfo "$VM_NAME" --machinereadable \
    | awk -F '"' '/^VMState=/ { print $2 }'
}

# Start headless if not running
ensure_vbox_headless() {
  if ! pgrep -x "VBoxHeadless" > /dev/null; then
    echo "Starting headless VirtualBox..."
    nohup VBoxHeadless --startvm "$VM_NAME" >/dev/null 2>&1 &
    sleep 5
  fi
}

main() {
  STATE=$(check_vm_state)
  case "$STATE" in
    running)
      echo "✔ VM '$VM_NAME' is already running." ;;
    paused)
      echo "⏸ VM is paused; resuming..."
      "$VBOXMANAGE" controlvm "$VM_NAME" resume ;;
    *)
      echo "▶ VM is $STATE; starting..."
      ensure_vbox_headless
      "$VBOXMANAGE" startvm "$VM_NAME" --type headless
      until [[ $(check_vm_state) == "running" ]]; do
        sleep 2
      done
      echo "✔ VM is now running."
      ;;
  esac
}

# Redirect all output to logfile
exec >>"$LOGFILE" 2>&1
main
EOF
  chmod +x $bin/vm_control.sh

  sudo mkdir -p /var/log/vmcontrol
  sudo chown "$user":vboxusers /var/log/vmcontrol
  sudo chmod 750 /var/log/vmcontrol
  sudo touch /var/log/vmcontrol/vm_control.log
  sudo chown $user:vboxusers /var/log/vmcontrol/vm_control.log
  sudo chmod 640 /var/log/vmcontrol/vm_control.log
  
  echo "✔ vm_control.sh deployed"

  echo "[+] Deploying vm_control.service"
  sudo tee /etc/systemd/system/vmcontrol.service > /dev/null << EOF
[Unit]
Description=Ensure VirtualBox VM '$ha_name' is running.
After=network-online.target vboxdrv.service
Wants=network-online.target vboxdrv.service

[Service]
Type=oneshot
User=$user
ExecStart=$bin/vm_control.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
  echo "[+] Deploying vm_control.service"
  sudo tee /etc/systemd/system/vmcontrol.timer > /dev/null << 'EOF'
[Unit]
Description=Re-check VM every 5 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Unit=vmcontrol.service

[Install]
WantedBy=timers.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable --now vmcontrol.service
  sudo systemctl enable --now vmcontrol.timer
  systemctl status vmcontrol.service
  systemctl status vmcontrol.timer
  journalctl -u vmcontrol.service --no-pager
  systemctl list-timers | grep vmcontrol
  echo "✔ vm_control.service deployed"
  echo "✔ vm_control.timer deployed"
}

setup_windows_vm() {
  echo "[+] Downloading Windows OS"
  wget -q --show-progress -P "$documents" "$windows_url"

  echo "[+] Creating Windows VM as $windows_name"
  #VM Creation Configuration
  windows_disk="$windows_path/${windows_name}.vdi"
  VBoxManage createmedium disk \
    --filename "$windows_disk" \
    --size 50000
  VBoxManage createvm \
    --name "$windows_name" \
    --ostype Windows11_64 \
    --register
  VBoxManage modifyvm $windows_name \
    --cpus 2 \
    --memory 4096 \
    --vram 16\
    --firmware efi
  VBoxManage storagectl $windows_name \
    --name "SATA Controller" \
    --add sata \
    --controller IntelAHCI
  VBoxManage storageattach $windows_name \
    --storagectl "SATA Controller" \
    --port 0 --device 0 \
    --type hdd \
    --medium $windows_disk
  VBoxManage storageattach "$windows_name" \
    --storagectl "SATA Controller" \
    --port 1 --device 0 \
    --type dvddrive \
    --medium "$windows_iso"
  echo "✔ Created Windows VM."
}

install_anydesk() {
  echo "[+] Installing Anydesk"
  # Add the AnyDesk GPG key
  sudo apt update
  sudo apt install ca-certificates curl apt-transport-https
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://keys.anydesk.com/repos/DEB-GPG-KEY -o /etc/apt/keyrings/keys.anydesk.com.asc
  sudo chmod a+r /etc/apt/keyrings/keys.anydesk.com.asc
  
  # Add the AnyDesk apt repository
  echo "deb [signed-by=/etc/apt/keyrings/keys.anydesk.com.asc] https://deb.anydesk.com all main" | sudo tee /etc/apt/sources.list.d/anydesk-stable.list > /dev/null
  
  # Update apt caches and install the AnyDesk client
  sudo apt update
  sudo apt install anydesk
  echo "✔ Install complete."
}

uninstall_all() {
  echo "[+] Uninstalling Home Assistant & Windows VMs"
  for vm in "$ha_name" "$windows_name"; do
    # attempt to power off, then unregister & delete
    runuser -l "$user" -c "\"$vboxmanage\" controlvm \"$vm\" poweroff" &>/dev/null || true
    runuser -l "$user" -c "\"$vboxmanage\" unregistervm \"$vm\" --delete" &>/dev/null || true
  done

  echo "[+] Disabling systemd timer & service"
  sudo systemctl disable --now vmcontrol.timer vmcontrol.service || true
  sudo rm -f /etc/systemd/system/vmcontrol.service /etc/systemd/system/vmcontrol.timer
  sudo systemctl daemon-reload

  echo "[+] Removing vm_control script"
  rm -f "$bin/vm_control.sh"
  rmdir --ignore-fail-on-non-empty "$bin" || true

  echo "[+] Removing log directory"
  sudo rm -rf /var/log/vmcontrol

  echo "[+] Cleaning up downloaded images"
  rm -f "$documents/haos_ova-$ha_version.vdi" "$windows_path"

  echo "[+] Purging VirtualBox and helpers"
  sudo apt remove --purge -y virtualbox virtualbox-dkms dkms "linux-headers-$(uname -r)" unzip

  echo "[+] Purging AnyDesk (if installed)"
  if dpkg -l anydesk &>/dev/null; then
    sudo apt remove --purge -y anydesk
    sudo rm -f /etc/apt/keyrings/keys.anydesk.com.asc \
              /etc/apt/sources.list.d/anydesk-stable.list
  fi

  echo "[+] Removing user from vboxusers group"
  sudo gpasswd -d "$user" vboxusers || true

  echo "✔ Uninstall complete."
}

### Main menu ###
PS3=$'\nChoose an option: '
options=("Full Configuration" "Home Assitant Only" "Windows Only" "AnyDesk Only" "Uninstall All" "Quit")
select opt in "${options[@]}"; do
  case $REPLY in
    1)
      install_virtualbox
      setup_homeassistant_vm
      create_vmcontrol_units
      setup_windows_vm
      install_anydesk
      break
      ;;
    2)
      install_virtualbox
      setup_homeassistant_vm
      create_vmcontrol_units
      break
      ;;
    3)
      setup_windows_vm
      break
      ;;
    4)
      install_anydesk
      break
      ;;
    5)
      uninstall_all
      break
      ;;
    6)
      exit 0
      ;;
    *)
      echo "Invalid choice."
      ;;
  esac
done
