class PeerManager
  MAXIMUM_PEERS = 40

  def initialize(torrent)
    @peers            = {}
    @torrent = torrent
    @in_state = {
      :unconnected  => 0,
      :connected    => 0,
      :connecting   => 0,
      :disconnected => 0,
      :failed       => 0
    }
  end

  def add_peers(peers)
    peers.each do |p|
      if !@peers.has_key?(p)
        @peers[p] = :unconnected
      end
    end
    connect_to_peers
  end

  private
  def connect_to_peers
    @peers.each do |p, state|
      if state == :unconnected && connect_to_more_peers?
        @peers[p] = :connecting
        connect_to_peer(p)
      end
    end
  end

  def connect_to_more_peers?
    connected_and_connecting = 0
    connected = 0
    connecting = 0
    @peers.each do |_, state|
      connected_and_connecting += 1 if state == :connecting || state == :connected
      connected += 1 if state == :connected
      connecting += 1 if state == :connecting
    end

    connected_and_connecting <= MAXIMUM_PEERS
  end

  def connect_to_peer(peer)
    ip, port = expand_peer(peer)
    EM.connect ip, port, PeerConnectionProper, @torrent.manager do |c|
      c.torrent     = self
      c.compact_id  = peer
    end
  end

    def expand_peer(peer)
      ary = peer.unpack('C4n')
      [ary[0..3].join("."), ary[-1]]
    end


end
