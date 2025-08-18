# Slim KDE on Kali (CM5/Hackberry)

## 0) Prep: base system + user

```bash
# Update
sudo apt update && sudo apt -y full-upgrade

# Ensure your user (replace alex if needed) is in sudo group and passwordless
sudo usermod -aG sudo alex
echo 'alex ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/010-alex-nopasswd >/dev/null
sudo chmod 0440 /etc/sudoers.d/010-alex-nopasswd
```

### Optional: NVMe stability/power hints (CM5 PCIe)

If you’ve seen NVMe hiccups with APST/ASPM, these cmdline toggles are the safe knobs. Edit `/boot/firmware/cmdline.txt` and **append** (on the same line):

* **Conservative APST** (often stable):
  `nvme_core.default_ps_max_latency_us=100000`
* **or Disable APST** (if you hit timeouts):
  `nvme_core.default_ps_max_latency_us=0`

Reboot after editing.

## 1) Install a **slim** KDE Plasma (Wayland) + SDDM

```bash
sudo apt install --no-install-recommends \
  kali-desktop-core \
  kde-plasma-desktop \
  sddm

# (Optional but handy) small KDE apps you likely want:
sudo apt install konsole dolphin kde-spectacle plasma-nm plasma-pa powerdevil power-profiles-daemon qt6-base-bin
```

Switch to SDDM and enable autologin:

```bash
sudo systemctl disable --now lightdm greetd 2>/dev/null || true
sudo systemctl enable --now sddm

# Autologin: create /etc/sddm.conf.d/autologin.conf
sudo install -d /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/autologin.conf >/dev/null <<'EOF'
[Autologin]
User=alex
Session=plasma
EOF
```

Reboot and choose **Plasma (Wayland)** if needed. Verify:

```bash
echo $XDG_SESSION_TYPE   # should say: wayland
```

## 2) Trim KDE bloat & effects

### Indexer, PIM, Discover

```bash
# Kill Baloo (indexer)
balooctl6 disable
systemctl --user mask plasma-baloorunner.service || true

# Remove Discover (store) if you don’t need it
sudo apt purge -y plasma-discover* || true

# Remove PIM stack you don’t use
sudo apt purge -y akonadi-server kdepim-runtime kmail kaddressbook akregator kontact || true

# Clean up
sudo apt autoremove --purge -y
```

### Disable visuals/animations you don’t want

```bash
# Requires qt6-base-bin (qdbus6), installed above.
# Turn off lockscreen auto-lock
kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock false
kwriteconfig6 --file kscreenlockerrc --group Daemon --key LockOnResume false

# Disable common KWin effects/popups
kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key wobblywindowsEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key windowviewEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key overviewEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key translucencyEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_slidingpopupsEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_dialogparentEnabled false

kwriteconfig6 --file kwinrc --group Compositing --key Enabled true
kwriteconfig6 --file kwinrc --group Compositing --key UseCompositing true
kwriteconfig6 --file kwinrc --group Compositing --key AllowTearing true
kwriteconfig6 --file kwinrc --group Compositing --key LatencyPolicy "PreferLowerLatency"

# Desktop cube & fancy switching
kwriteconfig6 --file kwinrc --group Plugins --key cubeEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key cubeSlideEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key flipswitchEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key coverswitchEnabled false

# Dim/animations
kwriteconfig6 --file kwinrc --group Plugins --key dimscreenEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key fadeEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key slideEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key scaleEnabled false

# Screen edge stuff
kwriteconfig6 --file kwinrc --group Plugins --key slidebackEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key slideEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_maximizeEnabled false

# Login/logout fade
kwriteconfig6 --file kwinrc --group Plugins --key loginEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key logoutEnabled false

# Disable tooltips (hover previews)
kwriteconfig6 --file plasmarc --group PlasmaToolTips --key Delay 0
kwriteconfig6 --file plasmarc --group PlasmaToolTips --key ShowToolTips false

# Disable animations globally
kwriteconfig6 --file kdeglobals --group KScreen --key AnimationDurationFactor 0

# Disable background blur in panels
kwriteconfig6 --file kwinrc --group Plugins --key backgroundcontrastEnabled false

# Disable desktop grid & workspace animations

kwriteconfig6 --file kwinrc --group Plugins --key desktopgridEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key presentwindowsEnabled false

# Disable panel/taskbar transparency & blur

kwriteconfig6 --file kwinrc --group Plugins --key backgroundcontrastEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled false

# Disable tooltips + previews completely

kwriteconfig6 --file plasmarc --group PlasmaToolTips --key ShowToolTips false
kwriteconfig6 --file plasmarc --group PlasmaToolTips --key Delay 0
kwriteconfig6 --file plasmarc --group PlasmaToolTips --key Duration 0

# Turn off animations globally

kwriteconfig6 --file kdeglobals --group KDE --key AnimationDurationFactor 0

# Tell KWin to reload settings
qdbus6 org.kde.KWin /KWin reconfigure || true
```

