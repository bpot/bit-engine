class PiecePicker
  def initialize(torrent)
    @torrent      = torrent
    @availability = [0] * @torrent.piece_count
  end

  def add_bitfield(field)
    field.each_with_index do |i,idx|
      @availability[idx] += i
    end
  end

  def remove_bitfield(field)
    field.each_with_index do |i,idx|
      @availability[idx] -= i
    end
  end

  def add_piece(piece)
    @availability[piece] += 1
  end

  # this should be quick enough for most torrents, but may have to be optimized eventually
  def rarest_piece(peer_bitfield)
    # find intersection of what the torrent wants and what the peer has
    intersection = @torrent.want_bitfield & peer_bitfield
    return nil if intersection.total_set == 0

    rarest = nil
    rarest_availability = 9999

    intersection.each_with_index do |i,idx|
      next if i == 0

      if @availability[idx] < rarest_availability
        rarest = idx
        rarest_availability = @availability[idx]
      end
    end

    rarest
  end
end
