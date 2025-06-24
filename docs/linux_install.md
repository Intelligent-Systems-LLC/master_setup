# Installing Linux on Bare Metal
## 1. Prerequisites

- **Backup your data. [`If necessary`]** Installing Ubuntu will overwrite Windows and all files on the target drive so make sure anything important is safely backed up elsewhere.
- A USB flash drive with at least **4 GB** capacity.
- A PC with an internet connection.
- A separate machine (or Windows itself) to prepare the USB installer.

---

## 2. Download Ubuntu ISO

- Open your browser and go to the Ubuntu download page:
    - **Ubuntu Desktop**: https://ubuntu.com/download/desktop
- Click **“Download”** under the latest LTS (long-term support) release (recommended).
- Save the `.iso` file to a location you’ll remember (e.g. your **Downloads** folder).

---

## 3. Install balenaEtcher

- Go to https://etcher.balena.io/
- Click **“Download for Windows (x64)”** (or the appropriate installer for your OS).
- Run the downloaded installer and follow the prompts to install balenaEtcher.

---

## 4. Create the Bootable USB

- **Launch balenaEtcher.**
- Click **“Flash from file”** and navigate to the Ubuntu `.iso` you downloaded.
- Click **“Select target”**, then choose your USB flash drive from the list.
- Click **“Flash!”**
    - Etcher will write the ISO and then validate the flash.
    - **Do not** remove the USB drive until Etcher reports **“Flash Complete!”**

---

## 5. Configure Your PC to Boot from USB

- **Shut down** your PC with Windows still installed.
- Insert the newly-created Ubuntu USB.
- Power on the PC and immediately press the BIOS/UEFI entry key:
    - Common keys: **F2**, **F10**, **F12**, **Esc**, or **Del** (it varies by manufacturer; watch the on-screen prompt).
- In the BIOS/UEFI menu:
    - Navigate to **“Boot”** or **“Boot Order”** settings.
    - Move the **USB drive** to the top of the boot priority list.
    - If present, **disable Secure Boot** or set it to allow “Other OS” (Ubuntu supports Secure Boot, but some setups require it off). This is also important for virtualization, so if you inted to work with VMs make sure **Secure Boot** is disabled.
- Save changes (`often **F10**`) and exit—your PC will reboot.

---

## 6. Install Ubuntu

- When the PC restarts, it should boot into the Ubuntu live environment.
- Select **“Try or Install Ubuntu”** → **“Install Ubuntu”**.
- **Keyboard layout:** choose your layout and click **“Continue”**.
- **Updates & other software:**
    - Optionally click **“Download updates while installing”** and **“Install third-party software”**.
- **Installation type:**
    - Choose **“Erase disk and install Ubuntu”** to completely replace Windows.
    - **Warning:** this will delete all existing partitions.
    
    <aside>
      
    🚨 If you get stuck on a endless loading it might be that Ubuntu installer update that is prompted at the beginning is misconfiguring the installer, so you will need to restart the computer and run the installer without updating the installer. 
    
    </aside>
    
- Click **“Install Now”**, then **“Continue”** to confirm.
- **Timezone:** select your region and city, then **“Continue”**.
- **User details:**
    - Enter your name, PC name, username, and a strong password.
    - Choose whether to log in automatically or require a password.
- The installer will copy files—this can take 10–20 minutes.

---

## 7. Final Steps & Reboot

- When prompted, click **“Restart Now”**.
- Remove the USB flash drive when asked, then press **Enter**.
- Your PC will boot into your new Ubuntu installation.

---

## 8. Post-Installation Tips

- **Update your system:**
    
    ```bash
    sudo apt update && sudo apt upgrade -y
    ```
    
- **Install additional drivers** (Graphics, Wi-Fi, etc.):
    - Open **“Software & Updates”** → **“Additional Drivers”** tab → apply recommended drivers.
- **Set up backups:** use Ubuntu’s **“Backups”** tool or another solution to safeguard your data.

---