> Tooltips / taskbar thumbnails preview: in **System Settings → Appearance → Panels/Task Manager** disable *“Show tooltips”* (the preview popups), or reduce hover delays in Task Manager settings.

## 3) Touchscreen & gestures

* On **Plasma 6 Wayland**, **native gestures** work — no `touchegg` needed.
  Enable/tune them at: **System Settings → Workspace → Gestures**.
* If your touch panel needs axis flip/rotation: put a libinput snippet in `/etc/X11/xorg.conf.d/` for XWayland apps (or tweak in KWin “Input”).

Quick sanity:

```bash
libinput list-devices | grep -A3 -i 'touch\|EP0110M09'
```

## 4) Battery & power (Hackberry MAX17048)

Make sure the driver is bound (you already have this):

```bash
# You should see these:
dmesg | grep -iE 'max170|hackberry'
ls -l /sys/class/power_supply/
# ... -> battery -> ...13-0036/power_supply/battery
```

Install & start the power stack:

```bash
sudo apt install -y upower powerdevil
sudo systemctl enable --now upower
systemctl --user restart plasma-powerdevil.service
```

Show the icon:

* System Tray → **Configure… → Entries → Battery and Brightness → Always shown**.

Verify:

```bash
upower -d | sed -n '/Device: \/org\/freedesktop\/UPower\/devices\/Battery/,/^$/p'
```

## 5) Wi-Fi stability (no random dropouts)

**Disable Wi-Fi power save** (persistent):

```bash
sudo install -d /etc/NetworkManager/conf.d
sudo tee /etc/NetworkManager/conf.d/wifi-powersave.conf >/dev/null <<'EOF'
[connection]
wifi.powersave = 2
EOF
sudo systemctl restart NetworkManager
```

Spot-check:

```bash
iw dev wlan0 get power_save   # expect: off
```

## 6) CPU governor + thermal guard (keeps it cool but snappy)

Use `schedutil` + sane min/max and a tiny thermal guard. (We already proved this out.)

```bash
# Service that sets governor + floors/ceilings at boot
sudo tee /usr/local/bin/cpufreq-tune.sh >/dev/null <<'EOF'
#!/bin/bash
for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
  echo schedutil > "$cpu/cpufreq/scaling_governor" 2>/dev/null
  echo 1500000  > "$cpu/cpufreq/scaling_min_freq"  2>/dev/null
  echo 2400000  > "$cpu/cpufreq/scaling_max_freq"  2>/dev/null
done
EOF
sudo chmod +x /usr/local/bin/cpufreq-tune.sh

sudo tee /etc/systemd/system/cpufreq-tune.service >/dev/null <<'EOF'
[Unit]
Description=Custom CPU frequency scaling with schedutil
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/cpufreq-tune.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now cpufreq-tune.service
```

**Optional thermal guard** (auto-cap at ≥70 °C, restore at ≤65 °C):

