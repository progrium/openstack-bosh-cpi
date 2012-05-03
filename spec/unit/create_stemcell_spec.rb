# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenStackCloud::Cloud do

  it "doesn't implement `create_stemcell'" do
    cloud = make_cloud
    expect {
      cloud.create_stemcell(nil, nil)
    }.to raise_error(Bosh::Clouds::NotImplemented,
                     "`create_stemcell' is not implemented "\
                     "by Bosh::OpenStackCloud::Cloud")
  end

end
