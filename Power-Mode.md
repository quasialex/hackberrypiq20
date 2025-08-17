## Option A — “Smart trend” detector (automatic)

Watch **battery voltage trend** in the background. When voltage is **rising** (or sits near full) we assume “plugged”; when it drifts **down**, we assume “battery”. Then flip Wi-Fi powersave + CPU governor accordingly.

Add this service + script (safe thresholds; change the interface/governors if you like):

1. Script

```bash
sudo tee /usr/local/bin/power-autotune-trend.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Config
WLAN_IF="$(iw dev 2>/dev/null | awk '/Interface/ {print $2; exit}')"
SAMPLES=8            # ~4 minutes if TIMER runs every 30s
DELTA_MV=6           # need >6 mV rise/fall over window to count as charging/discharging
HIGH_V_MV=4200       # >=4.20 V implies near-full (bias toward "plugged")
STATE_FILE="/run/power-autotune.state"

mkdir -p /run
readarray -t hist < <(tail -n "$SAMPLES" /run/batt_vhist 2>/dev/null || true)

read_v () {
  [ -r /sys/class/power_supply/battery/voltage_now ] || echo 0
  awk '{printf "%.0f\n",$1/1000}' /sys/class/power_supply/battery/voltage_now 2>/dev/null || echo 0
}

v_now="$(read_v)"
[ "$v_now" -gt 0 ] || exit 0

# Update history
hist+=("$v_now")
if [ "${#hist[@]}" -gt "$SAMPLES" ]; then
  hist=("${hist[@]: -$SAMPLES}")
fi
printf "%s\n" "${hist[@]}" > /run/batt_vhist

# Decide plugged vs battery
v_first="${hist[0]}"
v_last="${hist[-1]}"
delta=$(( v_last - v_first ))

is_plugged=0
# Heuristics:
# 1) Clear rising trend
if [ "$delta" -ge "$DELTA_MV" ]; then
  is_plugged=1
fi
# 2) At or near full voltage => likely on charger top-off
if [ "$v_last" -ge "$HIGH_V_MV" ] && [ "$delta" -ge 0 ]; then
  is_plugged=1
fi

prev_state=""
[ -f "$STATE_FILE" ] && prev_state="$(cat "$STATE_FILE" 2>/dev/null || true)"
new_state=$([ "$is_plugged" -eq 1 ] && echo "AC" || echo "BAT")
[ "$prev_state" = "$new_state" ] || echo "$new_state" > "$STATE_FILE"

# Actions only when state changes (or first run)
if [ "$prev_state" != "$new_state" ]; then
  # Wi-Fi power save
  if [ -n "${WLAN_IF:-}" ]; then
    if [ "$is_plugged" -eq 1 ]; then
      iw dev "$WLAN_IF" set power_save off 2>/dev/null || true
    else
      iw dev "$WLAN_IF" set power_save on 2>/dev/null || true
    fi
  fi

  # CPU governor
  set_gov () {
    local gov="$1"
    local changed=0
    for c in /sys/devices/system/cpu/cpu[0-9]*; do
      [ -w "$c/cpufreq/scaling_governor" ] || continue
      echo "$gov" > "$c/cpufreq/scaling_governor" && changed=1 || true
    done
    if [ "$changed" -eq 0 ] && command -v cpupower >/dev/null 2>&1; then
      cpupower frequency-set -g "$gov" >/dev/null 2>&1 || true
    fi
  }
  if [ "$is_plugged" -eq 1 ]; then
    set_gov performance
  else
    if grep -qw schedutil /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null; then
      set_gov schedutil
    else
      set_gov ondemand
    fi
  fi

  logger -t power-autotune "Trend mode -> ${new_state}; V=${v_now}mV Δ=${delta}mV; wifi=${WLAN_IF:-none}"
fi
EOF
sudo chmod +x /usr/local/bin/power-autotune-trend.sh
```

2. Timer + service (runs every 30s)

```bash
sudo tee /etc/systemd/system/power-autotune-trend.service >/dev/null <<'EOF'
[Unit]
Description=Power autotune (trend-based)

[Service]
Type=oneshot
ExecStart=/usr/local/bin/power-autotune-trend.sh
EOF

sudo tee /etc/systemd/system/power-autotune-trend.timer >/dev/null <<'EOF'
[Unit]
Description=Run power autotune every 30s

[Timer]
OnBootSec=15
OnUnitActiveSec=30

[Install]
WantedBy=timers.target
EOF

sudo systemctl enable --now power-autotune-trend.timer
```

**Notes**

* First few minutes it builds a small voltage history; then it will flip as trends are clear.
* You can tweak `SAMPLES`, `DELTA_MV`, `HIGH_V_MV` if it’s too eager/slow.

To watch it switch:

```bash
sudo journalctl -t power-autotune -f
```

---

## Option B — One-tap manual toggle (simple & instant)

If you prefer predictability, add a tiny toggle you can map to a key/menu:

```bash
sudo tee /usr/local/bin/power-mode-toggle.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# Flip between BAT and AC profiles

WLAN_IF="$(iw dev 2>/dev/null | awk '/Interface/ {print $2; exit}')"
STATE_FILE="/run/power-autotune.state"
curr="$(cat "$STATE_FILE" 2>/dev/null || echo "BAT")"

set_gov () {
  local gov="$1"
  for c in /sys/devices/system/cpu/cpu[0-9]*; do
    [ -w "$c/cpufreq/scaling_governor" ] && echo "$gov" > "$c/cpufreq/scaling_governor" || true
  done
}

if [ "$curr" = "BAT" ]; then
  echo "AC" | sudo tee "$STATE_FILE" >/dev/null
  [ -n "${WLAN_IF:-}" ] && sudo iw dev "$WLAN_IF" set power_save off || true
  set_gov performance
  notify-send "Power mode: AC" || true
else
  echo "BAT" | sudo tee "$STATE_FILE" >/dev/null
  [ -n "${WLAN_IF:-}" ] && sudo iw dev "$WLAN_IF" set power_save on || true
  if grep -qw schedutil /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null; then
    set_gov schedutil
  else
    set_gov ondemand
  fi
  notify-send "Power mode: Battery" || true
fi
EOF
sudo chmod +x /usr/local/bin/power-mode-toggle.sh
```

Bind `/usr/local/bin/power-mode-toggle.sh` to a key in XFCE (Settings → Keyboard → Application Shortcuts), or run via your OLED/menu.
