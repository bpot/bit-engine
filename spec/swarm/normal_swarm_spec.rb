require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Swarm" do
  def client_for(torrent_file, percent_complete)
    port = rand(55536) + 10_000
    directory = "/tmp/#{port}"
    TorrentManager.new(directory, port)
  end

  describe "two clients: new and seeder" do
    before(:each) do
      it 'should complete' do
        TestSwarm.new do |swarm|
          swarm.add_client(SIMPLE_TORRENT, 1)
          swarm.add_client(SIMPLE_TORRENT, 0)
        end
      end
    end
  end
end
