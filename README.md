# SSL Authenticated Proxy

A simple ssl-based authenticator that will proxy a network connection.

## Set up

### Server key pair

The server needs a key pair for clients to authenticate it.  Here is how you could make a self-signed key pair:

    NAME=server
    openssl genrsa -out $NAME.key 2048
    openssl req -new -x509 -days 1095 -key $NAME.key -out $NAME.pub -subj /CN=$NAME

By default, `sslauthproxy` looks for `server.key` and `server.pub` in `etc/`.

### Client key pair and registration

Each client must register an ssl certificate with the server.  You can create the key pair for a client like you did for the server:

    NAME=client1
    openssl genrsa -out $NAME.key 2048
    openssl req -new -x509 -days 1095 -key $NAME.key -out $NAME.pub -subj /CN=$NAME

By default, you would then register the client by placing `client.pub` in `etc/clients/`.  The id of the client is taken from the base name of the public key file.

### Trying it out

You can try out the proxy by setting up a UNIX domain socket server with `socat`:

    socat - unix-listen:/tmp/socket,reuseaddr,fork

Then, you could have an `etc/config.rb` like so:

    PORT = 8888
    PROXY = ->(client) do
      socket = UNIXSocket.new '/tmp/socket'
      socket.puts "This is #{client.client_id}"
      socket
    end

Next, run the server:

    bin/sslauthproxy

Finally, you can test connecting using `socat`:

    socat - ssl:localhost:8888,cafile=etc/server.pub,cert=etc/clients/client1.pub,key=path/to/client1.key

And on the "server" you started, you should see "This is client1" sent before any other communications that you do.
