# OneClickShadowsocks

This project provide a script that can automatically install [shadowsocks-libev](https://github.com/shadowsocks/shadowsocks-libev) on an ubuntu server and generate a subscription link of [clash-verge-rev](https://github.com/clash-verge-rev/clash-verge-rev)

---

Install shadowsocks on your server:

```shell
bash <(curl -fsSL https://raw.githubusercontent.com/V1an1337/OneClickShadowsocks/refs/heads/main/ss.sh)
```

In Mainland China:

```shell
bash <(curl -fsSL https://cloud.v1an.xyz/ss.sh)
```

This script will print a subscription link based on [clash.v1an.xyz](http://clash.v1an.xyz)

subscription link example:

> http://clash.v1an.xyz/?ip=1.2.3.4&port=11111&type=ss&cipher=chacha20-ietf-poly1305&password=V1an1337

---

To deploy clash-server.py, please open port 11356 then run

```shell
python3 clash-server.py
```

Optional: you could use a reverse proxy to make it better
