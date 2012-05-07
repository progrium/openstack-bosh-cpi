# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenStackCloud::Cloud do

  it "deregisters EC2 image" do
    image = double("image", :id => "i-foo")

    cloud = mock_cloud do |openstack|
      openstack.images.stub(:get).with("i-foo").and_return(image)
    end

    image.should_receive(:destroy)

    cloud.delete_stemcell("i-foo")
  end

end
