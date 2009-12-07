module BitEngine
  class ProtocolBuffer
    include BTMessage
    HANDSHAKE_LENGTH = 68
    FORMATS = { 
      HANDSHAKE    => 'Ca19C8a20a20',
      HAVE         => 'N',
      BITFIELD     => 'a*',
      REQUEST      => 'N3',
      PIECE        => 'N2a*',
      CANCEL       => 'N3'
    }.freeze

    def self.build_message(id, *args)
    end

    def initialize
      @buffer = ""
      @old    = ""
      @received_handshake = false
    end

    def <<(data)
      @buffer << data
    end

    def incoming_messages
      messages = []
      while message = extract_message 
        messages << message 
      end
      messages
    end

    private

    def have_message?
      @buffer.length >= 4 && @buffer.length >= current_message_length+4
    end

    def extract_message
      if @received_handshake == false
        if validate_handshake
          return extract_handshake
        else
          return false
        end
      end

      if have_message?
        print "cml: #{current_message_length}" if current_message_length > 20_000
        parse_message        
      else
        return false
      end
    end

    def current_message_length
      #p @buffer
      @buffer.unpack('N').first
    end

    def parse_message
      message_length = current_message_length
      message_s      = @buffer.slice!(0,4+current_message_length)
      @old << message_s

      if message_length == 0
        message_id = KEEP_ALIVE
      else
        message_id = message_s[4] 
      end

      message        = [message_id]

      # add in payload if there is one
      if message_length > 1
        payload    = message_s[5..-1]
        message += payload.unpack(FORMATS[message_id])
      end

      message
    end

    def format_for(message_id)
    end

    def extract_handshake
      @received_handshake = true

      handshake = @buffer.slice!(0, HANDSHAKE_LENGTH)
      @old << handshake
      [BTMessage::HANDSHAKE] + handshake.unpack(FORMATS[HANDSHAKE])
    end

    def validate_handshake
      @buffer.size >= HANDSHAKE_LENGTH && @buffer[1..19] == 'BitTorrent protocol'
    end
  end
end
