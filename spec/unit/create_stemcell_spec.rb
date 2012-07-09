# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenStackCloud::Cloud do

  before :each do
    @tmp_dir = Dir.mktmpdir
  end

  describe "Image upload based flow" do

    it "creates stemcell by uploading an image via Glance" do
      image = double("image", :id => "i-bar", :name => "i-bar")
      unique_name = UUIDTools::UUID.random_create.to_s
      image_params = {
        :name => "BOSH-#{unique_name}",
        :disk_format => "ami",
        :container_format => "ami",
        :properties => {
          :kernel_id => "k-id",
          :ramdisk_id => "r-id",
        },
        :location => "#{@tmp_dir}/root.img",
        :is_public => true
      }

      cloud = mock_glance do |glance|
        glance.images.should_receive(:create).with(image_params).and_return(image)
      end

      Dir.should_receive(:mktmpdir).and_yield(@tmp_dir)
      cloud.should_receive(:unpack_image).with(@tmp_dir, "/tmp/foo")
      cloud.should_receive(:generate_unique_name).and_return(unique_name)
      image.should_receive(:status).and_return(:queued)
      cloud.should_receive(:wait_resource).with(image, :queued, :active)

      sc_id = cloud.create_stemcell_using_upload("/tmp/foo",
                                                 {"kernel_id" => "k-id", "ramdisk_id" => "r-id"})
      sc_id.should == "i-bar"
    end

  end

  describe "Volume based flow" do

    it "creates stemcell by copying an image to a new volume" do
      unique_name = UUIDTools::UUID.random_create.to_s
      server = double("server", :id => "i-current", :name => "i-current")
      volume = double("volume", :id => "v-foobar")
      volume_attachments1 = double("body", :body => {"volumeAttachments" => []})
      volume_attachments2 = double("body", :body => {"volumeAttachments" => [{"volumeId" => "v-foobar"}]})
      snapshot = double("snapshot", :id => "s-foobar")

      cloud = mock_cloud do |openstack|
        openstack.servers.should_receive(:all).and_return(server)
        openstack.volumes.should_receive(:get).and_return(volume, volume)
        openstack.should_receive(:get_server_volumes).and_return(volume_attachments1, volume_attachments2)
        openstack.snapshots.should_receive(:create).and_return(snapshot)
      end

      cloud.stub(:current_server_id).and_return("i-current")
      server.should_receive(:empty?).and_return(false)
      server.should_receive(:first).and_return(server)
      cloud.should_receive(:create_disk).with(2048, "i-current").and_return("v-foobar")
      volume.should_receive(:attach).with(server.id, "/dev/vdc").and_return("/dev/vdc")
      volume.should_receive(:status).and_return(:available)
      cloud.should_receive(:wait_resource).with(volume, :available, :"in-use")
      cloud.stub(:sleep)
      File.stub(:blockdev?).with("/dev/vdc").and_return(false, false, true)
      File.stub(:blockdev?).with("/dev/xvdc").and_return(false, false)
      cloud.should_receive(:copy_root_image).with("/tmp/foo", "/dev/vdc")
      snapshot.should_receive(:status).and_return(:queued)
      cloud.should_receive(:wait_resource).with(snapshot, :queued, :available)

      volume.should_receive(:status).and_return(:"in-use")
      volume.should_receive(:detach).with(server.id, "v-foobar").and_return(true)
      cloud.should_receive(:wait_resource).with(volume, :"in-use", :available)

      volume.should_receive(:status).and_return(:available)
      volume.should_receive(:destroy)
      cloud.should_receive(:wait_resource).with(volume, :available, :deleted)

      expect {
        sc_id = cloud.create_stemcell_using_volume("/tmp/foo", {})
      }.to raise_error(Bosh::Clouds::CloudError, "Creating a stemcell from a volume is not supported by OpenStack CPI")
    end

  end

end
