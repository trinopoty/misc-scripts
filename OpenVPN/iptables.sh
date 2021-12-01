ip6tables -A FORWARD -i eth0 -o tun0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
ip6tables -A FORWARD -i eth0 -o tun0 -p ipv6-icmp -j ACCEPT
ip6tables -A FORWARD -i tun0 -o eth0 -j ACCEPT

