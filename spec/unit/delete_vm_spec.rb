# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenStackCloud::Cloud do

  it "deletes an OpenStack server" do
    server = double("server", :id => "i-foobar")

    cloud = mock_cloud do |openstack|
      openstack.servers.stub(:get).with("i-foobar").and_return(server)
    end

    server.should_receive(:destroy)
    server.should_receive(:state)

    cloud.should_receive(:wait_resource).with(server, nil, :deleted)

    cloud.delete_vm("i-foobar")
  end
end
