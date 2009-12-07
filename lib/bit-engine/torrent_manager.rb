module BitEngine
  class TorrentManager
    CLIENT_ID = "BE"
    VERSION   = "0001"
    attr_reader :download_path, :port,:torrents
    def initialize(download_path = '/data/test', port = 6881)
      # TODO validate port
      @download_path = download_path
      @port          = port
      @torrents      = []
      start_server
    end

    def find_torrent(hash)
      @torrents.find { |t| t.info_hash == hash }
    end

    def peer_id
      random_bytes = 16.times.collect { rand(255) }.pack('C*')
      "-#{CLIENT_ID}#{VERSION}-" + random_bytes
    end

    def register_peer(peer, info_hash, peer_id)
      #p "registering peer: #{peer} #{info_hash} #{peer_id}"
      # todo create a hash of info_hash to torrents? prolly not too necessary we'll never be managing a huge number of torrents, right?
      torrent = @torrents.find { |t| t.info_hash == info_hash && t.state == :started }
      if torrent.nil?
        #p "not managing torrent: #{info_hash}"
        return false
      end
      torrent.peer_connected(peer)
      return true
    end

    def register_torrent(torrent)
      @torrents << torrent
    end

    def on_complete(&block)
      @on_complete = block.to_proc
    end

    def on_torrent_completion(torrent)
      @on_complete.call(torrent) if @on_complete
    end

    def up_rate
      @torrents.inject(0.0) { |sum, t| sum += t.upload_rate }
    end

    def down_rate
      @torrents.inject(0.0) { |sum, t| sum += t.download_rate }
    end

    private
    def start_server
      EM.start_server '127.0.0.1', @port, PeerConnectionProper, self
      HttpServer.new(self).start!
      #p "server running"
    end

  end
end
