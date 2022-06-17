# OpenVPN installation Guide

First of all i would recommend to get a DuckDNS name, you can do this for free by going to:
https://www.duckdns.org/

Pick a name for the $OVPN_DATA data volume container. It's recommended to use the ovpn-data- prefix to operate seamlessly with the reference systemd service. Users are encourage to replace example with a descriptive name of their choosing.
~~~
OVPN_DATA="ovpn-data-example"
~~~

Initialize the $OVPN_DATA container that will hold the configuration files and certificates. The container will prompt for a passphrase to protect the private key used by the newly generated certificate authority.
~~~
docker volume create --name $OVPN_DATA
docker run -v $OVPN_DATA:/etc/openvpn --rm kylemanna/openvpn ovpn_genconfig -u udp://VPN.SERVERNAME.COM 
~~~
make sure you update VPN.SERVERNAME.COM with your own generated duckdns name!
~~~
docker run -v $OVPN_DATA:/etc/openvpn --rm -it kylemanna/openvpn ovpn_initpki
~~~
Start OpenVPN server process

~~~
docker run -v $OVPN_DATA:/etc/openvpn -d -p 1194:1194/udp --cap-add=NET_ADMIN kylemanna/openvpn
~~~
Generate a client certificate without a passphrase
~~~
docker run -v $OVPN_DATA:/etc/openvpn --rm -it kylemanna/openvpn easyrsa build-client-full CLIENTNAME nopass
~~~
Retrieve the client configuration with embedded certificates
~~~
docker run -v $OVPN_DATA:/etc/openvpn --rm kylemanna/openvpn ovpn_getclient CLIENTNAME > CLIENTNAME.ovpn
~~~

After that you can 
