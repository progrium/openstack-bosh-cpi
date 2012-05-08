# Copyright (c) 2012 Piston Cloud Computing, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::OpenStackCloud::Helpers do
  it "should time out" do
    cloud = mock_cloud

    resource = double("resource")
    resource.stub(:id).and_return("foobar")
    resource.stub(:reload).and_return(cloud)
    resource.stub(:status).and_return(:start)
    cloud.stub(:sleep)

    lambda {
      cloud.wait_resource(resource, :start, :stop, :status, 0.1)
    }.should raise_error Bosh::Clouds::CloudError, /Timed out/
  end

  it "should not time out" do
    cloud = mock_cloud

    resource = double("resource")
    resource.stub(:id).and_return("foobar")
    resource.stub(:reload).and_return(cloud)
    resource.stub(:status).and_return(:start, :stop)
    cloud.stub(:sleep)

    lambda {
      cloud.wait_resource(resource, :start, :stop, :status, 0.1)
    }.should_not raise_error Bosh::Clouds::CloudError
  end

end
