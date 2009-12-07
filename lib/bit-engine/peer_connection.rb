require 'socket'
module BitEngine
  module BTMessage
    HANDSHAKE       = -2
    KEEP_ALIVE      = -1
    CHOKE           = 0
    UNCHOKE         = 1
    INTERESTED      = 2
    UNINTERESTED    = 3
    HAVE            = 4
    BITFIELD        = 5
    REQUEST         = 6
    PIECE           = 7
    CANCEL          = 8
    PORT            = 9
  end

  module PeerConnection
    HANDSHAKE_LENGTH = 68
    REQUEST_QUEUE_LENGTH = 5
    BLOCK_SIZE  = 16384
    attr_accessor :torrent, :torrent_manager, :last_seen, :bitfield, :request_queue, :compact_id, :leeching_pieces

    def initialize(torrent_manager)
      @connected          = false
      @received_handshake = false
      @am_choking         = true
      @peer_choking       = true
      @am_interested      = false
      @peer_interested    = false
      @current_piece      = nil
      @current_piece_offset     = nil
      @current_piece_buffer = ""
      @request_queue      = []
      @outstanding_requests = []
      @torrent_manager = torrent_manager
      @pbuf            = ProtocolBuffer.new
      @leeching_pieces = []
      @uploaded         = 0
      @downloaded       = 0
      start_timeout
    end

    def summary
      port, ip = port_and_ip
      { 
        :ip               => ip,
        :port             => port,
        :amount_completed => amount_completed,
        :am_choking       => @am_choking,
        :peer_choking     => @peer_choking,
        :am_interested    => @am_interested,
        :peer_interested  => @peer_interested,
        :uploaded         => @uploaded, 
        :downloaded       => @downloaded
      }
    end

    def start_timeout
      @timeout_timer = EM.add_timer(10) { connection_timeout }
    end

    def connection_timeout
      @torrent.peer_connection_failed(self)
    end

    def connection_completed
      @torrent.peer_connected(self)
      EM.cancel_timer @timeout_timer if @timeout_timer
      @connected = true
    end

    def amount_completed
      @bitfield.total_set.to_f / @torrent.piece_count.to_f
    end

    def connected?
      @connected
    end

    def seeding?
      @bitfield.total_set == @torrent.piece_count
    end

    def receive_data(data)
      @pbuf << data
      @pbuf.incoming_messages.each do |message|
        process_message(message)
      end
    end

    def send_data data
##      p "sd>>>>#{data}"
      super data
    end

    def peer_added
      @bitfield = BitField.new(@torrent.piece_count)
      send_handshake
      send_bitfield(@torrent.bitfield.to_packed_s)
    end

    def interested?
      @am_interested
    end

    def peer_choking?
      @peer_choking
    end

    def peer_interested?
      @peer_interested
    end

    def send_keep_alive
      send_data "\000\000\000\000"
    end

    def peer_seeding?
      @bitfield.all_set?
    end
    
    def choked?
      @am_choking
    end

    def unchoke!
      if @am_choking
        @am_choking = false
        send_message(BTMessage::UNCHOKE)
      end
    end

    def choke!
      unless @am_choking
        @am_choking = true
        send_message(BTMessage::CHOKE)
      end
    end

    def interested_in_peer
      send_message(BTMessage::INTERESTED)
    end

    def not_interested_in_peer
      send_message(BTMessage::UNINTERESTED)
    end

    def have_piece(piece)
      #p "sending have: #{piece}"
      send_message(BTMessage::HAVE, [piece].pack('N'))
    end

    def send_bitfield(packed_bitfield)
      send_message(BTMessage::BITFIELD, packed_bitfield)
    end

    def request_block(piece, offset, length)
      #p "#{pp_peer_info}: #{piece} - #{offset}"
      send_message(BTMessage::REQUEST, [piece, offset, length].pack('N3'))
    end

    def send_block(piece, offset, data)
      @uploaded += data.size
      @torrent.sent_block
      send_message(BTMessage::PIECE, [piece, offset].pack('N2') + data)
    end

    def cancel_block(piece, offset, length)
      send_message(BTMessage::CANCEL, [piece, offset, length].pack('N3'))
    end

    def has_piece?(n)
      @bitfield[n] == 1
    end

    def unbind
      @torrent.peer_disconnected(self)
    end

    private

    def both_seeding?
      seeding? && @torrent.seeding?
    end


    def send_message(message_id, data = nil)
      message_length = 1 + (data ? data.length : 0)
      message = [message_length, message_id].pack('NC') + data.to_s

      send_data message
    end

    def revaluate_interested
      close_connection if both_seeding?
      if @am_interested == false && @torrent.interested_in_peer?(self)
        @am_interested = true
        interested_in_peer
      end
    end

    def request_next_block
