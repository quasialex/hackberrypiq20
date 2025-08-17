## Kali with KDE on Wayland (gesture support for touch)

```bash
sudo apt update
sudo apt install --no-install-recommends \
  kali-desktop-core \
  kde-plasma-desktop \
  kde-standard \
  sddm
```

* `--no-install-recommends` keeps it slim.
* `kali-desktop-core` ensures Kali theming + core bits.
* `kde-plasma-desktop` gives Plasma without the huge bloat (no games, no office).
* `kde-standard` is optional → includes Konsole, Dolphin, minimal tools.
* `sddm` = KDE’s preferred display manager (lightdm is messier on Wayland).

👉 After install, enable `sddm`:

```bash
sudo systemctl disable lightdm
sudo systemctl enable sddm
```

---

## 🔹First Boot into KDE

Reboot → you should land in KDE Plasma on **Wayland** (select session if needed at login).

Check session type:

```bash
echo $XDG_SESSION_TYPE
```

Expect: `wayland` ✅

---

## 🔹 Trim KDE Fat

Now we cut the overhead:

1. **Disable Baloo (indexer/search)**

```bash
balooctl6 disable
```

Optional, also mask:

```bash
systemctl --user mask plasma-baloorunner.service
```

2. **Turn off Akonadi (PIM/email junk)**

```bash
systemctl --user mask plasma-akonadi.service || true
```

3. **Disable Discover + background updates**

```bash
sudo apt purge plasma-discover*
```

4. **Trim effects**
   Disable blur, wobbly windows, animations:

```bash
# Disable translucency & animations
kwriteconfig6 --file kwinrc --group Compositing --key Enabled true
kwriteconfig6 --file kwinrc --group Compositing --key OpenGLIsUnsafe true
kwriteconfig6 --file kwinrc --group Compositing --key Backend "wayland"
kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key wobblywindowsEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key windowviewEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key overviewEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key taskbarThumbnailsEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key translucencyEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_scaleEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_slidingpopupsEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_dialogparentEnabled false


qdbus6 org.kde.KWin /KWin reconfigure

```

5. **Autologin**
   Edit `/etc/sddm.conf`:

```ini
[Autologin]
User=alex
Session=plasma
```

---

## 🔹 Step 5. Power + Touch

* **Power management** = Plasma’s `powerdevil` (keep it, don’t mask).
* **Battery widget** = already included, no need to hack in XFCE’s.
* **Touch gestures**: Plasma 6 has native gestures, no `touchegg` needed.
  Enable them under **System Settings → Workspace → Gestures**.

---

## 🔹 Step 6. Optional Extra Slimming

Remove heavy apps you don’t need:

```bash
sudo apt purge konqueror kaddressbook kmail akregator kontact kdeconnect plasma-discover akonadi-server kdepim-runtime korganizer
sudo apt autoremove --purge
```

You'll also need:

```bash
sudo apt install powerdevil
```

That will give you:

* the daemon (`powerdevil`)
* its config module (shows up in KDE System Settings → Power Management)

---

⚡ To recap, after re-imaging + KDE minimal, you’ll want:

```bash
sudo apt install powerdevil plasma-nm plasma-pa konsole dolphin kde-spectacle
```

Then trim the bloat as I listed before.

👉 Do you want me to build you a **single-script setup** (install + purge + disable baloo, etc.) so you just run it once after a fresh image and have a clean KDE environment?

---
```
sudo tee /etc/systemd/system/cpupower.service <<'EOF'
[Unit]
Description=Set CPU frequency governor
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/cpupower frequency-set -g schedutil
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl enable --now cpupower.service


systemctl disable --now cups.service avahi-daemon.service ModemManager.service
sudo systemctl disable NetworkManager-wait-online.service
sudo systemctl mask NetworkManager-wait-online.service
sudo systemctl disable networking.service ifupdown-pre.service
sudo systemctl disable tlp.service
sudo apt purge tlp

```

## 🔎 Possible Causes of Wi-Fi Drops

1. **Thermal throttling of the SoC**

   * The onboard Wi-Fi chip sits near the SoC; when it overheats, the kernel driver resets the radio.
   * You can check logs with:

     ```bash
     dmesg -w | grep -i wifi
     journalctl -f | grep -i wpa
     ```

2. **Power saving cutting the Wi-Fi**

   * By default, NetworkManager and some drivers enable power save aggressively.
   * Run:

     ```bash
     iw dev wlan0 get power_save
     ```

     If it says `on`, try disabling it:

     ```bash
     sudo iw dev wlan0 set power_save off
     ```

3. **Driver instability on Wayland/KDE**

   * Less likely, but some Realtek/MediaTek drivers are flaky under load.

---

## 🛠 Fixes to Try

1. **Force disable Wi-Fi powersave permanently**

   ```bash
   sudo mkdir -p /etc/NetworkManager/conf.d
   sudo tee /etc/NetworkManager/conf.d/wifi-powersave.conf <<'EOF'
   [connection]
   wifi.powersave = 2
   EOF
   sudo systemctl restart NetworkManager
   ```

2. **Improve cooling**

   * Ensure your heatsink actually touches the SoC with good thermal paste.
   * If you can, undervolt or cap CPU freq slightly:

     ```bash
     sudo cpupower frequency-set -u 1.8GHz
     ```

     (drops heat dramatically, Wi-Fi stays stable).

3. **Watch temps live**

   ```bash
   watch -n 1 "cat /sys/class/thermal/thermal_zone*/temp"
   ```

   Temps > 75–80 °C → expect Wi-Fi issues.


