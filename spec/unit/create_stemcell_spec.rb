# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenStackCloud::Cloud do

  before :each do
    @tmp_dir = Dir.mktmpdir
  end

  describe "Image upload based flow" do

    it "creates stemcell by uploading an image without kernel nor ramdisk" do
      image = double("image", :id => "i-bar", :name => "i-bar")
      unique_name = UUIDTools::UUID.random_create.to_s
      image_params = {
        :name => "BOSH-#{unique_name}",
        :disk_format => "ami",
        :container_format => "ami",
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

      sc_id = cloud.create_stemcell("/tmp/foo", {
        "container_format" => "ami",
        "disk_format" => "ami"
      })

      sc_id.should == "i-bar"
    end

    it "creates stemcell by uploading an image using kernel and ramdisk id's" do
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
        "kernel_id" => "k-id",
        "ramdisk_id" => "r-id",
        "kernel_file" => "kernel.img",
        "ramdisk_file" => "initrd.img"
      })

      sc_id.should == "i-bar"
    end

    it "creates stemcell by uploading image, kernel and ramdisk" do
      image = double("image", :id => "i-bar", :name => "i-bar")
      kernel = double("image", :id => "k-img-id", :name => "k-img-id")
      ramdisk = double("image", :id => "r-img-id", :name => "r-img-id")
      unique_name = UUIDTools::UUID.random_create.to_s
      kernel_params = {
        :name => "BOSH-#{unique_name}-AKI",
        :disk_format => "aki",
        :container_format => "aki",
        :location => "#{@tmp_dir}/kernel.img",
        :properties => {
          :stemcell => "BOSH-#{unique_name}",
        }
      }
      ramdisk_params = {
        :name => "BOSH-#{unique_name}-ARI",
        :disk_format => "ari",
        :container_format => "ari",
        :location => "#{@tmp_dir}/initrd.img",
        :properties => {
          :stemcell => "BOSH-#{unique_name}",
        }
      }
      image_params = {
        :name => "BOSH-#{unique_name}",
        :disk_format => "ami",
        :container_format => "ami",
        :location => "#{@tmp_dir}/root.img",
        :is_public => true,
        :properties => {
          :kernel_id => "k-img-id",
          :ramdisk_id => "r-img-id",
        }
      }

      cloud = mock_glance do |glance|
        glance.images.should_receive(:create).with(kernel_params).and_return(kernel)
        glance.images.should_receive(:create).with(ramdisk_params).and_return(ramdisk)
        glance.images.should_receive(:create).with(image_params).and_return(image)
      end

      Dir.should_receive(:mktmpdir).and_yield(@tmp_dir)
      cloud.should_receive(:unpack_image).with(@tmp_dir, "/tmp/foo")
      File.stub(:exists?).and_return(true)
      cloud.should_receive(:generate_unique_name).and_return(unique_name)
      kernel.should_receive(:status).and_return(:queued)
      cloud.should_receive(:wait_resource).with(kernel, :queued, :active)
      ramdisk.should_receive(:status).and_return(:queued)
      cloud.should_receive(:wait_resource).with(ramdisk, :queued, :active)
      image.should_receive(:status).and_return(:queued)
      cloud.should_receive(:wait_resource).with(image, :queued, :active)

      sc_id = cloud.create_stemcell("/tmp/foo", {
        "container_format" => "ami",
        "disk_format" => "ami",
        "kernel_file" => "kernel.img",
        "ramdisk_file" => "initrd.img"
      })

      sc_id.should == "i-bar"
    end

    it "creates stemcell using name and version cloud_properties" do
      image = double("image", :id => "i-bar", :name => "i-bar")
      kernel = double("image", :id => "k-img-id", :name => "k-img-id")
      ramdisk = double("image", :id => "r-img-id", :name => "r-img-id")
      kernel_params = {
        :name => "bosh-stemcell-x.y.z-AKI",
        :disk_format => "aki",
        :container_format => "aki",
        :location => "#{@tmp_dir}/kernel.img",
        :properties => {
          :stemcell => "bosh-stemcell-x.y.z",
        }
      }
      ramdisk_params = {
        :name => "bosh-stemcell-x.y.z-ARI",
        :disk_format => "ari",
        :container_format => "ari",
        :location => "#{@tmp_dir}/initrd.img",
        :properties => {
          :stemcell => "bosh-stemcell-x.y.z",
        }
      }
      image_params = {
        :name => "bosh-stemcell-x.y.z",
        :disk_format => "ami",
        :container_format => "ami",
        :location => "#{@tmp_dir}/root.img",
        :is_public => true,
        :properties => {
          :kernel_id => "k-img-id",
          :ramdisk_id => "r-img-id",
        }
      }

      cloud = mock_glance do |glance|
        glance.images.should_receive(:create).with(kernel_params).and_return(kernel)
        glance.images.should_receive(:create).with(ramdisk_params).and_return(ramdisk)
        glance.images.should_receive(:create).with(image_params).and_return(image)
      end

      Dir.should_receive(:mktmpdir).and_yield(@tmp_dir)
      cloud.should_receive(:unpack_image).with(@tmp_dir, "/tmp/foo")
      File.stub(:exists?).and_return(true)
      kernel.should_receive(:status).and_return(:queued)
      cloud.should_receive(:wait_resource).with(kernel, :queued, :active)
      ramdisk.should_receive(:status).and_return(:queued)
      cloud.should_receive(:wait_resource).with(ramdisk, :queued, :active)
      image.should_receive(:status).and_return(:queued)
      cloud.should_receive(:wait_resource).with(image, :queued, :active)

      sc_id = cloud.create_stemcell("/tmp/foo", {
        "name" => "bosh-stemcell",
        "version" => "x.y.z",
        "container_format" => "ami",
        "disk_format" => "ami",
        "kernel_file" => "kernel.img",
        "ramdisk_file" => "initrd.img"
      })

      sc_id.should == "i-bar"
    end

  end

end