```bash
sudo tee /usr/local/bin/cpu-thermal-guard.sh >/dev/null <<'EOF'
#!/bin/bash
FREQ_NORMAL=2400000
FREQ_COOL=1800000
FREQ_MIN=1500000
CPU_PATH="/sys/devices/system/cpu"
THERMAL="/sys/class/thermal/thermal_zone0/temp"

for cpu in ${CPU_PATH}/cpu[0-9]*; do echo schedutil > "$cpu/cpufreq/scaling_governor" 2>/dev/null; done

while true; do
  t=$(<"$THERMAL"); t=$((t/1000))
  if (( t >= 70 )); then
    for cpu in ${CPU_PATH}/cpu[0-9]*; do
      echo $FREQ_COOL > "$cpu/cpufreq/scaling_max_freq" 2>/dev/null
      echo $FREQ_MIN  > "$cpu/cpufreq/scaling_min_freq" 2>/dev/null
    done
  elif (( t <= 65 )); then
    for cpu in ${CPU_PATH}/cpu[0-9]*; do
      echo $FREQ_NORMAL > "$cpu/cpufreq/scaling_max_freq" 2>/dev/null
      echo $FREQ_MIN    > "$cpu/cpufreq/scaling_min_freq" 2>/dev/null
    done
  fi
  sleep 5
done
EOF
sudo chmod +x /usr/local/bin/cpu-thermal-guard.sh

sudo tee /etc/systemd/system/cpu-thermal-guard.service >/dev/null <<'EOF'
[Unit]
Description=CPU Thermal Guard for CM5
After=multi-user.target

[Service]
ExecStart=/usr/local/bin/cpu-thermal-guard.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable --now cpu-thermal-guard.service
```

Verify live:

```bash
watch -n2 "cat /sys/class/thermal/thermal_zone0/temp; echo -n max=; cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq"
```

## 7) Boot-time cleanups that helped

These shaved boot time / background CPU:

```bash
# Kill the notorious online-wait
sudo systemctl disable --now NetworkManager-wait-online.service
sudo systemctl mask NetworkManager-wait-online.service

# You already moved to NetworkManager, so disable legacy ifupdown units
sudo systemctl disable networking.service ifupdown-pre.service

# Drop services you don’t need on CM5 handheld
sudo systemctl disable --now ModemManager.service avahi-daemon.service cups.service colord.service phpsessionclean.service || true
```

---

### 🪓 Remaining Slim-Down Targets

1. **Plasma Add-ons**

   * Remove widgets you don’t need:
    `sudo apt purge plasma-widgets-* plasma-discover plasma-thunderbolt plasma-browser-integration`

2. **Background Services**

   * Double-check `systemctl --user list-unit-files | grep plasma`
     Anything like `plasma-activity*`, `plasma-kpackage*` can usually be masked.

3. **Akonadi (PIM services)**

   * If you never use KDE Mail/Calendar:

     ```bash
     sudo apt purge akonadi-server kdepim-runtime
     ```

     (removes \~200MB of RAM churn)

4. **KDE Wallet**

   * If you don’t use it:

     ```bash
     sudo apt purge kwalletmanager
     ```

     (disables all wallet popups)

5. **Baloo leftovers**

   * Ensure no baloo file indexer is running:

     ```bash
     ps aux | grep baloo
     ```

     Should be empty. If not:

     ```bash
     balooctl purge
     ```

6. **PackageKit / Discover updates**

   * Already masked the notifier, but to kill it entirely:

     ```bash
     sudo apt purge plasma-discover packagekit
     ```

7. **Session speedups**

   * Plymouth is still in your blame log.

     ```bash
     sudo apt purge plymouth*
     ```

     (saves \~1–2s boot and tiny RAM)

---

## Troubleshooting quick hits

* **Battery missing in tray**: confirm `/sys/class/power_supply/battery` exists, `upower -d` shows Battery device, `plasma-powerdevil.service` is running, and the tray entry is enabled.
* **Gestures not firing**: ensure you’re in **Wayland** (`echo $XDG_SESSION_TYPE`), then tweak **System Settings → Workspace → Gestures**.
* **Wi-Fi drops**: confirm powersave is off (`iw dev wlan0 get power_save`), watch temps, and check logs:
  `dmesg -w | grep -iE 'brcm|mtk|wifi|wlan|firmware'` and `journalctl -f | grep -i wpa`.

---
### ✅ Already Done / Covered

* 🔒 Lock screen + auto-lock disabled
* 🎞️ KWin effects disabled (blur, wobbly, translucency, popups, etc.)
* 🖼️ Wallpaper replaced with solid color for efficiency
* 🖱️ Gestures preserved via Wayland/KWin
* ⚡ CPU scaling tuned (`schedutil` with burst support)
* 🔋 Battery indicator fixed (via max17048 + UPower)
* 🌐 CUPS avoided, Bluetooth optional, NetworkManager only

👉 If you do **all of that**, you’ve essentially reached **KDE UltraSlim final form**:

* Boots nearly as fast as XFCE
* Uses <400MB RAM idle
* Keeps gestures & Wayland touch
* Battery + CPU scaling optimized
