# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenStackCloud::Cloud do

  it "deletes an OpenStack volume" do
    volume = double("volume", :id => "v-foo")

    cloud = mock_cloud do |openstack|
      openstack.volumes.stub(:[]).with("v-foo").and_return(volume)
    end

    volume.should_receive(:state).and_return(:available, :deleting)
    volume.should_receive(:delete)
    cloud.should_receive(:wait_resource).with(volume, :deleting, :deleted)

    cloud.delete_disk("v-foo")
  end

  it "doesn't delete volume unless it's state is `available'" do
    volume = double("volume", :id => "v-foo", :state => :busy)

    cloud = mock_cloud do |openstack|
      openstack.volumes.stub(:[]).with("v-foo").and_return(volume)
    end

    expect {
      cloud.delete_disk("v-foo")
    }.to raise_error(Bosh::Clouds::CloudError,
                     "Cannot delete volume `v-foo', state is busy")
  end

end
