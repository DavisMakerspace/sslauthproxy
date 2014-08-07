#
# proxy_proc = ->(client){ return socket; }
#
require 'logger'
class Proxy
  READSIZE = 1024
  def initialize(server, proxy_proc, logger:Logger.new(STDERR), readsize:READSIZE)
    @server = server
    @proxy_proc = proxy_proc
    @logger = logger
    @readsize = readsize
    @socket_pairs = {}
    @write_buffers = Hash.new{|h,k|h[k]=""}
  end
  def handle_accept
    begin
      client = @server.accept
    rescue => e
      @logger.error "#{e}"
    else
      @logger.info "new client #{client}"
      proxy = @proxy_proc.call client
      if proxy
        @logger.info "new proxy #{proxy}"
        @socket_pairs[client] = proxy
        @socket_pairs[proxy] = client
      else
        @logger.info "#{client} rejected"
        client.close
      end
    end
  end
  def handle_read(socket)
    return if !@socket_pairs.include? socket
    dest = @socket_pairs[socket]
    buf = begin
      socket.read_nonblock READSIZE
    rescue IO::WaitReadable
      nil
    rescue => e
      @logger.info "#{socket} #{e}"
      @write_buffers.delete socket
      @socket_pairs.delete socket
      "" if @socket_pairs.include? dest
    end
    @write_buffers[dest] += buf if buf
  end
  def handle_write(socket)
    return if !@write_buffers.include? socket
    buf = @write_buffers[socket]
    buf = begin
      len = socket.write_nonblock buf
    rescue IO::WaitWritable
      buf
    rescue => e
      @logger.info "#{socket} #{e}"
      @write_buffers.delete socket
      @socket_pairs.delete socket
      nil
    else
      buf.byteslice len..-1
    end
    @write_buffers[socket] = buf if buf
    @write_buffers.delete socket if @write_buffers[socket].empty?
  end
  def handle_close(socket)
    if @socket_pairs.include?(socket) && !@write_buffers.include?(socket) && !@socket_pairs.include?(@socket_pairs[socket])
      socket.close
      @socket_pairs.delete socket
      @logger.info "closed #{socket}"
    end
  end
  def run
    loop do
      rs, ws = IO.select [@server, *@socket_pairs.keys], @write_buffers.keys
      handle_accept if rs.delete @server
      rs.each{|s| handle_read s }
      ws.each{|s| handle_write s }
      ws.each{|s| handle_close s }
    end
  end
end
