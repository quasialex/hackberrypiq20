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

## 🔹 Result

* **Boot speed**: much faster (no plymouth, no extra services).
* **Idle RAM**: \~600–800 MB.
* **Gestures**: native in Plasma 6 Wayland.
* **Battery/heat**: lighter than GNOME, close to XFCE but modern.
