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
        :location => "#{@tmp_dir}/root.img",
        :is_public => true,
        :properties => {
          :kernel_id => "k-id",
          :ramdisk_id => "r-id",
        }
      }

      cloud = mock_glance do |glance|
        glance.images.should_receive(:create).with(image_params).and_return(image)
      end

      Dir.should_receive(:mktmpdir).and_yield(@tmp_dir)
      cloud.should_receive(:unpack_image).with(@tmp_dir, "/tmp/foo")
      cloud.should_receive(:generate_unique_name).and_return(unique_name)
      image.should_receive(:status).and_return(:queued)
      cloud.should_receive(:wait_resource).with(image, :queued, :active)

      sc_id = cloud.create_stemcell("/tmp/foo", {
          "container_format" => "ami",
          "disk_format" => "ami",
          "properties" => {
            "kernel_id" => "k-id",
            "ramdisk_id" => "r-id"
          }
        })

      sc_id.should == "i-bar"
    end

  end

end
