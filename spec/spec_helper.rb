$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'rubygems'
require 'bit-engine'
require 'spec'
require 'spec/autorun'

Spec::Runner.configure do |config|
  include BitEngine  
  TEST_DATA       = File.dirname(__FILE__) + "/data"
  SIMPLE_TORRENT  = File.join(TEST_DATA, "random.data.torrent")

  class StubTracker
  end

  class TestSwarm
    def initialize
      @torrents_to_finish = 0
      @successful = true
      EM.run {
        yield instance

        EM.add_timer(120) do
          @successful = false
          EM.stop_event_loop
        end
      }
      return @successful
    end

    def add_client(torrent_file, complete)
      @torrents_to_finish += 1 unless complete == 1
      port = rand(55536) + 10_000
      directory = File.join(Dir.tmpdir, port, "-bte")

      client = TorrentManager.new(directory,port)
      torrent = Torrent.new(torrent)
      client.register_torrent(torrent)
      client.on_torrent_completion do
        @finished_torrent += 1
        if @finished_torrents == @torrents_to_finish
          EM.stop_event_loop
        end
      end
    end
  end
end
