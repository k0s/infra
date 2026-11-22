# service_index

A page on port 80 linking the host's web services, for hosts in
`service_index_hosts`. Links open in new tabs, grouped **LAN** or **this box only**
by each service's bind address.

- The page is static, rendered from the other roles' port and address variables
  (`service_index_known` in `defaults/main.yml`). Add unmanaged services per host
  with `service_index_extra`.
- Served by `python3 -m http.server` in a system unit, as the login user, with only
  `CAP_NET_BIND_SERVICE`. Root installs the unit; no packages.
- Loopback by default. Set `service_index_address=0.0.0.0` per host for the LAN.
- `--tags service_index_page` re-renders the page alone, without root. The server
  reads the file on each request, so no restart.
- Port 80 must be free. If a firewall is on, allow the LAN to tcp/80.

## Check

    systemctl status service-index
    curl -s http://localhost/ | grep -c 'target="_blank"'
