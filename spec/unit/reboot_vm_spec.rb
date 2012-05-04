# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenStackCloud::Cloud do

  it "reboots an OpenStack server (CPI call picks soft reboot)" do
    server = double("server", :id => "i-foobar")

    cloud = mock_cloud(mock_cloud_options) do |openstack|
      openstack.servers.stub(:get).with("i-foobar").and_return(server)
    end

    cloud.should_receive(:soft_reboot).with(server)
    cloud.reboot_vm("i-foobar")
  end

  it "soft reboots an OpenStack server" do
    server = double("server", :id => "i-foobar")

    cloud = mock_cloud(mock_cloud_options) do |openstack|
      openstack.servers.stub(:get).with("i-foobar").and_return(server)
    end

    server.should_receive(:state)
    server.should_receive(:reboot)

    cloud.send(:soft_reboot, server)
  end

  it "hard reboots an OpenStack server" do
    server = double("server", :id => "i-foobar")

    cloud = mock_cloud(mock_cloud_options) do |openstack|
      openstack.servers.stub(:get).with("i-foobar").and_return(server)
    end

    server.should_receive(:state)
    server.should_receive(:reboot)

    cloud.send(:hard_reboot, server)
  end

end
