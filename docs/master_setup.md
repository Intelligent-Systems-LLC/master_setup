# Master Setup
## VirtualBox Install

This guide walks you through installing VirtualBox, configuring a script to auto-start and monitor a VM named `homeassistant`, and setting up `systemd` service and `timer units` with logging for troubleshooting.

<aside>

⚠️ If you haven’t installed Ubuntu on the machine yet, please follow the guide [Installing Ubuntu OS on Bare Metal](/docs/linux_install.md).

</aside>

---

### Prerequisites

- Ubuntu system with internet access
- `sudo` privileges
- Target VM exists in VirtualBox with name `homeassistant`
---

### 1. Install VirtualBox

```bash
sudo apt update
sudo apt install -y virtualbox
```

Verify installation:

```bash
which VBoxManage         # should return /usr/bin/VBoxManage
VBoxManage --version     # prints version
```

---

### 2. Add `iseadmin` to `vboxusers` group

```bash
sudo usermod -aG vboxusers $(id -un)
```

> Note: New group membership applies after logout/login or reboot. To verify immediately, use:
> 
> 
> ```bash
> su - $(id -un)
> id $(id -un)
> ```
> 

## Install Kernel Modules

- VirtualBox requires kernel modules (`vboxdrv`, `vboxnetflt`, etc.) to function.
- These modules are built using **DKMS** (Dynamic Kernel Module Support) during installation.
- If you’re missing the **`virtualbox-dkms`** package or **kernel headers**, the kernel module can’t be built → `/dev/vboxdrv` won't exist → VMs can't start.

---

### 1. **Install Required Packages**

Run this to install the DKMS module and the kernel headers for your running kernel:

```bash
sudo apt install virtualbox-dkms linux-headers-$(uname -r)
```

Also, ensure `dkms` itself is installed:

```bash
sudo apt install dkms
```

### 2. **Rebuild VirtualBox Kernel Modules**

After installing those, rebuild the modules:

```bash
sudo dpkg-reconfigure virtualbox-dkms
```

Then:

```bash
sudo modprobe vboxdrv
```

Check the device:

```bash
ls -l /dev/vboxdrv
```

You should see something like:

```
crw------- 1 root root 10, 59 Jun 16 15:22 /dev/vboxdrv
```

### 📌 Optional: **Restart VirtualBox and Try Your Script Again**

If you were troubleshooting, and went trough the steps of creting homeassistant vm already you can now retry starting your VM manually first:

```bash
VBoxManage startvm "homeassistant" --type headless
```

If that works, your `vm_control.sh` and systemd service should be fine after a reboot.

---

### 📌 Optional: Check Kernel Version Mismatch

