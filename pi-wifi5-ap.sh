#!/bin/bash

set -e

AP_SSID=PI_WIFI_NAME
AP_PWD=PI_WIFI_PASSWORD
# channels: 36, 40, 44, 48, 52, 56, 60, # 64, 149, # 153, 157, 161
AP_CHANNEL=149
# seg: 42 for channel36-48, 58 for channel52-64, 155 for channel149-161
AP_CHENNEL_SEG=155


# update apt
apt-get update

# unblock wireless network modules
rfkill unblock all

# Start WIFI AP (5Ghz)
echo "Opening wifi..."

# hostapd
echo "===== hostapd ====="
apt install hostapd -y
systemctl stop hostapd
cat << EOF > /etc/hostapd/hostapd.conf
interface=wlan0
driver=nl80211

hw_mode=a
ieee80211n=1
ieee80211ac=1
ieee80211d=1
ieee80211h=1
require_ht=1
require_vht=1
wmm_enabled=1
country_code=US

vht_oper_chwidth=1
channel=$AP_CHANNEL
vht_oper_centr_freq_seg0_idx=$AP_CHENNEL_SEG
ht_capab=[HT40-][HT40+][SHORT-GI-40][DSSS_CCK-40]

wpa=2
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP

ssid=$AP_SSID
wpa_passphrase=$AP_PWD
EOF
cat << EOF > /etc/default/hostapd
DAEMON_CONF="/etc/hostapd/hostapd.conf"
EOF
systemctl unmask hostapd
systemctl enable hostapd
systemctl start hostapd

# dhcpcd
echo "===== dhcpcd ====="
cat << EOF >> /etc/dhcpcd.conf
interface wlan0
    static ip_address=192.168.4.1/24
    nohook wpa_supplicant
EOF
systemctl restart dhcpcd

# dnsmasq
echo "===== dnsmasq ====="
apt install dnsmasq -y
systemctl stop dnsmasq
cat << EOF >> /etc/dnsmasq.conf
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
EOF
systemctl start dnsmasq
systemctl reload dnsmasq

# ipforward
echo "===== ipforward ====="
cat << EOF > /etc/sysctl.conf
net.ipv4.ip_forward=1
EOF
iptables -t nat -A  POSTROUTING -o eth0 -j MASQUERADE
sh -c "iptables-save > /etc/iptables.ipv4.nat":
cat << EOF > /etc/rc.local
#!/bin/sh -e
_IP=$(hostname -I) || true 
if [ "$_IP" ]; then 
  printf "My IP address is %s\n" "$_IP" 
fi 

iptables-restore < /etc/iptables.ipv4.nat

exit 0
EOF


systemctl restart hostapd

echo "All done. WIFI5-AP has started."
