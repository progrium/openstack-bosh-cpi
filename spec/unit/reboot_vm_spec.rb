# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenStackCloud::Cloud do

  before :each do
    @instance = double("instance", :id => "i-foobar")

    @cloud = mock_cloud(mock_cloud_options) do |openstack|
      openstack.instances.stub(:[]).with("i-foobar").and_return(@instance)
    end
  end

  it "reboots an OpenStack instance (CPI call picks soft reboot)" do
    @cloud.should_receive(:soft_reboot).with(@instance)
    @cloud.reboot_vm("i-foobar")
  end

  it "soft reboots an OpenStack instance" do
    @instance.should_receive(:reboot)
    @cloud.send(:soft_reboot, @instance)
  end

  it "hard reboots an OpenStack instance" do
    @instance.should_receive(:reboot)
    @cloud.send(:hard_reboot, @instance)
  end

end