Sometimes `linux-headers-generic` and your actual kernel (`uname -r`) can mismatch (e.g., if you just updated the kernel and haven't rebooted). Make sure you're using the latest kernel or reboot your system if needed.

---

### 🚀 Bonus: Prevent on-boot Race Conditions

Since VirtualBox modules may not be loaded immediately during early boot, your `vmcontrol.timer` might be firing too early.

Consider modifying your systemd unit to **wait for the modules**, by adding this line:

```
After=network-online.target vboxdrv.service
Wants=network-online.target
```

And delay the timer slightly or add a pre-check in your script for `/dev/vboxdrv`.

---

<aside>
📌

## Installing Home Assistant OS and Creating VM

### Prerequisites

- Ubuntu system with internet access
- `sudo` privileges

---

1. **Install VirtualBox & unzip**:
    
    ```bash
    sudo apt-get update
    sudo apt-get -y install unzip
    ```
    
    VirtualBox is required for VM creation; `unzip` extracts the downloaded OS image
    

---

### Download and Prepare Home Assistant OS

1. **Fetch the Home Assistant OS image**:
    
    ```bash
    cd $HOME/Downloads
    wget https://github.com/home-assistant/operating-system/releases/download/15.2/haos_ova-15.2.vdi.zip
    ```
    
    This is the VirtualBox-compatible VDI ZIP for version 15.2.
    
2. **Unpack & clean up**:
    
    ```bash
    unzip haos_ova-15.2.vdi.zip
    rm haos_ova-15.2.vdi.zip
    ```
    
3. **Move the VDI into Documents**:
    
    ```bash
    mv haos_ova-15.2.vdi $HOME/Downloads
    ```
    

---

## Create and Configure the Virtual Machine

### 1. Create the VM definition

```bash
VBoxManage createvm \
  --name homeassistant \
  --ostype Linux_64 \
  --register
```

`createvm` initializes the VM’s XML definition and registers it.
### 2. Allocate CPU & Memory

```bash
VBoxManage modifyvm homeassistant \
  --cpus 2 \
  --memory 12288 \
  --vram 16
```

Sets 2 vCPUs, 12 GB RAM (12288 MB), and 16 MB video RAM.

### 3. Enable UEFI & Audio

```bash
VBoxManage modifyvm homeassistant \
  --firmware efi \
  --audiocontroller hda
```

Turns on EFI boot and Intel HD Audio.

---

## Storage Configuration

1. **Add a SATA controller**:
    
    ```bash
    VBoxManage storagectl homeassistant \
      --name "SATA Controller" \
      --add sata \
      --controller IntelAHCI
    ```
    
    Creates a SATA bus for disk attachment.
    
2. **Attach the Home Assistant VDI**:
    
    ```bash
    VBoxManage storageattach homeassistant \
      --storagectl "SATA Controller" \
      --port 0 --device 0 \
      --type hdd \
      --medium ~/Documents/haos_ova-15.2.vdi
    ```
    
    Links your OS disk to the VM.
    

---

## Network Configuration

1. **Identify your host’s network interface**:
    
    ```bash
    ip a
    ```
    
    Note the adapter name (e.g., `enp3s0`).
    
2. **Enable bridged networking**:
    
    ```bash
    VBoxManage modifyvm homeassistant \
      --nic1 bridged \
      --bridgeadapter1 enp3s0 \
      --nictype1 82540EM
    ```
    
    Switches VM to bridged mode so it receives an IP from your LAN.
    
</aside>

### 3. Create the VM-control script

1. Create `bin` directory:
    
    ```bash
    mkdir -p $HOME/bin
    ```
    
2. Edit the script:
    
    ```bash
    nano $HOME/bin/vm_control.sh
    ```
    
3. Paste the following:
    
    ```bash
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
    ```
    
4. Save and exit (`Ctrl+X`, `Y`).
5. Make it executable:
    
    ```bash
    chmod +x $HOME/bin/vm_control.sh
    ```
    

---

### 4. Setup Logging

1. Create log directory and file:
    
    ```bash
    sudo mkdir -p /var/log/vmcontrol
    sudo touch /var/log/vmcontrol/vm_control.log
    sudo chown $(id -un):vboxusers /var/log/vmcontrol/vm_control.log
    sudo chmod 640 /var/log/vmcontrol/vm_control.log
    ```
    
2. Already handled in the script via `exec >>"$LOGFILE" 2>&1`.)

---

### 5. Create systemd Service

1. Create unit file:
    
    ```bash
    sudo nano /etc/systemd/system/vmcontrol.service
    ```
    
2. Paste the information below on `vmcontrol.service`:
    
    ```
    [Unit]
    Description=Ensure VirtualBox VM 'homeassistant' is running for %i
    After=network-online.target vboxdrv.service
    Wants=network-online.target vboxdrv.service
    
    [Service]
    Type=oneshot
    User=%i
    ExecStart=/home/%i/bin/vm_control.sh
    RemainAfterExit=yes
    
    [Install]
    WantedBy=multi-user.target
    ```
> If you want to later use simpler systemctl commands you will need to change values `%i` to your `username`, which can be found by running the command `id -un`.

3. Save and exit.

---

### 6. Create `systemd` Timer

1. Create timer file:
    
    ```bash
    sudo nano /etc/systemd/system/vmcontrol.timer
    ```
    
2. Paste the information below on `vmcontrol.timer`:
    
    ```
    [Unit]
    Description=Re-check VM every 5 minutes
    
    [Timer]
    OnBootSec=2min #Will wait 2 minutes after boot to load VirtuaBox Modules.
    OnUnitActiveSec=5min #Will wait 5 minutes from last run and repeat process.
    Unit=vmcontrol.service
    
    [Install]
    WantedBy=timers.target
    ```
    
    - `vmcontrol.timer`  the timer file is currently set to verify VMware every 5 minutes, please change if necessary.
3. Save and exit.

---

### 7. Enable & Start Services

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now vmcontrol@$(id -un).service
sudo systemctl enable --now vmcontrol@$(id -un).timer
```
If you changed %i parameter:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now vmcontrol.service
sudo systemctl enable --now vmcontrol.timer
```

Check status:

```bash
systemctl status vmcontrol@$(id -un).service
systemctl list-timers | grep vmcontrol@
```

If you changed %i parameter:
```bash
systemctl status vmcontrol.service
systemctl list-timers | grep vmcontrol
```
---

### 8. Verify & Troubleshoot

- **View logs:**
    
    ```bash
    tail -f /var/log/vmcontrol/vm_control.log
    ```
    
- **Check journal:**
    
    ```bash
    journalctl -u vmcontrol@$(id -un).service --no-pager
    ```
    If you changed %i parameters:
    ```bash
    journalctl -u vmcontrol.service --no-pager
    ```    

