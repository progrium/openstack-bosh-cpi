# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenStackCloud::Cloud do

  it "deregisters OpenStack image with no kernel nor ramdisk associated" do
    image = double("image", :id => "i-foo", :name => "i-foo",
                   :properties => {})

    cloud = mock_glance do |glance|
      glance.images.stub(:find_by_id).with("i-foo").and_return(image)
    end

    image.should_receive(:destroy)

    cloud.delete_stemcell("i-foo")
  end

  it "deregisters OpenStack image, kernel and ramdisk" do
    image = double("image", :id => "i-foo", :name => "i-foo",
                   :properties => {"kernel_id" => "k-id", "ramdisk_id" => "r-id"})
    kernel = double("image", :id => "k-id", :properties => {"stemcell" => "i-foo"})
    ramdisk = double("image", :id => "r-id", :properties => {"stemcell" => "i-foo"})

    cloud = mock_glance do |glance|
      glance.images.stub(:find_by_id).with("i-foo").and_return(image)
      glance.images.stub(:find_by_id).with("k-id").and_return(kernel)
      glance.images.stub(:find_by_id).with("r-id").and_return(ramdisk)
    end

    kernel.should_receive(:destroy)
    ramdisk.should_receive(:destroy)
    image.should_receive(:destroy)

    cloud.delete_stemcell("i-foo")
  end

  it "deregisters OpenStack image with kernel and ramdisk not uploaded by the CPI" do
    image = double("image", :id => "i-foo", :name => "i-foo",
                   :properties => {"kernel_id" => "k-id", "ramdisk_id" => "r-id"})
    kernel = double("image", :id => "k-id", :properties => {})
    ramdisk = double("image", :id => "r-id", :properties => {})

    cloud = mock_glance do |glance|
      glance.images.stub(:find_by_id).with("i-foo").and_return(image)
      glance.images.stub(:find_by_id).with("k-id").and_return(kernel)
      glance.images.stub(:find_by_id).with("r-id").and_return(ramdisk)
    end

    image.should_receive(:destroy)

    cloud.delete_stemcell("i-foo")
  end

  it "deregisters OpenStack image with kernel and ramdisk that belongs to other stemcell" do
    image = double("image", :id => "i-foo", :name => "i-foo",
                   :properties => {"kernel_id" => "k-id", "ramdisk_id" => "r-id"})
    kernel = double("image", :id => "k-id", :properties => {"stemcell" => "i-bar"})
    ramdisk = double("image", :id => "r-id", :properties => {"stemcell" => "i-bar"})

    cloud = mock_glance do |glance|
      glance.images.stub(:find_by_id).with("i-foo").and_return(image)
      glance.images.stub(:find_by_id).with("k-id").and_return(kernel)
      glance.images.stub(:find_by_id).with("r-id").and_return(ramdisk)
    end

    image.should_receive(:destroy)

    cloud.delete_stemcell("i-foo")
  end

end
