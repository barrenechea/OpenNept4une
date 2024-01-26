#!/bin/bash

# Create the config directory structure if not exists
[ ! -d "$HOME/printer_data/config/" ] && mkdir -p ~/printer_data/config/

# Clone the KAMP git repository if not exists
if [ ! -d "$HOME/Klipper-Adaptive-Meshing-Purging" ]; then
    cd ~/ && git clone https://github.com/kyleisah/Klipper-Adaptive-Meshing-Purging.git
fi

# Create a symbolic link if not exists
[ ! -L "$HOME/printer_data/config/KAMP" ] && ln -s ~/Klipper-Adaptive-Meshing-Purging/Configuration ~/printer_data/config/KAMP

# Clone Kiauh git repository if not exists
if [ ! -d "$HOME/kiauh" ]; then
    cd ~/ && git clone https://github.com/dw-0/kiauh.git
fi

# Add extraargs to armbianEnv.txt if not exists
FILE_PATH="/boot/armbianEnv.txt"
LINE_TO_ADD="extraargs=net.ifnames=0"
if ! grep -q "$LINE_TO_ADD" "$FILE_PATH"; then
    echo "$LINE_TO_ADD" | sudo tee -a "$FILE_PATH" > /dev/null
    echo "Added '$LINE_TO_ADD' to $FILE_PATH."
else
    echo "The line '$LINE_TO_ADD' already exists in $FILE_PATH."
fi

# Hardcoded list of GitHub raw links paired with filenames
declare -A LINKS_AND_NAMES=(
    ["https://raw.githubusercontent.com/halfmanbear/OpenNept4une/main/img-config/printer-data/printer.cfg"]="printer.cfg"
    ["https://raw.githubusercontent.com/halfmanbear/OpenNept4une/main/img-config/printer-data/moonraker.conf"]="moonraker.conf"
    ["https://raw.githubusercontent.com/halfmanbear/OpenNept4une/main/img-config/printer-data/KAMP_Settings.cfg"]="KAMP_Settings.cfg"
    ["https://raw.githubusercontent.com/halfmanbear/OpenNept4une/main/img-config/printer-data/accelerometers/btt_adxl.cfg"]="accelerometers/btt_adxl.cfg"
    ["https://raw.githubusercontent.com/halfmanbear/OpenNept4une/main/img-config/printer-data/accelerometers/btt_lis2dw.cfg"]="accelerometers/btt_lis2dw.cfg"
    ["https://raw.githubusercontent.com/halfmanbear/OpenNept4une/main/img-config/printer-data/accelerometers/mellow_adxl.cfg"]="accelerometers/mellow_adxl.cfg"
    ["https://raw.githubusercontent.com/halfmanbear/OpenNept4une/main/img-config/printer-data/accelerometers/mellow_lis2dw.cfg"]="accelerometers/mellow_lis2dw.cfg"
    ["https://raw.githubusercontent.com/halfmanbear/OpenNept4une/main/img-config/printer-data/crowsnest.conf"]="crowsnest.conf"
)

# Destination directory
DEST_DIR="$HOME/printer_data/config"

# Loop through each link and download the file only if it doesn't exist
for link in "${!LINKS_AND_NAMES[@]}"; do
    FILENAME="${LINKS_AND_NAMES[$link]}"
    if [ ! -f "$DEST_DIR/$FILENAME" ]; then
        wget -O "$DEST_DIR/$FILENAME" "$link"
        echo "Downloaded $FILENAME."
    else
        echo "$FILENAME already exists. Skipping download."
    fi
done

# Fluidd DB transfer
SHARE_LINK="https://raw.githubusercontent.com/halfmanbear/OpenNept4une/main/img-config/printer-data/data.mdb"

DESTINATION_DIR="$HOME/printer_data/database"
DESTINATION_FILE="${DESTINATION_DIR}/data.mdb"

# Check and create the output directory if it doesn't exist
[ ! -d "${DESTINATION_DIR}" ] && mkdir -p "${DESTINATION_DIR}"

# Download the .mdb file only if it doesn't already exist
if [ ! -f "${DESTINATION_FILE}" ]; then
    wget -O "${DESTINATION_FILE}" "${SHARE_LINK}"
    echo "Downloaded ${DESTINATION_FILE}."
else
    echo "${DESTINATION_FILE} already exists. Skipping download."
fi

# System updates and cleanups
sudo apt update 
sudo apt install ustreamer git python3-numpy python3-matplotlib libatlas-base-dev -y
sudo apt dist-upgrade -y
sudo apt clean -y
sudo apt autoclean -y
sudo apt autoremove -y
sudo rm -rf /var/log/*

# Create gpio and spi groups if they don't exist (for led control v.1.1+ & ADXL SPI
sudo groupadd gpio || true && sudo usermod -a -G gpio mks && echo 'SUBSYSTEM=="gpio", KERNEL=="gpiochip*", GROUP="gpio", MODE="0660"' | sudo tee /etc/udev/rules.d/99-gpio.rules > /dev/null 
sudo groupadd spiusers || true $$ sudo usermod -a -G spiusers mks 

sudo cp ~/OpenNept4une/img-config/spidev-fix/rockchip-fixup.scr /boot/dtb/rockchip/overlay/
sudo cp ~/OpenNept4une/img-config/spidev-fix/rockchip-spi-spidev.dtbo /boot/dtb/rockchip/overlay/

sudo cp ~/OpenNept4une/img-config/spidev-fix/99-spidev.rules /etc/udev/rules.d/

sudo sh -c 'echo "$(date)" > /boot/.OpenNept4une.txt'

# Add extraargs to armbianEnv.txt if not exists - makes net interface naming start from 0
FILE_PATH="/boot/armbianEnv.txt"
LINE_TO_ADD="extraargs=net.ifnames=0"
if grep -q "$LINE_TO_ADD" "$FILE_PATH"; then
    echo "The line '$LINE_TO_ADD' already exists in $FILE_PATH."
else
    echo "$LINE_TO_ADD" | sudo tee -a "$FILE_PATH" > /dev/null
    echo "Added '$LINE_TO_ADD' to $FILE_PATH."
fi

# Add sync command to crontab if not exists
CRON_ENTRY="*/10 * * * * /bin/sync"
if ! (crontab -l 2>/dev/null | grep -q "/bin/sync"); then
    (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
    echo "Sync command added to the crontab to run every 10 minutes."
else
    echo "The sync command is already in the crontab."
fi

# Immediate sync execution
sync

# Start Network Manager Text User Interface
sudo nmtui

# Run kiauh.sh as the mks user
~/kiauh/kiauh.sh