Now your `homeassistant` VM will auto-start at boot and be re-checked every 5 minutes (if timer enabled), with logs recorded for troubleshooting.

---

# AnyDesk Install and Configuration

This step‑by‑step guide shows you how to configure your Ubuntu to always use an X11 (Xorg) session—ensuring full AnyDesk compatibility.

---

## Prerequisites

- Ubuntu 20.04 or later with GDM3 as the display manager
- Use of X11 Configuration on Ubuntu OS
- Administrative `sudo` privileges

> Note: Switching to X11 has no impact on OS functionality but some software are made primarily for X11 and won’t have all features when using Wayland configuration.

---

## 1. Install AnyDesk

<aside>

🚨 AnyDesk will need Ubuntu graphics to be set to Xorg11 instead of Wayland which is currently the default, this is true because some features were made specific to work with Xorg11 [The graphic changes will not interfere with other softwares commonly used].

</aside>

1. **Install prerequisite packages**:
    
    ```bash
    sudo apt update
    sudo apt install -y ca-certificates curl apt-transport-https
    ```
    
2. **Download and add the AnyDesk GPG key**:
    
    ```bash
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://keys.anydesk.com/repos/DEB-GPG-KEY \
      | sudo tee /etc/apt/keyrings/keys.anydesk.com.asc > /dev/null
    sudo chmod a+r /etc/apt/keyrings/keys.anydesk.com.asc
    ```
    
3. **Add the AnyDesk repository**:
    
    ```bash
    echo "deb [signed-by=/etc/apt/keyrings/keys.anydesk.com.asc] https://deb.anydesk.com all main" \
      | sudo tee /etc/apt/sources.list.d/anydesk-stable.list > /dev/null
    ```
    
4. **Update package lists and install AnyDesk**:
    
    ```bash
    sudo apt update
    sudo apt install -y anydesk
    ```
    

---

## 2. Simulate a Connected Display (Headless Servers)

If your server has no physical monitor attached, ensure the display server initializes properly by:

1. **Connecting a monitor.**
2. **Using a Dummy HDMI adapter** (a headless display dongle).
---

## 3. Disable Wayland System-Wide

1. **Open the GDM configuration**:
    
    ```bash
    sudo nano /etc/gdm3/custom.conf
    ```
    
2. **Uncomment** the `WaylandEnable` line:
    
    ```
    WaylandEnable=false
    ```
    
    This forces GDM to use Xorg.
    
3. **Save and exit** (`Ctrl+O`, `Enter`, `Ctrl+X`).
4. **Restart GDM** to apply:
    
    ```bash
    sudo systemctl restart gdm3
    ```
    
    > You will be logged out. Save any work before running this.

---

## 4. Verify X11 Session

After logging in, open a terminal and run:

```bash
echo $XDG_SESSION_TYPE
```

- Output `x11` = ✓
- Output `wayland` = ✗

---

## 5. Configure AnyDesk for Unattended Access

You can enable unattended access and set a password via GUI or CLI:

### GUI Method

1. Launch AnyDesk on Ubuntu.
2. Go to **Settings > Security > Unattended Access**.
3. Enable **"Allow unattended access"** and set a strong password.

### CLI Method

1. **Set the unattended-access password** (run as `root` or with `sudo`):
    - Interactive:
        
        ```bash
        echo "MyStrongPassword" | sudo anydesk --set-password
        ```
        
    - Non-interactive:
        
        ```bash
        printf "MyStrongPassword\n" | sudo anydesk --set-password
        ```
    
2. **Confirm the password is saved** (inspect):
    
    ```bash
    grep -R "password" /home/$USER/.anydesk
    ```
    or retry a connection.
    
> Tip: The CLI command automatically enables unattended access when setting a password. (reddit.com)

---

## 6. Allow Root (Optional)

If you need to run AnyDesk as root or in scripts:

1. As your normal user, grant X access:
    
    ```bash
    xhost +SI:localuser:root
    ```
    
2. Run AnyDesk with sudo:
    
    ```bash
    sudo anydesk
    ```
    
> Security: Avoid xhost + (opens X to all users). (askubuntu.com)

---

## 7. Firewall Configuration (If necessary)

Ensure AnyDesk traffic is allowed through UFW:

```bash
sudo ufw allow anydesk
```

If using a custom port (default TCP 7070), allow it explicitly:

```bash
sudo ufw allow 7070/tcp
```

---

## 8. Testing Your Remote Session

1. From your Windows (or other) machine, open the AnyDesk client.
2. Enter the Ubuntu host’s AnyDesk address.
3. Connect using the unattended-access password.
4. You should see the Ubuntu desktop without errors.

---
