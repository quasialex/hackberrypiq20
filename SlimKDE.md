# SlimKDE (Ultra-Slim, Touch + Battery) — Hackberry CM5 / Kali

> Target: **Kali (arm64) on NVMe**, KDE **Wayland**, gestures via **KWin**, **MAX17048** battery, cool/quiet, fast boot.

---

## 0) Fresh base + users

Update the system:

```bash
sudo apt update && sudo apt full-upgrade -y
```

Create your user if needed (example: `alex`) and mirror groups from `kali`:

```bash
# If alex already exists, just mirror groups:
sudo usermod -aG $(id -nG kali | tr ' ' ',') alex
```

Passwordless sudo:

```bash
echo 'alex ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/010_alex-nopasswd
sudo chmod 0440 /etc/sudoers.d/010_alex-nopasswd
```

---

## 1) Minimal KDE (Wayland) + SDDM autologin

Install a slim Plasma:

```bash
sudo apt install -y \
  plasma-desktop plasma-workspace-wayland sddm \
  kde-cli-tools kde-config-gtk-style kdeplasma-addons \
  powerdevil upower qt6-base-bin \
  blueman polkit-kde-agent-1
```

Set **SDDM** as display manager & enable autologin into **Wayland**:

```bash
sudo systemctl disable --now lightdm 2>/dev/null || true
sudo systemctl enable --now sddm

sudo tee /etc/sddm.conf >/dev/null <<'EOF'
[Autologin]
User=alex
Session=plasmawayland
EOF
```

(Replace `alex` if different.)

---

## 2) NVMe tuning (cmdline + fstab + fstrim)

### 2.1 Kernel/NVMe power policy

Prefer driver option (survives kernel updates):

```bash
sudo tee /etc/modprobe.d/nvme.conf >/dev/null <<'EOF'
options nvme_core default_ps_max_latency_us=5500
EOF
sudo update-initramfs -u
```

> If you **must** pass via cmdline instead, append
> `nvme_core.default_ps_max_latency_us=5500` to `/boot/firmware/cmdline.txt` (single line).

Optionally add **PCIe ASPM powersave** (helps thermals):

* Append `pcie_aspm.policy=powersave` to `/boot/firmware/cmdline.txt` (end of the *same line*).

### 2.2 `fstab` (ext4, noatime, long commit; use fstrim.timer)

```bash
# Find your root UUID
blkid
```

Edit `/etc/fstab` and make your **root** ext4 line look like:

```
UUID=<YOUR-ROOT-UUID>  /  ext4  defaults,noatime,errors=remount-ro  0 1
```

Enable weekly TRIM (no continuous mount-time discard):

```bash
sudo systemctl enable --now fstrim.timer
```

Reboot later to apply cmdline/initramfs changes; for now continue.

---

## 3) CPU governor (schedutil) with bursts (persistent)

Install:

```bash
sudo apt install -y linux-cpupower
```

Set governor now:

```bash
sudo cpupower frequency-set -g schedutil
```

Your CM5 showed available big-cluster steps up to **2400000**; you kept **bursty** behavior with base floor at **1.5 GHz**. Persist this via a systemd unit that **only** sets the governor (we avoid writing non-existent `schedutil/*rate_limit*` files):

```bash
sudo tee /etc/systemd/system/cpufreq-tune.service >/dev/null <<'EOF'
[Unit]
Description=Custom CPU frequency scaling with schedutil
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/cpupower frequency-set -g schedutil

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable --now cpufreq-tune.service
```

(Your runtime min/max ended up **1500000–2400000** automatically; if needed later, you can check with:)

```bash
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
```

---

## 4) Battery (MAX17048) — driver + UPower + Plasma

You ended up with the **Hackberry MAX17048** fuel-gauge driver working, exposing:

```
/sys/class/power_supply/battery -> ../../devices/platform/i2c@0/i2c-13/13-0036/power_supply/battery
```

and dmesg line:

```
i2c i2c-13: new_device: Instantiated device max17040 at 0x36
```

