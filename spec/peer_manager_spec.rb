require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "PeerManager" do
  before(:each) do
    @torrent = mock(Torrent).as_null_object
    @peer_manager = PeerManager.new(@torrent)
    @compacted_peer = [127,0,0,1,6881].pack('C4n')
  end

  describe "adding a peer" do
    it "should create a PeerConnection for the peer" do
      EM.should_receive(:connect).with("127.0.0.1", 6881, PeerConnectionProper, anything)
      @peer_manager.add_peers([@compacted_peer])
    end

    it "should have 1 peers connecting" do
      @peer_manager.connecting.should == 1
    end

    it "should set the torrent in the block" do
    end
  end
end
