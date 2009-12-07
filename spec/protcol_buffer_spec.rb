require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "ProtcolBuffer" do
  INFO_HASH = "acbde" * 4
  PEER_ID   = "hello" * 4

  before(:each) do
    @pb = ProtocolBuffer.new
  end

  context 'incoming data' do
    context 'receiving handshake' do
      it "should have an incoming handshake message" do
        @pb << "\023BitTorrent protocol\000\000\000\000\000\000\000\000#{INFO_HASH}#{PEER_ID}"
        @pb.incoming_messages.first.should == [BTMessage::HANDSHAKE, 19, 'BitTorrent protocol',0,0,0,0,0,0,0,0, INFO_HASH, PEER_ID]
      end

      it "should have no incoming message for a partial handshake" do
        @pb << "\023BitTorrent protocol\000\000\000\000\000\000\000\000#{INFO_HASH}"
        @pb.incoming_messages.empty?.should be_true
      end
    end

    context 'handshaked connection' do
      before(:each) do
        @pb << "\023BitTorrent protocol\000\000\000\000\000\000\000\000#{INFO_HASH}#{PEER_ID}"
        @pb.incoming_messages
      end

      it "should handle keep alive messages" do
        10.times { @pb << "\000\000\000\000" }

        incoming_messages = @pb.incoming_messages
        incoming_messages.size.should == 10
        incoming_messages.first.should == [BTMessage::KEEP_ALIVE]
      end

      it 'should handle choke messages' do
        @pb << "\000\000\000\001\000"
        @pb.incoming_messages.first.should == [BTMessage::CHOKE]
      end

      it 'should handle unchoke messages' do
        @pb << "\000\000\000\001\001"
        @pb.incoming_messages.first.should == [BTMessage::UNCHOKE]
      end

      it 'should handle interested messages' do
        @pb << "\000\000\000\001\002"
        @pb.incoming_messages.first.should == [BTMessage::INTERESTED]
      end

      it 'should handle uninterested messages' do
        @pb << "\000\000\000\001\003"
        @pb.incoming_messages.first.should == [BTMessage::UNINTERESTED]
      end

      it 'should handle have messages' do
        @pb << "\000\000\000\005\004\000\000\000\f"
        @pb.incoming_messages.first.should == [BTMessage::HAVE, 12]
      end

      it 'should handle bitfield messages' do
        @pb << "\000\000\000\020\005\000\000\000\000\000\000\000\000\000\000\000\000\000\000\200"
        @pb.incoming_messages.first.should == [BTMessage::BITFIELD, "\000\000\000\000\000\000\000\000\000\000\000\000\000\000\200"]
      end

      it 'should handle request messages' do
        @pb << "\000\000\000\r\006\000\000\000\f\000\000\000\002\000\000@\000"
        @pb.incoming_messages.first.should == [BTMessage::REQUEST, 12,2,16*1024]
      end

      it 'should handle piece messages' do
        data  = "\000" * (2**14)
        @pb << "\000\000@\t\a\000\000\000\000\000\000\000\000" + data
        @pb.incoming_messages.first.should == [BTMessage::PIECE, 0,0, data]
      end

      it 'should handle cancel messages' do
        @pb << "\000\000\000\r\b\000\000\000\f\000\000\000\002\000\000@\000"
        @pb.incoming_messages.first.should == [BTMessage::CANCEL, 12,2,16*1024]
      end
    end
  end
end
