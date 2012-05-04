# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenStackCloud::Cloud do

  it "deletes an OpenStack volume" do
    volume = double("volume", :id => "v-foo", :state => :available)

    cloud = mock_cloud do |openstack|
      openstack.volumes.stub(:get).with("v-foo").and_return(volume)
    end

    volume.should_receive(:state)
    volume.should_receive(:destroy)

    cloud.should_receive(:wait_resource).with(volume, "v-foo", :available, :deleted)
    cloud.delete_disk("v-foo")
  end

  it "doesn't delete volume unless it's state is `available'" do
    volume = double("volume", :id => "v-foo", :state => :busy)

    cloud = mock_cloud do |openstack|
      openstack.volumes.stub(:get).with("v-foo").and_return(volume)
    end

    expect {
      cloud.delete_disk("v-foo")
    }.to raise_error(Bosh::Clouds::CloudError,
                     "Cannot delete volume `v-foo', state is busy")
  end

end
