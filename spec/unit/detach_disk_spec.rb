# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenStackCloud::Cloud do

  it "detaches OpenStack volume from a server" do
    server = double("server", :id => "i-test")
    volume = double("volume", :id => "v-foobar")
    attachment = double("attachment", :device => "/dev/sdf")

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:[]).with("i-test").and_return(server)
      openstack.volumes.should_receive(:[]).with("v-foobar").and_return(volume)
    end

    mappings = {
      "/dev/sdf" => mock("attachment",
                         :volume => mock("volume", :id => "v-foobar")),
      "/dev/sdg" => mock("attachment",
                         :volume => mock("volume", :id => "v-deadbeef")),
    }

    server.should_receive(:block_device_mappings).and_return(mappings)
    volume.should_receive(:detach_from).with(server, "/dev/sdf").and_return(attachment)
    attachment.should_receive(:status).and_return(:detaching)
    cloud.should_receive(:wait_resource).with(attachment, :detaching, :detached)

    old_settings = {
      "foo" => "bar",
      "disks" => {
        "persistent" => {
          "v-foobar" => "/dev/sdf",
          "v-deadbeef" => "/dev/sdg"
        }
      }
    }

    new_settings = {
      "foo" => "bar",
      "disks" => {
        "persistent" => {
          "v-deadbeef" => "/dev/sdg"
        }
      }
    }

    cloud.detach_disk("i-test", "v-foobar")
  end

end
