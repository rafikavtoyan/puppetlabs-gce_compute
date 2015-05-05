require 'json'

class IntegrationSpecHelper
  def self.describe_out(resource, args)
    out, _ = describe_resource(resource, args)
    # NOTE This will throw a TypeError if `describe_resource` had no content in stdout
    return JSON.parse(out)
  end

  def self.describe_err(resource, args)
    _, err = describe_resource(resource, args)
    return err
  end

  def self.describe_resource(resource, args)
    _, stdout, stderr = Open3.popen3("gcloud compute #{resource} describe #{args} --format json")
    return stdout.gets(nil), stderr.gets(nil)
  end

  def self.apply_example(example)
    _, stdout, stderr = Open3.popen3("puppet apply examples/#{example}.pp")
    return stdout.gets(nil), stderr.gets(nil)
  end
end

RSpec.shared_examples "a resource that can be created and destroyed" do
  let(:type_name) { type.name.to_s }
  # NOTE we have to create an actual resource in order to find the gcloud provider
  let(:provider) { type.new({'name' => 'name'}).provider }
  let(:gcloud_resource_name) { provider.gcloud_resource_name }

  it "runs creates and destroys a resource" do
    expect(IntegrationSpecHelper.describe_err(gcloud_resource_name, describe_args)).to match(/ERROR: .* Could not fetch resource/)

    IntegrationSpecHelper.apply_example("#{type_name}/up")
    out = IntegrationSpecHelper.describe_out(gcloud_resource_name, describe_args)
    expected_properties.each do |property, value|
      if value.is_a? Regexp
        expect(out[property]).to match(value)
      else
        expect(out[property]).to eq(value)
      end
    end
    if defined?(other_property_expectations)
      other_property_expectations.call(out)
    end

    IntegrationSpecHelper.apply_example("#{type_name}/down")
    expect(IntegrationSpecHelper.describe_err(gcloud_resource_name, describe_args)).to match(/ERROR: .* Could not fetch resource/)
  end

  it "complains about an invalid resource" do
    _, err = IntegrationSpecHelper.apply_example("#{type_name}/bad")
    expect(err).to match(/failed/)
  end
end
