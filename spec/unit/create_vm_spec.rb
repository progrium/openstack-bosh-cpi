# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenStackCloud::Cloud, "create_vm" do

  def agent_settings(unique_name, network_spec = dynamic_network_spec)
    {
      "vm" => {
        "name" => "vm-#{unique_name}"
      },
      "agent_id" => "agent-id",
      "networks" => { "network_a" => network_spec },
      "disks" => {
        "system" => "/dev/vda",
        "ephemeral" => "/dev/vdb",
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
      :name=>"agent-id",
      :image_ref => "sc-id",
      :flavor_ref => "f-test",
      :key_name => "test_key",
      :security_groups => security_groups,
      :user_data => Yajl::Encoder.encode(user_data),
      :availability_zone => "foobar-1a"
    }
  end

  before(:each) do
    @registry = mock_registry
  end

  it "creates an OpenStack server and polls until it's ready" do
    unique_name = UUIDTools::UUID.random_create.to_s
    user_data = {
      "registry" => {
        "endpoint" => "http://registry:3333"
      },
      "agent" => {
        "id" => "agent-id"
      }
    }
    server = double("server", :id => "i-test", :name => "i-test")
    image = double("image", :id => "sc-id", :name => "sc-id")
    flavor = double("flavor", :id => "f-test", :name => "m1.tiny")
    address = double("address", :id => "a-test", :ip => "10.0.0.1", :instance_id => "i-test")

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:create).with(openstack_params(user_data)).and_return(server)
      openstack.images.should_receive(:each).and_yield(image)
      openstack.flavors.should_receive(:each).and_yield(flavor)
      openstack.addresses.should_receive(:each).and_yield(address)
    end

    cloud.should_receive(:generate_unique_name).and_return(unique_name)
    address.should_receive(:disassociate)
    server.should_receive(:state).and_return(:build)
    cloud.should_receive(:wait_resource).with(server, :build, :active, :state)

    @registry.should_receive(:update_settings).with("i-test", agent_settings(unique_name))

    vm_id = cloud.create_vm("agent-id", "sc-id",
                            resource_pool_spec,
                            { "network_a" => dynamic_network_spec },
                            nil, { "test_env" => "value" })
    vm_id.should == "i-test"
  end

  it "creates an OpenStack server with security group" do
    unique_name = UUIDTools::UUID.random_create.to_s
    user_data = {
      "registry" => {
        "endpoint" => "http://registry:3333"
      },
      "agent" => {
        "id" => "agent-id"
      }
    }
    security_groups = %w[foo bar]
    network_spec = dynamic_network_spec
    network_spec["cloud_properties"] = { "security_groups" => security_groups }
    server = double("server", :id => "i-test", :name => "i-test")
    image = double("image", :id => "sc-id", :name => "sc-id")
    flavor = double("flavor", :id => "f-test", :name => "m1.tiny")
    address = double("address", :id => "a-test", :ip => "10.0.0.1", :instance_id => nil)

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:create).with(openstack_params(user_data, security_groups)).and_return(server)
      openstack.images.should_receive(:each).and_yield(image)
      openstack.flavors.should_receive(:each).and_yield(flavor)
      openstack.addresses.should_receive(:each).and_yield(address)
    end

    cloud.should_receive(:generate_unique_name).and_return(unique_name)
    server.should_receive(:state).and_return(:build)
    cloud.should_receive(:wait_resource).with(server, :build, :active, :state)

    @registry.should_receive(:update_settings).with("i-test", agent_settings(unique_name, network_spec))

    vm_id = cloud.create_vm("agent-id", "sc-id",
                            resource_pool_spec,
                            { "network_a" => network_spec },
                            nil, { "test_env" => "value" })
    vm_id.should == "i-test"
  end

  it "associates server with floating ip if vip network is provided" do
    server = double("server", :id => "i-test", :name => "i-test")
    image = double("image", :id => "sc-id", :name => "sc-id")
    flavor = double("flavor", :id => "f-test", :name => "m1.tiny")
    address = double("address", :id => "a-test", :ip => "10.0.0.1", :instance_id => "i-test")

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:create).and_return(server)
      openstack.images.should_receive(:each).and_yield(image)
      openstack.flavors.should_receive(:each).and_yield(flavor)
      openstack.addresses.should_receive(:each).and_yield(address)
    end

    address.should_receive(:disassociate)
    address.should_receive(:associate).with(server)
    server.should_receive(:state).and_return(:build)
    cloud.should_receive(:wait_resource).with(server, :build, :active, :state)

    @registry.should_receive(:update_settings)

    vm_id = cloud.create_vm("agent-id", "sc-id",
                            resource_pool_spec,
                            combined_network_spec)
  end

end
