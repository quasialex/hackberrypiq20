# hackberrypiq20
battery driver and panel fix for hbp q20 with cm5
# installation
```bash
sudo apt install make linux-headers-rpi-2712
git clone https://github.com/quasialex/hackberrypiq20 --depth 1
cd hackberrypiq20
make && sudo make install
sudo reboot
```
Don't forget to remove the `dtoverlay=hyperpixel4sq` line in your `config.txt`

# remove
```bash
sudo make remove
```
