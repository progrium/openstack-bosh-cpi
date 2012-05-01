# Copyright (c) 2012 Piston Cloud Computing, Inc.

module Bosh
  module OpenStackCloud; end
end

require "fog"
require "httpclient"
require "pp"
require "set"
require "tmpdir"
require "uuidtools"
require "yajl"

require "common/thread_pool"
require "common/thread_formatter"

require "cloud"
require "cloud/openstack/helpers"
require "cloud/openstack/cloud"
require "cloud/openstack/version"

module Bosh
  module Clouds
    OpenStack = Bosh::OpenStackCloud::Cloud
  end
end
