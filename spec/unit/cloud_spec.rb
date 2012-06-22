# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenStackCloud::Cloud do

  describe "creating via provider" do

    it "can be created using Bosh::Cloud::Provider" do
      Fog::Compute.stub(:new)
      Fog::Image.stub(:new)
      cloud = Bosh::Clouds::Provider.create(:openstack, mock_cloud_options)
      cloud.should be_an_instance_of(Bosh::OpenStackCloud::Cloud)
    end

  end


  internal_to Bosh::OpenStackCloud::Cloud do

    it "should not find stemcell-copy" do
      Fog::Compute.stub(:new)
      Fog::Image.stub(:new)
      cloud = Bosh::Clouds::Provider.create(:openstack, mock_cloud_options)
      cloud.has_stemcell_copy("/usr/bin:/usr/sbin").should be_nil
    end

    it "should find stemcell-copy" do
      Fog::Compute.stub(:new)
      Fog::Image.stub(:new)
      cloud = Bosh::Clouds::Provider.create(:openstack, mock_cloud_options)
      path = ENV["PATH"]
      path += ":#{File.expand_path('../../assets', __FILE__)}"
      cloud.has_stemcell_copy(path).should_not be_nil
    end

  end

end
