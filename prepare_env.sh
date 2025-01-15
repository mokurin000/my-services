sudo apt-get update
sudo apt-get upgrade

sudo apt-get install -y fail2ban firewall-cmd
sudo systemctl enable --now fail2ban firewalld

# caddy reverse proxy
sudo firewall-cmd --add-service=http{,s,3}
# rustdesk self-host server
sudo firewall-cmd --add-port=2111{4..9}/tcp --add-port=21116/udp
# Whitelist rathole ports
sudo firewall-cmd --add-port=2333/tcp
sudo firewall-cmd --runtime-to-permanent

# Install caddy (packages on 24.04)
sudo apt-get install -y curl
sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt-get update
sudo apt-get install caddy

# Create custom user
sudo useradd -m moku
sudo chsh -s $(which bash) moku

# Prepare binaries
sudo apt-get install -y unzip
sudo su moku -c "mkdir -p ~/.local/bin"
sudo su moku -c "cd ~; curl -sLO https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-x86_64-unknown-linux-gnu.zip"
sudo su moku -c "cd ~; unzip rathole-x86_64-unknown-linux-gnu.zip; rm rathole-x86_64-unknown-linux-gnu.zip; mv rathole ~/.local/bin"

# Generate server-side configuration of rathole
rathole_password=$(tr -cd '[:alnum:]' < /dev/random | head -c 64)
echo '
[server]
bind_addr = "[::]:2333"

[server.services.jellyfin]
token = "'$rathole_password'"
bind_addr = "127.0.0.1:8096"

[server.transport]
type = "tcp"

[server.transport.tcp]
nodelay = false
' | sudo su moku -c 'dd of=~/server.toml'

my_ipv4=$(curl -s 'https://api.ipify.org')
clear && cat <<< '
client.toml of rathole
-----------------
[client]
remote_addr = "'$my_ipv4':2333"
default_token = "'$rathole_password'"

[client.transport]
type = "tcp"

[client.transport.tcp]
nodelay = false

[client.services.jellyfin] # Multiple services can be defined
local_addr = "127.0.0.1:8096"
'

sudo curl -1sLf -o /etc/systemd/system/rathole.service https://raw.githubusercontent.com/mokurin000/my-services/refs/heads/main/rathole.service
sudo systemctl enable --now rathole

sudo dd of=/etc/caddy/Caddyfile <<< '
jellyfinpoly.duckdns.org

reverse_proxy http://127.0.0.1:8096
'
sudo systemctl enable --now caddy

sudo su moku -c "cd ~; curl -sLO https://github.com/rustdesk/rustdesk-server/releases/download/1.1.12/rustdesk-server-linux-amd64.zip"
sudo su moku -c "cd ~; unzip rustdesk-server-linux-amd64.zip -d rustdesk-server"
sudo curl -1sLf -o /etc/systemd/system/rustdesk-hbbr.service https://raw.githubusercontent.com/mokurin000/my-services/refs/heads/main/rustdesk-hbbr.service
sudo curl -1sLf -o /etc/systemd/system/rustdesk-hbbs.service https://raw.githubusercontent.com/mokurin000/my-services/refs/heads/main/rustdesk-hbbs.service
sudo systemctl enable --now rustdesk-hbb{r,s}

echo Rustdesk server key:
echo --------------------
sudo cat /home/moku/rustdesk-server/amd64/id_ed25519.pub; echo
