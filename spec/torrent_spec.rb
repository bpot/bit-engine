require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Torrent" do
  TEST_INFO_HASH = "\234\224\020|\3472v\257\200\005\214\246\367\342q\327hy\343\f"
  before(:each) do
    @manager  = mock(TorrentManager, :peer_id => "hello", :port => 6881, :download_path => "/tmp", :register_torrent => true, :torrent_completed => true)
    @td = mock(TorrentData, :piece_size => 2**14, :piece_count => 88).as_null_object
    TorrentData.stub!(:new).and_return(@td)
    @torrent  = Torrent.new(@manager, File.dirname(__FILE__) + '/data/random.data.torrent')
    EM.stub!(:add_periodic_timer)
    EM.stub!(:cancel_timer)
  end

  it 'should provide the torrents info hash' do
    @torrent.info_hash.should == TEST_INFO_HASH
  end

  it 'should provide an array of http trackers' do
    @torrent.http_trackers.should == ['http://tracker.openbittorrent.com/announce']
  end

  context 'starting torrent' do
    before(:each) do
      @ta = mock(TorrentTracker).as_null_object
      TorrentTracker.stub!(:start).and_return(@ta)
    end
    it 'should announce to the tracker' do
      TorrentTracker.should_receive(:start).with(@torrent, 'http://tracker.openbittorrent.com/announce')
      @torrent.start!
    end

    it 'should update state to started' do
      @torrent.start!
      @torrent.state.should == :started
    end

    it 'should tell torrent_data to hash the files' do
      @td.should_receive(:hash!)
      @torrent.start!
    end
  end

  context 'stopping torrent' do
    before(:each) do
      @ta = mock(TorrentTracker).as_null_object
      TorrentTracker.stub!(:start).and_return(@ta)
      @torrent.start!
    end

    it 'should stop tracker' do
      @ta.should_receive(:stop!)
      @torrent.stop!
    end

    it 'should close all peer connections' do
      pc = mock('peer_connection')
      @torrent.peer_connections << pc

      pc.should_receive(:close_connection)
      @torrent.stop!
    end
  end

  context 'interest in peer' do
    before(:each) do
      @bitfield = BitField.new(4)
      @bitfield[0] = 1
      @peer = mock(PeerConnection, :bitfield => @bitfield)
      @torrent.torrent_data.stub!(:piece_count).and_return(4)
    end

    it 'should return true if peer has a piece we are missing' do
      our_bf = BitField.new(4)
      @torrent.torrent_data.stub!(:bitfield).and_return(our_bf)

      @torrent.interested_in_peer?(@peer).should == true 
    end

    it 'should return false if peer has a subset of pieces we have' do
      our_bf = BitField.new(4)
      4.times { |n| our_bf[n] = 1}
      @torrent.torrent_data.stub!(:bitfield).and_return(our_bf)

      @torrent.interested_in_peer?(@peer).should == false
    end
  end

  context 'connecting to peers' do
  end

  describe 'interested in peer?' do
  end

  context 'received new piece' do
    before(:each) do
      @torrent.torrent_data.stub!(:received_piece).and_return(true)
    end

    it 'should send it to torrent data' do
      @torrent.torrent_data.should_receive(:received_piece).and_return(true)
      @torrent.peer_received_piece(12, "asdfasdfd")
    end

    it 'should updated downloaded amount by piece size' do
      @torrent.peer_received_piece(12, "asdfasdfd")
      @torrent.downloaded.should == @torrent.piece_size

      @torrent.peer_received_piece(13, "asdfasdfd")
      @torrent.downloaded.should == @torrent.piece_size * 2
    end

  end

  context 'broadcasting have information' do
    # FIXME
    it 'should broadcast a have message only to peers without the piece' do
      pending "fix me"
      @peer_has_piece = mock(PeerConnection, :has_piece? => true)
      @peer_doesnt_have_piece = mock(PeerConnection, :has_piece? => false)
      peer_hash = { "a" => @peer_has_piece, "b" => @peer_doesnt_have_piece }
      @torrent.instance_eval { @peers = peer_hash }

      @peer_has_piece.should_not_receive(:have_piece)
      @peer_doesnt_have_piece.should_receive(:have_piece).with(12)

      @torrent.broadcast_have(12)
    end
  end

  context 'stopping torrent' do
  end

  # TODO announce-list
  #
  context 'adding peers' do
  end
end
