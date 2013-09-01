require 'openssl'

class SSLAuthServer < OpenSSL::SSL::SSLServer
  def initialize(server, server_cert, server_key, clients_certs, require_client_auth: false)
    ssl_context = OpenSSL::SSL::SSLContext.new
    ssl_context.cert = OpenSSL::X509::Certificate.new(server_cert)
    ssl_context.key = OpenSSL::PKey::RSA.new(server_key)
    ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER
    ssl_context.verify_mode |= OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT if require_client_auth
    ssl_context.cert_store = OpenSSL::X509::Store.new
    clients_certs.each do |client_cert|
      ssl_context.cert_store.add_cert OpenSSL::X509::Certificate.new(client_cert)
    end
    super(server, ssl_context)
  end
end

module OpenSSL
  module X509
    class Certificate
      DN_NAME, DN_DATA = 0,1
      def uids
        uids = []
        subject.to_a.each do |entry|
          uids << entry[DN_DATA] if entry[DN_NAME] == 'UID'
        end
        return uids
      end
    end
  end
  module SSL
    class SSLSocket
      def uids
        return nil if !peer_cert
        return peer_cert.uids
      end
    end
  end
end
