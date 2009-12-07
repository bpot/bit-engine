class TorrentView
  def initialize(torrent_manager)
    @torrent_client = torrent_manager
  end

  def summary
    summary = {"up_rate" => @torrent_client.up_rate,
               "down_rate" => @torrent_client.down_rate}
    torrents_summary = []
    @torrent_client.torrents.each do |t|
      torrents_summary << {"name"       => t.name,
                           "completed"  => t.amount_completed,
                           "info_hash"  => t.info_hash.unpack("H*").first,
                           "uploaded"   => t.uploaded,
                           "downloaded" => t.downloaded,
                           "state"      => t.state.to_s}
    end
    summary["torrents"] = torrents_summary
    summary.to_json
  end

  def peers(hash)
    torrent = @torrent_client.find_torrent(hash)

    peers = []
    torrent.peer_connections.each do |pc|
      peers << pc.summary
    end
    peers.to_json
  end
end
