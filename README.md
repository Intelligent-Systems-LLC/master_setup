# Master Setup

[master_setup.sh](master_setup.sh) is a one-stop installer & manager for VirtualBox, Home Assistant OS, and Windows VMs on Ubuntu/Debian.
1. Installs VirtualBox (with required kernel modules)
2. Creates/configures a Home Assistant VM (with automatic “watchdog” with systemctl).
3. Optionally installs AnyDesk.
4. Optionally creates a Windows VM.
5. Can uninstall everything cleanly.

---

## 📋 Prerequisites

1. Ubuntu or Debian-based Linux 
2. A user account with `sudo` privileges  
3. ≥ 12 GB free RAM  
4. ≥ 60 GB free disk space  
5. Internet access (for downloads)

> If you haven't installed linux on your machine please follow the guide for [installing linux on bare metal.](docs/linux_install.md)

---

## ⚙️ Installation & Usage

1. **Clone or download** this repo and `cd` into its folder.  
2. Make the script executable:
    ```
    chmod +x master_setup.sh
    ```
3. Run it:
    ```
    ./master_setup.sh
    ```
5. You’ll see a menu:
   
| Option              | What it does                                                                                        |
| ------------------- | --------------------------------------------------------------------------------------------------- |
| **1) Full Config**   | Install VirtualBox → create HA VM → deploy watchdog service & timer.                                |
| **2) HA Only**       | Same as Full Config, but skips Windows VM creation and Anydesk install.                             |
| **3) AnyDesk Only**  | *(Not implemented)* Would install AnyDesk only.                                                     |
| **4) Windows Only**  | Download Windows ISO & build a 50 GB Windows 11 VM.                                                 |
| **5) Uninstall All** | Stop/delete both VMs, disable/remove services & timer, uninstall VirtualBox & AnyDesk, clean files. |
| **6) Quit**          | Exit without changes.                                                                               |
