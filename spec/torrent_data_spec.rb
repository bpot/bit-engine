require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'fileutils'
describe "TorrentData" do
  context 'multi-file nested torrent' do
    before(:each) do
      @info_dict = BEncode.load_file(File.dirname(__FILE__) + "/data/nested.torrent")['info']
      FileUtils.mkdir_p("/tmp/bte_test/") 
    end

    after(:each) do
      FileUtils.rm_rf("/tmp/bte_test/")
    end

    context 'creating torrent data' do
      it 'should create files' do
        TorrentData.new(@info_dict, "/tmp/bte_test/")
        File.exist?("/tmp/bte_test/dir1/file1.txt").should == true
        File.exist?("/tmp/bte_test/dir2/file1.txt").should == true
        File.exist?("/tmp/bte_test/dir3/file1.txt").should == true
      end

      it "should create mmap handles" do
        Mmap.should_receive(:new).with("/tmp/bte_test/dir1/file1.txt", "rw", Mmap::MAP_SHARED, anything)
        Mmap.should_receive(:new).with("/tmp/bte_test/dir2/file1.txt", "rw", Mmap::MAP_SHARED, anything)
        Mmap.should_receive(:new).with("/tmp/bte_test/dir3/file1.txt", "rw", Mmap::MAP_SHARED, anything)
        TorrentData.new(@info_dict, "/tmp/bte_test/")
      end
    end

    context 'hashing' do
      context 'full file' do
        before(:each) do
          FileUtils.cp_r(File.join(TEST_DATA, "nested_torrent"), "/tmp/bte_test/")
          @torrent_data = TorrentData.new(@info_dict, "/tmp/bte_test/nested_torrent")
        end

        it 'should be complete' do
          @torrent_data.hash!
          @torrent_data.complete?.should == true
        end
      end

      context 'empty file' do
        before(:each) do
          @torrent_data = TorrentData.new(@info_dict, "/tmp/bte_test/")
        end

        it 'should not be complete' do
          @torrent_data.hash!
          @torrent_data.complete?.should == false
        end
      end
    end

  end
  context 'single file torrent' do
    before(:each) do
      @info_dict = BEncode.load_file(File.dirname(__FILE__) + "/data/random.data.torrent")['info']
      FileUtils.mkdir_p("/tmp/bte_test/") 
    end

    after(:each) do
      FileUtils.rm_rf("/tmp/bte_test/")
    end

    context 'creating torrent data' do
      it "should create file" do
        TorrentData.new(@info_dict, "/tmp/bte_test/")
        File.exist?("/tmp/bte_test/random.data").should == true
      end
      
      it "should create mmap handles" do
        Mmap.should_receive(:new).with("/tmp/bte_test/random.data", "rw", Mmap::MAP_SHARED, anything)
        TorrentData.new(@info_dict, "/tmp/bte_test/")
      end
    end

    context 'torrent data' do
      before(:each) do
        @torrent_data = TorrentData.new(@info_dict, "/tmp/bte_test/")
      end

      it 'should provide the torrents piece_count' do
        @torrent_data.piece_count.should == 4
      end
       
      it "should provide a hash of files" do
        @torrent_data.files.first[:path].should == '/tmp/bte_test/random.data'
      end

      context 'hashing' do
        context 'full file' do
          before(:each) do
            FileUtils.cp(File.join(TEST_DATA, "random.data"), "/tmp/bte_test/")
            @torrent_data = TorrentData.new(@info_dict, "/tmp/bte_test/")
          end

          it 'should be complete' do
            @torrent_data.hash!
            @torrent_data.complete?.should == true
          end
        end

        context 'empty file' do
          before(:each) do
            @torrent_data = TorrentData.new(@info_dict, "/tmp/bte_test/")
          end

          it 'should not be complete' do
            @torrent_data.hash!
            @torrent_data.complete?.should == false
          end
        end
      end
    end
  end
end
