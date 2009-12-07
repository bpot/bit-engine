module BitEngine
  class Torrent
    MAXIMUM_PEERS = 40
    attr_accessor :state, :torrent_data, :peer_connections, :want_bitfield
    attr_reader   :downloaded, :uploaded

    def initialize(manager, path)
      @manager          = manager
      @metadata         = BEncode.load_file(path)
      @torrent_data     = TorrentData.new(@metadata['info'], manager.download_path)
      @peers            = {}
      @pieces           = {}
      @rarity           = {}
      @rarity.default   = 0
      @state            = :stopped
      @peer_connections = []
      @uploaded         = 0
      @downloaded       = 0
      @piece_picker     = PiecePicker.new(self)
      @manager.register_torrent(self)
    end

    # information #
    def name
      @metadata['info']['name']
    end

    def info_hash
      Digest::SHA1.digest(@metadata['info'].bencode)
    end

    def peer_id
      @manager.peer_id
    end

    def listen_port
      @manager.port
    end

    def piece_count
      @torrent_data.piece_count
    end
    
    def piece_size
      @torrent_data.piece_size
    end

    def bitfield
      @torrent_data.bitfield
    end

    # state #
    
    def seeding?
      @torrent_data.complete?
    end

    def amount_completed
      return nil unless @want_bitfield
      have = @torrent_data.bitfield.total_set
      want = @want_bitfield.total_set
      return 0.0 if (want + have) == 0
      have.to_f / (want + have).to_f
    end

    def upload_rate
      @peer_connections.inject(0) { |sum,c| sum += c.up_rate }
    end

    def download_rate
      @peer_connections.inject(0) { |sum,c| sum += c.down_rate }
    end

    # peer interface - received_piece, sent_block, interest_changed 

    def peer_received_piece(piece, data)
      if @torrent_data.received_piece(piece, data)
        @downloaded += piece_size
        # TODO extract method
        @peer_connections.each do |p|
          p.torrent_received_piece(piece)
        end

        if seeding?
          @manager.torrent_completed(self)
        end
      else
        @want_bitfield[piece] = 1
      end
    end

    def peer_sent_block
      @uploaded += PeerConnection::BLOCK_SIZE
    end

    def peer_interest_changed
      @choker.choke!
    end

    # ??
    def read_block(idx, offset, size)
      @torrent_data.read_piece(idx).slice(offset, size)
    end

    # manager interface 
    
    # TODO this will block everything -- create a hashing state and hash using #next_tick/Thread mechanism
    def start!
      @state = :started
      @torrent_data.hash!
      @want_bitfield      = @torrent_data.bitfield.inverse
      @trackers           = http_trackers.collect { |ht| TorrentTracker.start(self,ht) }
      @choker             = Choker.new(self)
      @choker.start!
      @peer_connect_timer = EM.add_periodic_timer(30) { connect_to_peers }
    end

    def stop!
      @state = :stopped
      @trackers.each { |t| t.stop! }
      EM.cancel_timer @peer_connect_timer
      @peer_connections.each do |pc|
        pc.close_connection
      end
      @peer_connections = []
      @choker.stop!
    end

    # peer management

    # array of 6 byte strings (compact format)
    def add_peers(peers)
      p "new peers: #{peers}"
      peers.each do |p|
        if !@peers.has_key?(p)
          @peers[p] = :unconnected
        end
      end
      connect_to_peers
    end

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
      EM.connect ip, port, PeerConnectionProper, @manager do |c|
        c.torrent     = self
        c.compact_id  = peer
      end
    end

    def peer_disconnected(peer)
      @peer_connections.delete(peer)
      peer.leeching_pieces.each do |piece|
        @want_bitfield[piece] = 1
      end
      @peers[peer.compact_id] = :disconnected
    end

    def peer_choked_us(peer)
      # guess we should do something here??
    end

    def peer_connection_failed(peer)
      @peers[peer.compact_id] = :connection_failed
    end

    def peer_connected(peer)
      if @state == :stopped
        peer.close_connection
        return
      end

      @peers[peer.compact_id] = :connected
      peer.torrent = self
      peer.peer_added
      @peer_connections << peer
    end

    def expand_peer(peer)
      ary = peer.unpack('C4n')
      [ary[0..3].join("."), ary[-1]]
    end

    # TODO move to torrent data?
    def interested_in_peer?(peer)
      piece_count.times do |idx|
        if peer.bitfield[idx] == 1 && torrent_data.bitfield[idx] == 0
          return true
        end
      end
      return false
    end

    # pieces

    def has_piece?(n)
      @torrent.bitfield[n] == 1
    end

    def select_rarest_piece_for_peer(peer)
      rarest = @piece_picker.rarest_piece(peer.bitfield)
      @want_bitfield[rarest] = 0 unless rarest.nil?
      rarest
    end

    def update_rarity_for_new_peer(bitfield)
      @piece_picker.add_bitfield(bitfield)
    end

    def update_rarity_for_disconnected_peer(bitfield)
      @piece_picker.remove_bitfield(bitfield)
    end

    def update_rarity_with_have(piece_idx)
      @piece_picker.add_piece(piece_idx)
    end

    def http_trackers
      (@metadata['announce-list'] && @metadata['announce-list'].select { |a| a.first.match(/http/) }.collect { |tracker| tracker.first }) || [@metadata['announce']]
    end
  end
end
