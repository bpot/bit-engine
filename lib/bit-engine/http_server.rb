require 'thin'
require 'sinatra/base'
class HttpApp < Sinatra::Base
  attr_accessor :tv,:torrent_manager
  set :dump_errors, true

  get '/torrents' do
    body @tv.summary
  end

  post "/torrents" do
    if File.exists?(params["path"])
      @torrent = Torrent.new(@torrent_manager, params["path"])
      "Added"
    else
      "Not Found"
    end
  end

  put "/torrent/:hash" do
    info_hash = [params[:hash]].pack("H*")
    torrent = @torrent_manager.find_torrent(info_hash)
    case params["action"]
    when 'start'
      torrent.start!
    when 'stop'
      torrent.stop!
    end
  end

  get "/torrent/:hash/peers" do
    info_hash = [params[:hash]].pack("H*")
    body @tv.peers(info_hash)
  end

  get "/torrent/:id/files" do
  end
end

class HttpServer
  def initialize(torrent_manager)
    @torrent_manager = torrent_manager
  end

  # HACK Rack::Builder uses instance_eval for it's blocks
  # so any application has to be available in the global
  # scope
  def start!(port = 8080)
    $app = HttpApp.new do |app|
      app.torrent_manager = @torrent_manager
      app.tv              = TorrentView.new(@torrent_manager)
    end
    Thin::Server.start('127.0.0.1', port) do
      map '/' do
        run $app
      end
    end
  end
end