### 4.1 Ensure the driver module loads automatically

```bash
sudo apt install make linux-headers-rpi-2712
git clone https://github.com/quasialex/hackberrypiq20 --depth 1
cd hackberrypiq20
make && sudo make install
```
The install creates a `dtoverlay=hackberrypicm5` entry in `/boot/firmware/config.txt` which should be removed as it disables the touchscreen.

If your kernel already has the out-of-tree module installed (you saw this):

* `hackberrypi_max17048` present (and `regmap_i2c`, `industrialio`)
* `max17040_battery.ko.xz` also visible

Just **load + persist**:

```bash
# Load now
sudo modprobe hackberrypi_max17048

# Load every boot
echo hackberrypi_max17048 | sudo tee /etc/modules-load.d/hackberry-battery.conf
sudo depmod -a
```

> If the `.ko` is **not** on your system, build/install it from your repo and place it under
> `/lib/modules/$(uname -r)/extra/`, then `sudo depmod -a`, then add the modules-load line above.

### 4.2 Verify kernel + sysfs

```bash
lsmod | egrep 'max170|hackberry|regmap_i2c|industrialio'
ls -l /sys/class/power_supply/
```

Expect a `battery` symlink as shown above.

### 4.3 UPower + Plasma

Restart UPower and re-login once:

```bash
sudo systemctl restart upower
# Then log out/in to Plasma (Wayland)
```

Inspect:

```bash
upower -d | sed -n '/Device: \/org\/freedesktop\/UPower\/devices\/Battery/,/^$/p'
```

You should **not** see `battery-missing-symbolic` anymore.
Plasma (PowerDevil) will now show a **battery icon** in the tray.

---

## 5) Touchscreen & gestures (Wayland, no Touchegg)

On Wayland+KDE, **KWin** handles gestures; we **do not** install Touchegg.

Confirm your touchscreen shows up (you saw `13-0048 EP0110M09`):

```bash
xinput list
```

(Ignoring X11 specifics; on Wayland, actual input routing is libinput → KWin.)

Enable gestures in:

> **System Settings → Workspace → Gestures**
> (2/3/4-finger swipe/pinch; works on your 4″ touch)

If you’re also using the HyperPixel overlay, keep your existing `config.txt` lines, e.g.:

```
dtoverlay=vc4-kms-dpi-hyperpixel4sq
dtoverlay=dwc2,dr_mode=host
```

(You discovered overlay order could break touch; keep the order that worked for you.)

---

## 6) Trim boot/services (what you actually disabled)

You removed/disabled these to reduce boot time/heat, but retained things you need:

```bash
# Keep BlueZ off by default (you toggle from GUI when needed)
sudo systemctl disable --now bluetooth.service

# PackageKit (updates) off
sudo systemctl disable --now packagekit.service

# PHP’s session cleaner off (you said PHP stays, but not the timer)
sudo systemctl disable --now phpsessionclean.service phpsessionclean.timer

# ModemManager + colord weren’t needed
sudo systemctl disable --now ModemManager.service colord.service 2>/dev/null || true

# NetworkManager-wait-online causes long stalls (you saw ~1m); disable:
sudo systemctl disable --now NetworkManager-wait-online.service 2>/dev/null || true
```

You **could not purge** Plymouth due to `kali-themes` dependency; leave it installed.
(If it still shows in `systemd-analyze blame`, that’s expected but small now.)

Check boot:

```bash
systemd-analyze blame
```

---

## 7) KDE: power button + wallet + tray

Power button shows **menu** (not shutdown):

```bash
kwriteconfig6 --file powermanagementprofilesrc --group HandleButtonEvents --key PowerButtonAction 0
```

Disable **KDE Wallet** (no prompts):

```bash
kwriteconfig6 --file kwalletrc --group Wallet --key Enabled false
kwriteconfig6 --file kwalletrc --group Wallet --key "First Use" false
```

Ensure the **polkit** agent is running (it is, via `polkit-kde-agent-1`).

---

## 8) KDE Ultra-Slim: nuke animations, tooltips, previews (full list you used)

