# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenStackCloud::Cloud do

  describe "creating via provider" do

    it "can be created using Bosh::Cloud::Provider" do
      Fog::Compute.stub(:new)
      Fog::Image.stub(:new)
      cloud = Bosh::Clouds::Provider.create(:openstack, mock_cloud_options)
      cloud.should be_an_instance_of(Bosh::OpenStackCloud::Cloud)
    end

    it "raises ArgumentError on initializing with blank options" do
    	options = Hash.new("options")
    	expect { 
    		Bosh::OpenStackCloud::Cloud.new(options)
    	}.to raise_error(ArgumentError)
    end

    it "raises ArgumentError on initializing with non Hashoptions" do
    	options = "this is a string"
    	expect { 
    		Bosh::OpenStackCloud::Cloud.new(options)
    	}.to raise_error(ArgumentError)
    end

    it "should create a Cloud Instance on giving valid params" do
      openstack = { "auth_url" => "http://localhost/",
                    "username" =>"testuser",
          				  "api_key" => "test_api_key",
          				 "tenant" => "test_tenant"
          			  }
      registry = { "endpoint" => "http://0.0.0.0",
          	       "user" => "testuser",
          	       "password" => "password"
                 }
      options = { "openstack" => openstack,
                  "registry" => registry
                }
      socket_error = false
      begin
        cloud = Bosh::OpenStackCloud::Cloud.new(options)
        rescue Excon::Errors::SocketError => e
          socket_error = true
        end
      socket_error.should be_true
    end
  end
end
