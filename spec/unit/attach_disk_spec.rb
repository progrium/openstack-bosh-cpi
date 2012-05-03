# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenStackCloud::Cloud do

  it "attaches OpenStack volume to a server" do
    server = double("server", :id => "i-test")
    volume = double("volume", :id => "v-foobar")
    attachment = double("attachment", :device => "/dev/sdf")

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:get).with("i-test").and_return(server)
      openstack.volumes.should_receive(:get).with("v-foobar").and_return(volume)
    end

    server.should_receive(:attach_volume).with("v-foobar", "i-test", "v-foobar")

    cloud.stub(:update_agent_settings).and_return({})
    cloud.attach_disk("i-test", "v-foobar")
  end

end
