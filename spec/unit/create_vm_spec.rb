# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenStackCloud::Cloud, "create_vm" do

  def agent_settings(unique_name, network_spec=dynamic_network_spec)
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

  def openstack_params(user_data, security_groups=[])
    {
      :image_id => "sc-id",
      :instance_type => "m3.zb",
      :user_data => Yajl::Encoder.encode(user_data),
    }
  end

  it "creates OpenStack instance and polls until it's ready" do
    unique_name = UUIDTools::UUID.random_create.to_s

    user_data = {}

    instance = double("instance",
                      :id => "i-test")

    cloud = mock_cloud do |openstack|
      openstack.instances.should_receive(:create).
        with(openstack_params(user_data)).
        and_return(instance)
    end

    instance.should_receive(:status).and_return(:pending)
    cloud.should_receive(:generate_unique_name).and_return(unique_name)
    cloud.should_receive(:wait_resource).with(instance, :pending, :running)

    vm_id = cloud.create_vm("agent-id", "sc-id",
                            resource_pool_spec,
                            { "network_a" => dynamic_network_spec },
                            nil, { "test_env" => "value" })

    vm_id.should == "i-test"
  end

end
