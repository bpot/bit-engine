require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "PeerConnection" do
  class TestPeerConnection
    include BitEngine::PeerConnection

    def send_data data
      @sent_data ||= ''
      @sent_data << data
    end

    def sent_data
      @sent_data ||= ''
    end

    def get_peername
      Socket.getaddrinfo("localhost",Socket::AF_INET).first
    end
  end

  INFO_HASH = "acbde" * 4
  PEER_ID   = "hello" * 4

  before(:each) do
    EM.stub!(:add_periodic_timer)
    EM.stub!(:add_timer)

    @bitfield = mock(BitField, :field => [255,255,255,255], :to_packed_s => [255,255,255,255].pack('C*')).as_null_object
    @torrent = mock(Torrent, :info_hash => INFO_HASH, :peer_id => PEER_ID, :piece_count => 120, :interested_in_peer? => false, :read_block => "a" * 2**14, :piece_size => 2**16, :bitfield => @bitfield, :recalculate_chokes => true, :peer_interest_changed => true, :sent_block => true, :peer_choked_us => true)
    @torrent_manager = mock(TorrentManager).as_null_object
    @peer_c  = TestPeerConnection.new(@torrent_manager)
    @peer_c.torrent_manager = @torrent_manager
    Socket.stub!(:unpack_sockaddr_in).and_return("asdf")
  end

  context 'peer added to client' do
    it "should send handshake" do
      @peer_c.torrent = @torrent
      @peer_c.peer_added
      @peer_c.sent_data[0..67].should == "\023BitTorrent protocol\000\000\000\000\000\000\000\000#{INFO_HASH}#{PEER_ID}" 
    end
  end

  context 'incoming connection' do
    context 'receiving handshake' do
      it "should try to register with the torrent manager" do
        pending "is this necessary?"
        @torrent_manager.should_receive(:register_peer).with(@peer_c, INFO_HASH, PEER_ID)
        @peer_c.receive_data  "\023BitTorrent protocol\000\000\000\000\000\000\000\000#{INFO_HASH}#{PEER_ID}"
      end
    end
  end

  context 'incoming messages' do
    before(:each) do
      @peer_c.torrent = @torrent
      @peer_c.peer_added
      @peer_c.receive_data "\023BitTorrent protocol\000\000\000\000\000\000\000\000#{INFO_HASH}#{PEER_ID}"
    end
    context 'keep alive' do
      it 'should update last time it saw keep alive' do
        now = Time.now
        Time.stub!(:now).and_return(now)

        10.times { @peer_c.receive_data "\000" * 4 }
        @peer_c.last_seen.should == now
      end
    end

    context 'received choked message' do
      it "peer_choking? should be true" do
        @peer_c.instance_eval { @peer_choking = false }

        @peer_c.receive_data "\000\000\000\001\000"
        @peer_c.peer_choking?.should == true
      end
    end

    context 'received unchoke message' do
      it "peer_choking? should be false" do
        @peer_c.receive_data "\000\000\000\001\001"
        @peer_c.peer_choking?.should == false
      end
    end

    context 'received unchoke message' do
      it "peer_choking? should be false" do
        @peer_c.receive_data "\000\000\000\001\001"
        @peer_c.peer_choking?.should == false
      end
    end

    context 'received interested message' do
      it "peer_interested? should be true" do
        @peer_c.receive_data "\000\000\000\001\002"
        @peer_c.peer_interested?.should == true
      end

      it 'should notify torrent that a peer interest changed' do
        @peer_c.torrent.should_receive(:peer_interest_changed)
        @peer_c.receive_data "\000\000\000\001\002"
      end

    end

    context 'received uninterested message' do
      it "peer_uninterested? should be false" do
        @peer_c.instance_eval { @peer_interested = true }

        @peer_c.receive_data "\000\000\000\001\003"
        @peer_c.peer_interested?.should == false
      end

      it 'should notify torrent that a peer interest changed' do
        @peer_c.torrent.should_receive(:peer_interest_changed)
        @peer_c.receive_data "\000\000\000\001\003"
      end
    end

    context 'have message' do
      it 'should set that bit in the bitfield' do
        @peer_c.torrent = @torrent
        @peer_c.peer_added

        @peer_c.receive_data "\000\000\000\005\004\000\000\000\031"
        @peer_c.bitfield[25].should == 1
      end

      it 'should revaluated interested if not interested' do
        @peer_c.torrent = @torrent
        @peer_c.peer_added

        @torrent.should_receive(:interested_in_peer?).with(@peer_c)
        @peer_c.receive_data "\000\000\000\005\004\000\000\000\031"
      end

      it 'should send interested message if torrent tells us its interested' do
        @peer_c.torrent = @torrent
        @peer_c.peer_added

        @torrent.stub!(:interested_in_peer?).and_return(true)
        @peer_c.receive_data "\000\000\000\005\004\000\000\000\031"

        @peer_c.sent_data[-5..-1].should == "\000\000\000\001\002"
      end

      it 'should not revaluate interested if interested' do
        @peer_c.torrent = @torrent
        @peer_c.peer_added
        @peer_c.instance_eval { @am_interested = true }

        @torrent.should_not_receive(:interested_in_peer?).with(@peer_c)
        @peer_c.receive_data "\000\000\000\005\004\000\000\000\031"
      end
    end

    context 'bitfield' do
      it 'should set the correct bits' do
        @peer_c.torrent = @torrent
        @peer_c.peer_added

        @peer_c.receive_data "\000\000\000\020\005\000\000\000\000\000\000\000\000\000\000\000\000\000\000\200"
        @peer_c.bitfield[119].should == 1
      end
    end

    context 'request' do
      it 'should add the request to the request queue' do
        pending "hmmmm"
        @peer_c.receive_data "\000\000\000\r\006\000\000\000\f\000\000\000\002\000\000@\000"
        @peer_c.request_queue[0].should == [12,2,16*1024]
      end

      it 'should read the block from the torrent' do
        @torrent.should_receive(:read_block).with(12,2,16*1024)

        @peer_c.receive_data "\000\000\000\r\006\000\000\000\f\000\000\000\002\000\000@\000"
      end
    end

    context 'piece' do
      it 'should pass the piece on to the torrent' do
        @peer_c.torrent = @torrent
        @peer_c.peer_added

        @torrent.stub!(:piece_size).and_return(2**14)
        idx = 0
        offset = 0
        data  = "\000" * (2**14)
        @peer_c.torrent.should_receive(:received_piece).with(idx,data)

        @peer_c.instance_eval { @outstanding_requests = [[0,0]] }
        @peer_c.receive_data [9+data.length,7,0,0].pack('NCNN') + data
      end
    end

    context 'cancel' do
      it 'should remove the request from the queue' do
        @peer_c.request_queue = [[12,2,16*1024]]

        @peer_c.receive_data "\000\000\000\r\b\000\000\000\f\000\000\000\002\000\000@\000"
        @peer_c.request_queue.should == []
      end
    end

    context 'port' do
      it 'should be ignored' do
        pending 'handle in proto buf'
        @peer_c.receive_data "\000\000\000\003\t\032\201"
      end
    end
  end

  context 'outgoing messages' do
    before(:each) do
      @peer_c.torrent = @torrent
    end
    it 'should send 4 zeroed bytes for keep alive' do
      @peer_c.send_keep_alive
      @peer_c.sent_data.should == "\000\000\000\000"
    end

    it 'should send choke' do
      @peer_c.instance_eval { @am_choking = false }
      @peer_c.choke!
      @peer_c.sent_data.should == "\000\000\000\001\000"
    end

    it 'should send unchoke' do
      @peer_c.unchoke!
      @peer_c.sent_data.should == "\000\000\000\001\001"
    end

    it 'should send interested' do
      @peer_c.interested_in_peer
      @peer_c.sent_data.should == "\000\000\000\001\002"
    end

    it 'should send not interested' do
      @peer_c.not_interested_in_peer
      @peer_c.sent_data.should == "\000\000\000\001\003"
    end

    it 'should send have message for piece' do
      @peer_c.have_piece(12)
      @peer_c.sent_data.should == "\000\000\000\005\004\000\000\000\f"
    end

    it 'should send bitfield' do
      pending 'api changing...'
      @peer_c.send_bitfield("\000\000\000\031")
      @peer_c.sent_data.should == "\000\000\000\005\005\000\000\000\31"
    end

    it 'should request a block' do
      @peer_c.request_block(1,2,16*1024)
      @peer_c.sent_data.should == "\000\000\000\r\006\000\000\000\001\000\000\000\002\000\000@\000"
    end

    it 'should cancel a block' do
      @peer_c.cancel_block(1,2,16*1024)
      @peer_c.sent_data.should == "\000\000\000\r\b\000\000\000\001\000\000\000\002\000\000@\000"
    end

    it 'should send a block' do
      @peer_c.send_block(1,2,"\b" * 16* 1024)
      @peer_c.sent_data.should == "\000\000@\t\a\000\000\000\001\000\000\000\002" + "\b" * 16 * 1024
    end

  end
end
