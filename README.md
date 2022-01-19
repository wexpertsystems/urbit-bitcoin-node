# Umbrel %btc-provider node 

This image is a port of the self-contained [%btc-provider](https://github.com/wexpertsystems/urbit-bitcoin-node) image which acts as a backend for Urbit's Bitcoin wallet. This port is an app for [Umbrel](https://getumbrel.com/), a personal server project focused on crypto sovereignty.

Since Umbrel ships with `bitcoind` and `electrs` out of the box, the only remaining component from the original stack is a custom Express proxy that translates `electrs`'s RPC calls from TCP to HTTP. As a result it is quite lightweight, but entirely dependent on the host's services.

The Docker Compose file is included for reference. Most importantly it imports env vars that describe the `bitcoind` and `electrs` servers to communicate with. This package does not need persistent storage.

Once you've got it running, try curling it:

```
$> curl http://ip.address.here:50002/addresses/info/bc1qm7cegwfd0pvv9ypvz5nhstage00xkxevtrpshc
```
