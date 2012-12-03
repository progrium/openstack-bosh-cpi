# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.dirname(__FILE__) + "/lib/cloud/openstack/version"

Gem::Specification.new do |s|
  s.name         = "bosh_openstack_cpi"
  s.version      = Bosh::OpenStackCloud::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = "BOSH OpenStack CPI"
  s.description  = s.summary
  s.author       = "Piston Cloud Computing"
  s.email        = "info@pistoncloud.com"
  s.homepage     = "http://www.pistoncloud.com"

  s.files        = `git ls-files -- bin/* lib/*`.split("\n") + %w(README.md Rakefile)
  s.test_files   = `git ls-files -- spec/*`.split("\n")
  s.require_path = "lib"
  s.bindir       = "bin"
  s.executables  = %w(bosh_openstack_console)

  s.add_dependency "fog", ">=1.6.0"
  s.add_dependency "bosh_common", ">=0.5.1"
  s.add_dependency "bosh_cpi", ">=0.4.4"
  s.add_dependency "httpclient", ">=2.2.0"
  s.add_dependency "uuidtools", ">=2.1.2"
  s.add_dependency "yajl-ruby", ">=0.8.2"
end
