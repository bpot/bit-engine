require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "TorrentManager" do
  before(:each) do
    EM.stub!(:start_server)
    EM.stub!(:add_periodic_timer)
    HttpServer.stub!(:new).and_return(mock('http-server').as_null_object)
    @torrent_manager = TorrentManager.new
  end

  it 'should return a peer id with prefix "-BE0001-"' do
    @torrent_manager.peer_id[0..7].should == "-BE0001-"
  end

  it 'should start server on initialization' do
    EM.should_receive(:start_server)
    TorrentManager.new
  end

  context 'registering a peer' do
    before(:each) do
      @torrent = mock(Torrent, :info_hash => "asdfasdfasdfasdf", :state => :started).as_null_object
      @stopped_torrent = mock(Torrent, :info_hash => "stopped_torrent", :state => :stopped).as_null_object
      @torrent_manager.register_torrent(@torrent)
      @torrent_manager.register_torrent(@stopped_torrent)
    end

    it 'should add the peer to the torrent' do
      peer = mock(PeerConnection)
      @torrent.should_receive(:peer_connected).with(peer)

      @torrent_manager.register_peer(peer, "asdfasdfasdfasdf", "peer_if")
    end

    context 'not managing the torrent' do
      it 'should return false' do
        peer = mock(PeerConnection)

        @torrent_manager.register_peer(peer, "fake_fake_fake_peer", "peer_id").should == false
      end
    end

    context 'torrent not started' do
      it 'should return false' do
        peer = mock(PeerConnection)

        @torrent_manager.register_peer(peer, "stopped_torrent", "peer_id").should == false
      end
    end
  end
end
