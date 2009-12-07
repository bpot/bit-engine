require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Choker" do
  before(:each) do
    @torrent = mock(Torrent).as_null_object
    @choker  = Choker.new(@torrent)
  end

  describe 'timers' do
    before(:each) do
      EM.stub!(:add_periodic_timer)
      EM.stub!(:cancel_timer)
    end

    it 'should create a periodic EM timer for every 10 seconds' do
      EM.should_receive(:add_periodic_timer).with(10)
      @choker.start!
    end

    it 'should cancel periodic timer' do
      @choker.start!

      EM.should_receive(:cancel_timer).once
      @choker.stop!
    end
  end

  def mock_peer(down_rate, up_rate, interested)
    mock(PeerConnection, :down_rate => down_rate, :peer_interested? => interested, :choked? => true, :unchoke! => true, :up_rate => up_rate, :choke! => true)
  end

  context 'leeching' do
    before(:each) do
      @torrent  = mock(Torrent, :seeding? => false)
      @choker   = Choker.new(@torrent)

      @peers    = []
      # slow
      5.times { @peers << mock_peer(5, 15, true) }

      # unchoke
      @peers << @p_08_i = mock_peer( 8, 20, true)
      @peers << @p_10_i = mock_peer(10, 30, true)
      @peers << @p_15_i = mock_peer(15, 22, true)
      @peers << @p_25_i = mock_peer(25, 99, true)
      @peers << @p_30_u = mock_peer(30,  0, false)
      @peers << @p_35_i = mock_peer(35,  0, true)

      @torrent.stub!(:peer_connections).and_return(@peers)
    end

    it 'should unchoke 4 peers with highest download rates who are interested' do
      @p_35_i.should_receive(:unchoke!)
      @p_25_i.should_receive(:unchoke!)
      @p_15_i.should_receive(:unchoke!)
      @p_10_i.should_receive(:unchoke!)

      @choker.choke!
    end

    it 'should only unchoke the highest 4 peers' do
      @p_08_i.should_not_receive(:unchoke!)

      @choker.choke!
    end

    it 'should unchoke peers with higher download rates than unchoke who arent intrested' do
      @p_30_u.should_receive(:unchoke!)

      @choker.choke!
    end

    context 'uninterested fast peer becomes interested' do
      it 'should choke slowest unchoked & interested peer' do
        @choker.choke!

        @p_10_i.stub!(:choked?).and_return(false)
        @p_30_u.stub!(:peer_interested? => true)

        @p_10_i.should_receive(:choke!)
        @choker.choke!
      end
    end
  end

  context 'seeding' do
  end

  describe 'optimistic peer selection' do
    it 'should happen every 3rd rechoke' do
    end

    it 'should choose a random peer' do
    end
  end
end