#      p "requesting block"
      request_block(@current_piece, @current_piece_offset, BLOCK_SIZE)
      @outstanding_requests.push([@current_piece, @current_piece_offset])

      @current_piece_offset += BLOCK_SIZE
      if @current_piece_offset == @torrent.piece_size
        @current_piece = nil
        @current_piece_offset = nil
      end
    end

    def request_blocks
      return unless !@peer_choking && @am_interested

      while @outstanding_requests.length < REQUEST_QUEUE_LENGTH
        # yay we can request more blocks
        if @current_piece
          request_next_block
        else
          piece = @torrent.select_rarest_piece_for_peer(self)
          if piece.nil?
            # guess were not interested anymore
            @am_interested = false
            not_interested_in_peer
            return
          end
          #print "requesting: #{piece} - #{@peer_id}\n"
          @leeching_pieces     << piece
          @current_piece        = piece
          @current_piece_offset = 0

          request_next_block
        end
      end
    end
    

    def send_requested_blocks
      return if @peer_choked
      while @request_queue.any?
        idx, offset, size = @request_queue.shift
        data = @torrent.read_block(idx, offset, size)
        #p "sending block (#{@request_queue.size})"
        send_block(idx, offset, data)
      end
    end

    def torrent_received_piece(piece)
      have_piece(piece) unless has_piece?(piece)
      revaluate_interested
    end

    def process_message(message)
      message_id = message.shift
      payload    = message
      case message_id
      when BTMessage::HANDSHAKE
        process_handshake(payload)
      when BTMessage::KEEP_ALIVE
        @last_seen = Time.now
      when BTMessage::CHOKE
        @peer_choking = true
        @torrent.peer_choked_us(self)
      when BTMessage::UNCHOKE
        @peer_choking = false
        request_blocks
      when BTMessage::INTERESTED
        @peer_interested = true
        @torrent.peer_interest_changed
      when BTMessage::UNINTERESTED
        @peer_interested = false
        @torrent.peer_interest_changed
      when BTMessage::HAVE
        piece_idx = payload.first
        @bitfield[piece_idx] = 1
        revaluate_interested
      when BTMessage::BITFIELD
        @bitfield = BitField.new(@torrent.piece_count, payload.first.unpack('C*'))
        revaluate_interested
      when BTMessage::REQUEST
        # TODO sanity checking
        #p "piece requested"
        @request_queue << payload
        send_requested_blocks
      when BTMessage::PIECE
        idx, beg, data = *payload
        #p "#{pp_peer_info} received piece: #{idx} - #{beg} - #{data.size} - #{@current_piece_buffer.size} (#{@peer_id})"
        @downloaded += data.size
        @current_piece_buffer += data
        request = @outstanding_requests.shift
        if request != [idx,beg]
          close_connection
        end
        if @current_piece_buffer.length == @torrent.piece_size
          @leeching_pieces.delete(idx)
          @torrent.received_piece(idx,@current_piece_buffer)
          @current_piece_buffer = ""
        end
        request_blocks
      when BTMessage::CANCEL
        idx,offset,length = *payload
        @request_queue.delete([idx,offset,length])
      when BTMessage::PORT
        # no-op for now
      end
    end

    def port_and_ip
      Socket.unpack_sockaddr_in(get_peername)
    end

    def pp_peer_info
    #  Socket.unpack_sockaddr_in(get_peername).last
    end

    def send_handshake
      handshake = [19, "BitTorrent protocol", 0,0,0,0,0,0,0,0, @torrent.info_hash, @torrent.peer_id].pack("cA19c8A20A20")
      send_data handshake
    end

    def process_handshake(payload)
      @received_handshake = true

      info_hash = payload[10]
      peer_id   = payload[11]
      @peer_id  = peer_id
      @torrent_manager.register_peer(self, info_hash, peer_id) unless @torrent
    end
  end

  class PeerConnectionProper < EM::Connection
    include PeerConnection
    include MeasureBandwidth

    def choke_peer
      @previous_up_rate = up_rate
      super
    end

    def rate_for_choke
      if @peer_choked == true
        @previous_up_rate
      else
        up_rate
      end
    end
  end
end
