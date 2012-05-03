# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenStackCloud::Cloud do

  it "deletes an OpenStack instance" do
    instance = double("instance", :id => "i-foobar")

    cloud = mock_cloud do |openstack|
      openstack.instances.stub(:[]).with("i-foobar").and_return(instance)
    end

    instance.should_receive(:terminate)
    instance.should_receive(:status).and_return(:deleting)
    cloud.should_receive(:wait_resource).with(instance, :deleting, :terminated)

    cloud.delete_vm("i-foobar")
  end
end
