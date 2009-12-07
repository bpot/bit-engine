require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "PiecePicker" do
  before(:each) do
    @torrent = mock(Torrent, :piece_count => 88, :want_bitfield => BitField.new(88, [BitField::ALL_SET_VALUE] * 88))
    @piece_picker = PiecePicker.new(@torrent)
  end

  context 'we have no pieces, peer has all pieces' do
    context 'peer has all pieces' do
      it 'should find the rarest piece the peer doesnt have' do
        bf = BitField.new(@torrent.piece_count, [BitField::ALL_SET_VALUE] * 88)

        @piece_picker.add_bitfield(bf)
        @piece_picker.rarest_piece(bf).should == 0
      end
    end

    context 'peer has only 5th piece' do
      it 'should return 5' do
        bf = BitField.new(@torrent.piece_count, [0] * 88)
        bf[5] = 1

        @piece_picker.add_bitfield(bf)
        @piece_picker.rarest_piece(bf).should == 5
      end
    end

    context 'swarm with pieces 5 & 10 being rarest' do
      before(:each) do
        bf = BitField.new(@torrent.piece_count, [BitField::ALL_SET_VALUE] * 88)
        bf[5] = 0
        bf[10] = 0
        @piece_picker.add_bitfield(bf)
      end

      it 'should return 5 for peer with all pieces' do
        bf = BitField.new(@torrent.piece_count, [BitField::ALL_SET_VALUE] * 88)
        @piece_picker.rarest_piece(bf).should == 5
      end

      it 'should return 10 for peer without 5' do
        bf = BitField.new(@torrent.piece_count, [BitField::ALL_SET_VALUE] * 88)
        bf[5] = 0

        @piece_picker.rarest_piece(bf).should == 10
      end
      context 'receive a have for piece 5' do
        before(:each) do
          @piece_picker.add_piece(5)
        end

        it 'should return 10 for peer with all pieces' do
          bf = BitField.new(@torrent.piece_count, [BitField::ALL_SET_VALUE] * 88)
          @piece_picker.rarest_piece(bf).should == 10
        end
      end

      context 'peer leaves swarm' do
        it 'should return rarest piece for new availabilities' do
          leaving_bf = BitField.new(@torrent.piece_count, [BitField::ALL_SET_VALUE] * 88)
          leaving_bf[5] = 0
          staying_bf = BitField.new(@torrent.piece_count, [BitField::ALL_SET_VALUE] * 88)
          staying_bf[10] = 0
          
          @piece_picker.add_bitfield(leaving_bf)
          @piece_picker.add_bitfield(staying_bf)
          @piece_picker.remove_bitfield(leaving_bf)

          bf = BitField.new(@torrent.piece_count, [BitField::ALL_SET_VALUE] * 88)
          @piece_picker.rarest_piece(bf).should == 10 
        end
      end
    end
  end
end