**Lockscreen auto-lock off**

```bash
kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock false
kwriteconfig6 --file kscreenlockerrc --group Daemon --key LockOnResume false
```

**Common effects/popups off**

```bash
kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key wobblywindowsEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key windowviewEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key overviewEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key translucencyEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_slidingpopupsEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_dialogparentEnabled false
```

**Desktop cube & fancy switching off**

```bash
kwriteconfig6 --file kwinrc --group Plugins --key cubeEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key cubeSlideEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key flipswitchEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key coverswitchEnabled false
```

**Dim/animations off**

```bash
kwriteconfig6 --file kwinrc --group Plugins --key dimscreenEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key fadeEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key slideEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key scaleEnabled false
```

**Screen-edge & maximize flashes off**

```bash
kwriteconfig6 --file kwinrc --group Plugins --key slidebackEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_maximizeEnabled false
```

**Login/logout fading off**

```bash
kwriteconfig6 --file kwinrc --group Plugins --key loginEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key logoutEnabled false
```

**Disable desktop grid & present windows**

```bash
kwriteconfig6 --file kwinrc --group Plugins --key desktopgridEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key presentwindowsEnabled false
```

**Panel/taskbar transparency & blur off**

```bash
kwriteconfig6 --file kwinrc --group Plugins --key backgroundcontrastEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled false
```

**Disable tooltips & previews**

```bash
kwriteconfig6 --file plasmarc --group PlasmaToolTips --key ShowToolTips false
kwriteconfig6 --file plasmarc --group PlasmaToolTips --key Delay 0
kwriteconfig6 --file plasmarc --group PlasmaToolTips --key Duration 0
```

**Turn off animations globally**

```bash
kwriteconfig6 --file kdeglobals --group KDE --key AnimationDurationFactor 0
```

**Compositor minimal & low latency**

```bash
kwriteconfig6 --file kwinrc --group Compositing --key Enabled true
kwriteconfig6 --file kwinrc --group Compositing --key UseCompositing true
kwriteconfig6 --file kwinrc --group Compositing --key AllowTearing true
kwriteconfig6 --file kwinrc --group Compositing --key LatencyPolicy "PreferLowerLatency"
```

**Apply without logging out**

```bash
qdbus6 org.kde.KWin /KWin reconfigure || true
```

> (You also removed **Baloo** previously to drop indexing overhead:)
>
> ```bash
> sudo apt purge -y baloo6
> sudo apt autoremove -y
> ```

---

## 9) Optional: keep Bluetooth “off but handy”

You wanted it mostly off to save power/heat, but easy to enable when needed.
The **simplest**: disable the **service** (above), then toggle in Plasma’s Bluetooth applet; systemd will start it when required.

---

## 10) Sanity checks

* **Battery**

  ```bash
  upower -d | sed -n '/Device: \/org\/freedesktop\/UPower\/devices\/Battery/,/^$/p'
  ```

  You should see real capacity/voltage (no “battery-missing”).

* **Governor**

  ```bash
  cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor   # schedutil
  ```

* **NVMe**

  ```bash
  cat /proc/cmdline | tr ' ' '\n' | egrep 'nvme_core|pcie_aspm' || true
  findmnt -no OPTIONS /   # expect noatime,commit=60
  systemctl status fstrim.timer
  ```

* **Boot**

  ```bash
  systemd-analyze blame
  ```

* **Gestures**

  > System Settings → Workspace → Gestures

---

## Notes on things we intentionally **didn’t** do (because they broke flow earlier)

* Don’t remove `plymouth*` on Kali — `kali-themes` depends on it (you saw the solver wall).
* Don’t rely on Touchegg for gestures on Wayland/KDE — KWin handles them (your earlier source build is unnecessary now).
* Prefer **power-profiles-daemon + PowerDevil** over TLP. If you installed TLP before, purge it:

  ```bash
  sudo apt purge -y tlp
  sudo systemctl disable --now tlp.service 2>/dev/null || true
  ```

---
