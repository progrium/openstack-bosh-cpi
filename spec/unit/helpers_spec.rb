# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenStackCloud::Helpers do
  it "should time out" do
  end

  it "should not time out" do
    cloud = mock_cloud

    resource = double("resource")
    resource.stub(:status).and_return(:start, :stop)
    cloud.stub(:sleep)

    lambda {
      cloud.wait_resource(resource, :start, :stop, :status, 0.1)
    }.should_not raise_error Bosh::Clouds::CloudError
  end

  it "should raise error when target state is wrong" do
  end
end
