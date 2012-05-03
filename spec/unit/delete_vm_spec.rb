# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenStackCloud::Cloud do

  it "deletes an OpenStack server" do
    server = double("server", :id => "i-foobar")

    cloud = mock_cloud do |openstack|
      openstack.servers.stub(:[]).with("i-foobar").and_return(server)
    end

    server.should_receive(:terminate)
    server.should_receive(:status).and_return(:deleting)
    cloud.should_receive(:wait_resource).with(server, :deleting, :terminated)

    cloud.delete_vm("i-foobar")
  end
end
