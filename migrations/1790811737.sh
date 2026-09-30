echo "Limit the LocalSend firewall rule to private and local networks"

omarchy-cmd-present ufw || exit 0

# Installs before this opened 53317 to Anywhere, which on IPv6 is usually the
# whole internet. Replace only that exact rule, so a machine that closed it stays closed.
added=$(sudo ufw show added)

for proto in udp tcp; do
  if grep -Fqx "ufw allow 53317/$proto" <<<"$added"; then
    for net in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 fc00::/7 fe80::/10; do
      sudo ufw allow in proto "$proto" from "$net" to any port 53317 comment 'localsend' >/dev/null
    done
    sudo ufw delete allow "53317/$proto" >/dev/null
  fi
done
