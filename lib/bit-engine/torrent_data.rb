class TorrentData
  attr_reader :files,:bitfield, :piece_size
  def initialize(info_dict, data_path)
    @info_dict = info_dict
    @data_path = data_path
    @files     = []
    @piece_size= info_dict["piece length"]
    @bitfield  = BitField.new(piece_count)
    populate_file_list
    create_files_if_necessary
    mmap_files
  end

  def piece_count
    @info_dict["pieces"].length / 20
  end

  def hash!
    @complete = true

    0.upto(piece_count-1) do |piece|
      piece_sha1 = @info_dict["pieces"].slice(piece * 20, 20)
      if piece_sha1 == Digest::SHA1.digest(read_piece(piece))
        @bitfield[piece] = 1
      else
        @complete = false
      end
    end
  end

  def complete?
    @complete
  end

  # TODO this is pretty nasty
  def read_piece(piece_idx)
    global_offset = @piece_size * piece_idx
    piece = ''
    while piece.size < @piece_size
      file_hash   = find_file_for_offset(global_offset)
      file_offset = global_offset - file_hash[:piece_offset]
      size        = @piece_size - piece.size

      if size + file_offset > file_hash[:length]
        size = file_hash[:length] - file_offset
      end

      piece += file_hash[:mmap].slice(file_offset, size)

      global_offset += size

      break if file_hash[:piece_offset] + file_hash[:length] == @total_length
    end
    return piece
  end

  def received_piece(piece, data)
    piece_sha1 = @info_dict["pieces"].slice(20*piece, 20)
    if piece_sha1 == Digest::SHA1.digest(data)
      write_piece(piece, data)
      @bitfield[piece] = 1
      return true
    else
      #p "hash check failed: #{piece}"
      return false
    end
  end

  # clean this crap up and test it
  def write_piece(piece_idx, data)
    global_offset = @piece_size * piece_idx
    n = 0
    while data != ''
      file_hash = find_file_for_offset(global_offset)
      file_offset = global_offset - file_hash[:piece_offset]
      update_ending = (file_offset + data.size) - 1
      if update_ending > file_hash[:length]
        update_ending = (file_hash[:length] - 1)
      end

      data_to_write = data.slice!(0, (update_ending - file_offset) + 1)
      file_hash[:mmap][file_offset..update_ending] = data_to_write

      global_offset += data_to_write.size
      n+=1
    end
  end

  private

  def find_file_for_offset(offset)
    @files.each_with_index do |f,idx| 
      if f[:piece_offset] > offset
        return @files[idx-1]
      end
    end
    return @files.last
  end

  def populate_file_list
    if @info_dict.has_key?('files')
      @files = populate_file_list_multi
    else
      @files = populate_file_list_single
    end
  end

  def populate_file_list_multi
    offset = 0
    files = @info_dict['files'].collect do |file|
      file_path = File.join(*[@data_path, file['path']].flatten)
      file_directory = File.dirname(file_path)
      create_directory_if_necessary(file_directory)

      h = { :path => file_path, :length => file['length'], :piece_offset => offset }
      offset += file['length']
      h
    end
    @total_length = offset
    return files
  end

  def populate_file_list_single
    files = [{:path => File.join(@data_path, @info_dict['name']),
      :length => @info_dict['length'],
      :piece_offset => 0}]
    @total_length = @info_dict['length']
    return files
  end

  def create_directory_if_necessary(file_directory)
    FileUtils.mkdir_p(file_directory) unless File.exists?(file_directory)
  end

  def create_files_if_necessary
    files.each do |f|
      path = f[:path]
      length = f[:length]
      #p path
      unless File.exists?(path)
        File.new(path, 'w').close
        File.truncate(path, length)
      end
    end
  end

  def mmap_files
    @mmap_handles = {}
    files.each do |f|
      path = f[:path]
      length = f[:length]
      f[:mmap] = Mmap.new(path, "rw", Mmap::MAP_SHARED, :length => length)
    end
  end
end
