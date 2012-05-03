# Copyright (c) 2012 Piston Cloud Computing, Inc.

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile", __FILE__)

require "rubygems"
require "bundler"
Bundler.setup(:default, :test)

require "rspec"
require "tmpdir"

require "cloud/openstack"

class OpenStackConfig
  attr_accessor :db, :logger, :uuid
end

os_config = OpenStackConfig.new
os_config.db = nil # OpenStack CPI doesn't need DB
os_config.logger = Logger.new(StringIO.new)
os_config.logger.level = Logger::DEBUG

Bosh::Clouds::Config.configure(os_config)

def mock_cloud_options
  {
    "openstack" => {
      "auth_url" => "http://127.0.0.1:5000/v2.0/tokens",
      "username" => "admin",
      "api_key" => "nova",
      "tenant" => "admin"
    },
    "agent" => {
      "foo" => "bar",
      "baz" => "zaz"
    }
  }
end

def make_cloud(options = nil)
  Bosh::OpenStackCloud::Cloud.new(options || mock_cloud_options)
end

def mock_cloud(options = nil)
  servers = double("servers")
  volumes = double("volumes")

  openstack = double(Fog::Compute)

  openstack.stub(:servers).and_return(servers)
  openstack.stub(:volumes).and_return(volumes)

  Fog::Compute.stub(:new).and_return(openstack)

  yield openstack if block_given?

  Bosh::OpenStackCloud::Cloud.new(options || mock_cloud_options)
end
