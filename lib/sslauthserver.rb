require 'openssl'

class SSLAuthServer < OpenSSL::SSL::SSLServer
  def initialize(server, server_key, server_cert, client_ids)
    ssl_context = OpenSSL::SSL::SSLContext.new
    ssl_context.key = server_key
    ssl_context.cert = server_cert
    ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER | OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
    ssl_context.cert_store = OpenSSL::X509::Store.new
    client_ids.keys.each{|cert|ssl_context.cert_store.add_cert(cert)}
    @clients = client_ids.map{|cert,id|[cert.to_pem,id.to_sym]}.to_h
    super(server, ssl_context)
  end
  def self.new_from_paths(server, server_key_path, server_cert_path, client_paths)
    server_key = OpenSSL::PKey::RSA.new File.read server_key_path
    server_cert = OpenSSL::X509::Certificate.new File.read server_cert_path
    client_ids = client_paths.map{|path,id|[OpenSSL::X509::Certificate.new(File.read(path)),id]}.to_h
    SSLAuthServer.new server, server_key, server_cert, client_ids
  end
  def accept
    socket = super
    id = @clients[socket.peer_cert.to_pem] if socket.peer_cert
    socket.define_singleton_method(:client_id){id}
    socket
  end
end
