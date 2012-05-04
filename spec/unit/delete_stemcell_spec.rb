# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenStackCloud::Cloud do

  it "doesn't implement `delete_stemcell'" do
    cloud = make_cloud
    expect {
      cloud.delete_stemcell(nil)
    }.to raise_error(Bosh::Clouds::NotImplemented,
                     "`delete_stemcell' is not implemented "\
                     "by Bosh::OpenStackCloud::Cloud")
  end

end
