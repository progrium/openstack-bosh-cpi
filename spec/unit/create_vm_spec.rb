# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenStackCloud::Cloud, "create_vm" do

  def agent_settings(unique_name, network_spec = nil)
    {
      "vm" => {
        "name" => "vm-#{unique_name}"
      },
      "agent_id" => "agent-id",
      "networks" => { "network_a" => network_spec },
      "disks" => {
        "system" => "/dev/sda",
        "ephemeral" => "/dev/sdb",
        "persistent" => {}
      },
      "env" => {
        "test_env" => "value"
      },
      "foo" => "bar", # Agent env
      "baz" => "zaz"
    }
  end

  def openstack_params()
    {  :image_id => "bar", :flavor_id => nil }
  end

  it "creates OpenStack server and polls until it's ready" do
  end

end
