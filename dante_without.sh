#!/bin/bash

# Install necessary packages
if ! apt-get update || ! apt-get install -y net-tools dante-server; then
    printf >&2 "Failed to install required packages\n"
    return 1
fi

# Stop dante-server if running
if ! systemctl stop danted; then
    printf >&2 "Failed to stop danted\n"
    return 1
fi

# Adjust port range
echo "1024 65535" > /proc/sys/net/ipv4/ip_local_port_range

# Backup existing danted configuration
mv /etc/danted.conf /etc/danted.conf.bak 2>/dev/null

# Determine the external interface
REAL_ETH=$(route | grep '^default' | grep -o '[^ ]*$')

# Check if REAL_ETH is empty
if [[ -z "$REAL_ETH" ]]; then
    printf >&2 "Failed to determine external interface\n"
    return 1
fi

# Configure danted without IP binding and login/password authentication
cat > /etc/danted.conf <<EOF
internal: $REAL_ETH port = 61080
external: $REAL_ETH
clientmethod: none
socksmethod: none
user.privileged: root
user.notprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error connect disconnect
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: bind connect udpassociate
    log: error connect disconnect
}

socks block {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect error
}
EOF

# Restart and enable danted
if ! systemctl restart danted || ! systemctl enable danted; then
    printf >&2 "Failed to restart or enable danted\n"
    return 1
fi

# Display connection test information
IP=$(wget -4 --timeout=1 --tries=1 -qO- ident.me)

printf "===================================\n"
printf "Тест подключения без IP привязки:\n"
printf "curl --ipv4 --socks5-hostname socks5://$IP:61080 ident.me\n\n"

