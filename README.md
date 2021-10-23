# %btc-provider full node on Docker

[Dockerhub](https://hub.docker.com/r/wexpertsystems/urbit-bitcoin-node)

Urbits communicate with the Bitcoin blockchain via providers, who themselves are connected to full nodes running a few pieces of extra software. This stack can be a little complicated to set up on your own -- using this Docker container should simplify setup and scaling. 

We'll go through the full setup process, from installing Docker to connecting your provider.

To begin with, you will need **at least** 600GB of disk space available. This setup requires the full blockchain, plus additional space for indexing. Once you have a disk available, make note of its path; you might just use your home directory if if you are running this on a spare PC, or it may be somewhere like `/media/<label>` or `/mnt/<label>` for a mounted drive.

## Under the hood

You can take a look at the pieces involved here by looking at `~timluc-miptev`'s [urbit-bitcoin-rpc](https://github.com/urbit/urbit-bitcoin-rpc) repo; this container is just a prepackaged version of the software therein. Inside there is `bitcoind`, the Bitcoin daemon; `electrs`, a Rustlang reimplementation of the Electrum RPC server; and a custom Node Express server to translate the RPC calls to and from HTTP.

Once it's set up, the chain of communication looks like this:

```
<Docker>
  [bitcoind]
  [electrs]
  [express]
         ^
         |
         v
<Moon>
  [%btc-provider]
         ^
         |
         v
<Planet>
  [%btc-wallet]
```

## Install Docker

On Ubuntu, install the dependencies and repos:

```
$> sudo apt-get update
$> sudo apt-get install ca-certificates curl gnupg lsb-release
$> curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
$> echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

Then install Docker:

```
$> sudo apt-get update
$> sudo apt-get install docker-ce docker-ce-cli containerd.io
$> sudo groupadd docker && sudo usermod -aG docker $USER
```

## Running the container

Now you can run the container:

```
docker run -d --name urbit-bitcoin-node -v /mnt/bitcoin/bitcoin_data:/bitcoin/data -p 127.0.0.1:8332:8332 -p 8333:8333 -p 50002:50002 wexpertsystems/urbit-bitcoin-node
```

A few notes here: 

- `/mnt/bitcoin/bitcoin_data` is a placeholder path -- replace it with whatever path you want to hold the blockchain in. Remember that it needs at least 600GB of free space.
- `8333` is the `bitcoind` p2p port; `50002` is the RPC port. These ports are exposed on the host machine's network interface, so you can reach them from other devices.
- Once you start running the container, it will **probably take about two days** for the blockchain to finish syncing and indexing. You can check on its progress by watching the terminal output. 

Once the blockchain has synced, you can test the RPC manually using `curl`: 

```
$> curl http://ip.address.here:50002/addresses/info/bc1qm7cegwfd0pvv9ypvz5nhstage00xkxevtrpshc
```

...which should return a JSON blob.

## TLS reverse proxy

By default, our RPC server is serving requests publicly over unencrypted HTTP. Let's put a restricted reverse proxy with TLS on it -- this is very simple with a tool called [Caddy](https://caddyserver.com/).
 
First, install the repo:

```
$> sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
$> curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/cfg/gpg/gpg.155B6D79CA56EA34.key' | sudo apt-key add -
$> curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/cfg/setup/config.deb.txt?distro=debian&version=any-version' | sudo tee -a /etc/apt/sources.list.d/caddy-stable.list
```

Then install Caddy, and give it well-known port privileges: 

```
$> sudo apt update && sudo apt install caddy
$> sudo setcap 'cap_net_bind_service=+ep' /usr/bin/caddy
```
 
Now you'll need to create a config file. Open `/etc/caddy/Caddyfile` in a text editor. Here is a simple config that includes IP address whitelisting to prevent public use of the node:

```
bitcoin.domain.com {
@node {
remote_ip forwarded 172.17.0.0/24 1.2.3.4
}
handle @node {
reverse_proxy 172.17.0.1:50002
}
respond "Bad IP" 403
}
```

In this configuration, `bitcoin.domain.com` is your full node's dedicated subdomain, `1.2.3.4` is the public IP address of any external device that needs to access the node, and `172.17.0.0/24` whitelists the private IP range of your Docker interfaces, in case you're running a ship in a container. `172.17.0.1` is the private IP of your node's container -- you can find it with `ip a`, and looking for the interface named `docker0`.

Save this file, and `caddy start`. You should be able to curl your domain with HTTPS:

```
$> curl https://bitcoin.domain.com/addresses/info/bc1qm7cegwfd0pvv9ypvz5nhstage00xkxevtrpshc
```

## Setting up %btc-provider

You are strongly encouraged to **run `%btc-provider` on a moon**! This service can be taxing on ships, and it is good to separate that from the day-to-day tasks your personal planet or star might need to perform.

All ships come with `%btc-provider` pre-installed. Once you have booted a moon, run the folllowing commands in the dojo:

```
dojo> |rein %bitcoin [& %btc-provider]
dojo> =network %main
dojo> :btc-provider +bitcoin!btc-provider/command [%set-credentials api-url='https://addresshere' network]
```

Modify the node's address as necessary; if you are not using a TLS reverse proxy, change the URL to use `http`.

Your provider ship will grind for a few moments, then give you a new block announcement in the dojo:

```
"%new-block: 706.085"
```

Now you can whitelist clients to allow them to connect to you as a provider. For your child points:

```
dojo> :btc-provider +bitcoin!btc-provider/command [%add-whitelist %kids ~]
```

For all members of a group:

```
dojo> :btc-provider +bitcoin!btc-provider/command [%add-whitelist [%groups groups=(sy ~[[~sampel %group-name]])]]
```

For a specific `@p`:

```
dojo> :btc-provider +bitcoin!btc-provider/command [%add-whitelist [%users users=(sy ~[~wallet-hodler])]]
```

To allow public use/global whitelist:

```
dojo> :btc-provider +bitcoin!btc-provider/command [%add-whitelist %public ~]
```
