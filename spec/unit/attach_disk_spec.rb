# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenStackCloud::Cloud do

  it "attaches OpenStack volume to an instance" do
    instance = double("instance", :id => "i-test")
    volume = double("volume", :id => "v-foobar")
    attachment = double("attachment", :device => "/dev/sdf")

    cloud = mock_cloud do |openstack|
      openstack.instances.should_receive(:[]).with("i-test").and_return(instance)
      openstack.volumes.should_receive(:[]).with("v-foobar").and_return(volume)
    end

    volume.should_receive(:attach_to).
      with(instance, "/dev/sdf").and_return(attachment)

    instance.should_receive(:block_device_mappings).and_return({})

    attachment.should_receive(:status).and_return(:attaching)
    cloud.should_receive(:wait_resource).with(attachment, :attaching, :attached)

    old_settings = { "foo" => "bar" }
    new_settings = {
      "foo" => "bar",
      "disks" => {
        "persistent" => {
          "v-foobar" => "/dev/sdf"
        }
      }
    }

    cloud.attach_disk("i-test", "v-foobar")
  end

  it "picks available device name" do
    instance = double("instance", :id => "i-test")
    volume = double("volume", :id => "v-foobar")
    attachment = double("attachment", :device => "/dev/sdh")

    cloud = mock_cloud do |openstack|
      openstack.instances.should_receive(:[]).with("i-test").and_return(instance)
      openstack.volumes.should_receive(:[]).with("v-foobar").and_return(volume)
    end

    instance.should_receive(:block_device_mappings).
      and_return({ "/dev/sdf" => "foo", "/dev/sdg" => "bar" })

    volume.should_receive(:attach_to).
      with(instance, "/dev/sdh").and_return(attachment)

    attachment.should_receive(:status).and_return(:attaching)
    cloud.should_receive(:wait_resource).with(attachment, :attaching, :attached)

    old_settings = { "foo" => "bar" }
    new_settings = {
      "foo" => "bar",
      "disks" => {
        "persistent" => {
          "v-foobar" => "/dev/sdh"
        }
      }
    }

    cloud.attach_disk("i-test", "v-foobar")
  end

  it "picks available device name" do
    instance = double("instance", :id => "i-test")
    volume = double("volume", :id => "v-foobar")
    attachment = double("attachment", :device => "/dev/sdh")

    cloud = mock_cloud do |openstack|
      openstack.instances.should_receive(:[]).with("i-test").and_return(instance)
      openstack.volumes.should_receive(:[]).with("v-foobar").and_return(volume)
    end

    instance.should_receive(:block_device_mappings).
      and_return({ "/dev/sdf" => "foo", "/dev/sdg" => "bar" })

    volume.should_receive(:attach_to).
      with(instance, "/dev/sdh").and_return(attachment)

    attachment.should_receive(:status).and_return(:attaching)
    cloud.should_receive(:wait_resource).with(attachment, :attaching, :attached)

    old_settings = { "foo" => "bar" }
    new_settings = {
      "foo" => "bar",
      "disks" => {
        "persistent" => {
          "v-foobar" => "/dev/sdh"
        }
      }
    }

    cloud.attach_disk("i-test", "v-foobar")
  end

  it "raises an error when sdf..sdp are all reserved" do
    instance = double("instance", :id => "i-test")
    volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |openstack|
      openstack.instances.should_receive(:[]).with("i-test").and_return(instance)
      openstack.volumes.should_receive(:[]).with("v-foobar").and_return(volume)
    end

    all_mappings = ("f".."p").inject({}) do |hash, char|
      hash["/dev/sd#{char}"] = "foo"
      hash
    end

    instance.should_receive(:block_device_mappings).
      and_return(all_mappings)

    expect {
      cloud.attach_disk("i-test", "v-foobar")
    }.to raise_error(Bosh::Clouds::CloudError, /too many disks attached/)
  end

end
