require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "TorrentView" do
  before(:each) do
    @torrent          = mock(Torrent, :name => "ubuntu-9-10.iso", :amount_completed => 0.5, :info_hash => "asdf", :uploaded => 100, :downloaded => 100, :state => 'started')
    @torrent_manager  = mock(TorrentManager, :up_rate => 10, :down_rate => 10, :torrents => [@torrent])
    @torrent_view     = TorrentView.new(@torrent_manager)
  end
  describe "summary" do
    before(:each) do
      @hash = JSON.parse(@torrent_view.summary)
    end

    it "should return the current up/down rates" do
      @hash["up_rate"].should   == @torrent_manager.up_rate
      @hash["down_rate"].should == @torrent_manager.down_rate
    end

    it "should return information about the torrents" do
      t = @hash["torrents"].first
      t["name"].should      == "ubuntu-9-10.iso"
      t["completed"].should == 0.5
    end
  end
end
