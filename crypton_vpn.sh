#!/bin/bash

echo -e '\e[91m'
echo -e '  ____                  _                    '
echo -e ' / ___|_ __ _   _ _ __ | |_ ___  _ __        '
echo -e '| |   |  __| | | |  _ \| __/ _ \|  _ \       '
echo -e '| |___| |  | |_| | |_) | || (_) | | | |      '
echo -e ' \____|_|   \__  |  __/ \__\___/|_| |_|      '
echo -e '            |___/|_|                         '
echo -e '\e[0m'

function install_wireguard() {
  echo -e '\n\e[42m\e[30mStarting Wireguard Installation\e[0m\n' && sleep 2

  sudo apt update && sudo apt upgrade -y

  apt install ufw  -y
  apt install qrencode -y
  sudo ufw allow 51820/udp && sudo ufw reload

  apt install wireguard -y

  wg genkey | tee /etc/wireguard/privatekey | wg pubkey | tee /etc/wireguard/publickey
  chmod 600 /etc/wireguard/privatekey

  sudo tee /etc/wireguard/wg0.conf > /dev/null <<EOF
[Interface]
PrivateKey = $(cat /etc/wireguard/privatekey)
Address = 10.0.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $(ip a | grep -oP '(?<=2: ).*' | grep -o '^....') -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $(ip a | grep -oP '(?<=2: ).*' | grep -o '^....') -j MASQUERADE
EOF

  sysctl -w net.ipv4.ip_forward=1
  echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
  sysctl -p

  sudo systemctl daemon-reload
  sudo systemctl enable wg-quick@wg0.service
  sudo systemctl start wg-quick@wg0.service

  echo -e '\n\e[42m\e[30mGenerating keys for confings, please wait\e[0m\n' && sleep 2

  for ACC_NUM in {2..11}
  do
    private_key=$(wg genkey)
    public_key=$(echo $private_key | wg pubkey)
    echo $private_key | tee /etc/wireguard/$ACC_NUM'_private' > /dev/null
    echo $public_key | tee /etc/wireguard/$ACC_NUM'_public' > /dev/null

    echo $public_key
  
    sudo tee -a /etc/wireguard/wg0.conf > /dev/null <<EOF

[Peer]
PublicKey = $public_key
AllowedIPs = 10.0.0.$ACC_NUM/32
EOF

    systemctl restart wg-quick@wg0.service && sleep 2
  done



  echo -e '\n\e[42m==================================================\e[0m\n'
  echo -e '\n\e[42m\e[30mSAVE ALL DATA BELOW\e[0m\n' && sleep 2
  echo -e '\n\e[42m==================================================\e[0m\n'

  for ACC_NUM in {2..11}
  do
    echo "
[Interface]
PrivateKey = $(cat /etc/wireguard/$ACC_NUM'_private')
Address = 10.0.0.$ACC_NUM/32
DNS = 8.8.8.8

[Peer]
PublicKey = $(cat /etc/wireguard/publickey)
Endpoint = $(wget -qO- eth0.me):51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 20

"
    sudo tee qr.conf > /dev/null <<EOF
[Interface]
PrivateKey = $(cat /etc/wireguard/$ACC_NUM'_private')
Address = 10.0.0.$ACC_NUM/32
DNS = 8.8.8.8

[Peer]
PublicKey = $(cat /etc/wireguard/publickey)
Endpoint = $(wget -qO- eth0.me):51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 20
EOF
    qrencode -t ansiutf8 < qr.conf
    if [ $ACC_NUM -ne 11 ]; then
      echo -e "\n"
      echo -e "\n\e[42m###################################\e[0m\n"
    fi
  done

  echo -e '\n\e[42m==================================================\e[0m\n'
  echo -e '\n\e[42m\e[30mSAVE ALL DATA ABOVE\e[0m\n' && sleep 2
  echo -e '\n\e[42m==================================================\e[0m\n'
}

function add_more_profiles() {
  # Check how many profiles already exist
  profile_count=$(ls /etc/wireguard | grep "_private" | wc -l)

  # Increase the profile count by 10
  profile_count=$((profile_count+10))

  echo -e '\n\e[42m###################################\e[0m\n'

  echo -e '\n\e[42m\e[30mGenerating keys for confings, please wait\e[0m\n' && sleep 2

  for ACC_NUM in $(seq $((profile_count-9)) $profile_count)
  do
    private_key=$(wg genkey)
    public_key=$(echo $private_key | wg pubkey)
    echo $private_key | tee /etc/wireguard/$ACC_NUM'_private' > /dev/null
    echo $public_key | tee /etc/wireguard/$ACC_NUM'_public' > /dev/null

    echo $public_key

    sudo tee -a /etc/wireguard/wg0.conf > /dev/null <<EOF

[Peer]
PublicKey = $public_key
AllowedIPs = 10.0.0.$ACC_NUM/32
EOF

    systemctl restart wg-quick@wg0.service && sleep 2
  done



  # Output configurations and QR codes
  echo -e '\n\e[42m==================================================\e[0m\n'
  echo -e '\n\e[42m\e[30mSAVE ALL DATA BELOW\e[0m\n' && sleep 2
  echo -e '\n\e[42m==================================================\e[0m\n'

  for ACC_NUM in $(seq $((profile_count-9)) $profile_count)
  do
    echo "
[Interface]
PrivateKey = $(cat /etc/wireguard/$ACC_NUM'_private')
Address = 10.0.0.$ACC_NUM/32
DNS = 8.8.8.8

[Peer]
PublicKey = $(cat /etc/wireguard/publickey)
Endpoint = $(wget -qO- eth0.me):51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 20

"
    sudo tee qr.conf > /dev/null <<EOF
[Interface]
PrivateKey = $(cat /etc/wireguard/$ACC_NUM'_private')
Address = 10.0.0.$ACC_NUM/32
DNS = 8.8.8.8

[Peer]
PublicKey = $(cat /etc/wireguard/publickey)
Endpoint = $(wget -qO- eth0.me):51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 20
EOF
    qrencode -t ansiutf8 < qr.conf
    if [ $ACC_NUM -ne $profile_count ]; then
      echo -e "\n"
      echo -e "\n\e[42m###################################\e[0m\n"
    fi
  done

  echo -e '\n\e[42m==================================================\e[0m\n'
  echo -e '\n\e[42m\e[30mSAVE ALL DATA ABOVE\e[0m\n' && sleep 2
  echo -e '\n\e[42m==================================================\e[0m\n'
}


function remove_and_reset() {
    echo -e '\n\e[42m\e[30mResetting all changes\e[0m\n' && sleep 2

    # Stop the Wireguard service
    sudo systemctl stop wg-quick@wg0.service

    # Remove Wireguard configuration and keys
    sudo rm -r /etc/wireguard/*

    # Uninstall Wireguard and qrencode
    sudo apt purge wireguard qrencode -y

    # Block the Wireguard port on ufw
    sudo ufw deny 51820/udp && sudo ufw reload

    # Reset IP forwarding 
    sudo sed -i '/net.ipv4.ip_forward=1/d' /etc/sysctl.conf
    sudo sysctl -p
}


echo "Choose option:"
echo "1. Install Wireguard and create profiles"
echo "2. Add more Wireguard profiles"
echo "3. Remove Wireguard and reset changes"
read -p "Enter your choice: " choice

case $choice in
  1) install_wireguard;;
  2) add_more_profiles;;
  3) remove_and_reset;;
  *) echo "Invalid choice";;
esac
