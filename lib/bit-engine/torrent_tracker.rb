class TorrentTracker
  ANNOUNCE_INTERVAL = 30*60
  def initialize(torrent,tracker)
    @torrent, @tracker = torrent, tracker
  end

  def self.start(torrent, tracker)
    tt = new(torrent, tracker)
    tt.start!
    tt
  end

  def start!
    do_request(request_hash.merge(:event => 'start'))
    @announce_timer = EM.add_periodic_timer(ANNOUNCE_INTERVAL) { announce }
  end

  def stop!
    do_request(request_hash.merge(:event => 'stopped'))
    EM.cancel_timer(@announce_timer) if @announce_timer
  end

  def announce
    do_request(request_hash)
  end

  private

  def handle_announce_response(content)
    dict = BEncode.load(content)
    @torrent.add_peers(split_peers(dict["peers"]))
  end

  def split_peers(peers)
    num_peers = peers.length/6
    (0..(num_peers-1)).collect { |n| peers.slice(n*6,6) }
  end

  def do_request(hash)
    query_string = hash.map { |k,v| "%s=%s" % [URI.encode(k.to_s), URI.encode(v.to_s)] }.join("&")
    uri = URI.parse(@tracker)
    http = EventMachine::Protocols::HttpClient.request(
      :host => uri.host,
      :post => uri.port,
      :request => uri.path,
      :query_string => query_string
    )

    http.callback { |response|
      if response[:status] == 200
        handle_announce_response(response[:content])
      end
    }
  end

  def request_hash
    {:info_hash   => @torrent.info_hash,
      :port       => @torrent.listen_port,
      :peer_id    => @torrent.peer_id,
      :uploaded   => @torrent.uploaded,
      :downloaded => @torrent.downloaded,
      :compact    => 1}
  end
end
