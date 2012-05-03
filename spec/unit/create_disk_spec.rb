# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenStackCloud::Cloud do

  it "creates an OpenStack volume" do
    disk_params = {
      :size => 2,
    }

    volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |openstack|
      openstack.volumes.should_receive(:create).with(disk_params).and_return(volume)
    end

    volume.should_receive(:state).and_return(:creating)
    cloud.should_receive(:wait_resource).with(volume, :creating, :available)

    cloud.create_disk(2048).should == "v-foobar"
  end

  it "rounds up disk size" do
    disk_params = {
      :size => 3,
    }

    volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |openstack|
      openstack.volumes.should_receive(:create).with(disk_params).and_return(volume)
    end

    volume.should_receive(:state).and_return(:creating)
    cloud.should_receive(:wait_resource).with(volume, :creating, :available)

    cloud.create_disk(2049)
  end

end
