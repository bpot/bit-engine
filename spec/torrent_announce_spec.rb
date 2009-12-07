require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "TorrentTracker" do
  before(:each) do
    @torrent = mock(Torrent, :info_hash => "info_hash", :listen_port => 6881, :peer_id => "peer_id").as_null_object
    @tracker = "http://tracker.example.com/announce"
    @torrent_announce = TorrentTracker.new(@torrent, @tracker)
    EM::P::HttpClient.stub(:request).and_return(mock('http').as_null_object)
    EM.stub!(:add_periodic_timer)
  end

  context 'sending request' do
    it 'should send the request via EM HttpClient' do
      EM::P::HttpClient.should_receive(:request).and_return(mock('http').as_null_object)
      @torrent_announce.announce
    end

    it 'should include the torrents information' do
      EM::P::HttpClient.should_receive(:request).with do |hash|
        hash[:query_string].should match(/info_hash=info_hash/)
        hash[:query_string].should match(/port=6881/)
        hash[:query_string].should match(/peer_id=peer_id/)
      end.and_return(mock('http').as_null_object)

      @torrent_announce.announce
    end
  end

  context 'handling response' do
    before(:each) do
      response_dict = {
        "complete" => 10,
        "incomplete" => 20,
        "peers"     => "\177\000\000\001\032\341\177\000\000\002\032\341"
      }
      @response = {
        :status => 200,
        :content => BEncode.dump(response_dict),
      }
      @http = mock('http')
      @http.stub!(:callback).and_yield(@response)
      EM::P::HttpClient.stub(:request).and_return(@http)
    end

    it 'should add peers to torrent' do
      @torrent.should_receive(:add_peers).with(["\177\000\000\001\032\341","\177\000\000\002\032\341"])
      @torrent_announce.announce
    end
  end

  context 'starting' do
    it 'should have event of "start"' do
      EM::P::HttpClient.should_receive(:request).with do |hash|
        hash[:query_string].should match(/event=start/)
      end
      @torrent_announce.start!
    end

    it 'should start a periodic timer triggering announce every 30 minutes' do
      EM.should_receive(:add_periodic_timer).with(1800)
      @torrent_announce.start!
    end
  end

  context 'stop' do
    before(:each) do
      EM.stub!(:add_periodic_timer).and_return('imasignature')
      EM.stub!(:cancel_timer)
      @torrent_announce.start!
    end

    it 'should have event of "stopped"' do
      EM::P::HttpClient.should_receive(:request).with do |hash|
        hash[:query_string].should match(/event=stopped/)
      end

      @torrent_announce.stop!
    end

    it 'should cancel announce timer' do
      EM.should_receive(:cancel_timer).with('imasignature')
      @torrent_announce.stop!
    end
  end
end
