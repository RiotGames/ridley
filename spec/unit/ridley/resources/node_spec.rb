require 'spec_helper'

describe Ridley::Node do
  it_behaves_like "a Ridley Resource", Ridley::Node

  let(:connection) do
    double('conn',
      server_url: "https://api.opscode.com/organizations/vialstudios",
      validator_client: "chef-validator",
      ssh: {
        user: "reset",
        password: "lol"
      }
    )
  end

  describe "ClassMethods" do
    subject { Ridley::Node }

    describe "::bootstrap" do
      let(:boot_options) do
        {
          validator_path: fixtures_path.join("reset.pem").to_s,
          encrypted_data_bag_secret_path: fixtures_path.join("reset.pem").to_s
        }
      end

      it "bootstraps a single node" do
        pending
        subject.bootstrap(connection, "33.33.33.10", boot_options)
      end

      it "bootstraps multiple nodes" do
        pending
        subject.bootstrap(connection, "33.33.33.10", "33.33.33.11", boot_options)
      end
    end
  end

  subject { Ridley::Node.new(connection) }

  describe "#override=" do
    context "given a Hash" do
      it "returns a HashWithIndifferentAccess" do
        subject.override = {
          "key" => "value"
        }

        subject.override.should be_a(HashWithIndifferentAccess)
      end
    end
  end

  describe "#automatic=" do
    context "given a Hash" do
      it "returns a HashWithIndifferentAccess" do
        subject.automatic = {
          "key" => "value"
        }

        subject.automatic.should be_a(HashWithIndifferentAccess)
      end
    end
  end

  describe "#normal=" do
    context "given a Hash" do
      it "returns a HashWithIndifferentAccess" do
        subject.normal = {
          "key" => "value"
        }

        subject.normal.should be_a(HashWithIndifferentAccess)
      end
    end
  end

  describe "#default=" do
    context "given a Hash" do
      it "returns a HashWithIndifferentAccess" do
        subject.default = {
          "key" => "value"
        }

        subject.default.should be_a(HashWithIndifferentAccess)
      end
    end
  end

  describe "#set_attribute" do
    it "returns a HashWithIndifferentAccess" do
      subject.set_attribute('deep.nested.item', true).should be_a(HashWithIndifferentAccess)
    end

    it "sets an normal node attribute at the nested path" do
       subject.set_attribute('deep.nested.item', true)

       subject.normal.should have_key("deep")
       subject.normal["deep"].should have_key("nested")
       subject.normal["deep"]["nested"].should have_key("item")
       subject.normal["deep"]["nested"]["item"].should be_true
    end

    context "when the normal attribute is already set" do
      it "test" do
        subject.normal = {
          deep: {
            nested: {
              item: false
            }
          }
        }
        subject.set_attribute('deep.nested.item', true)
        
        subject.normal["deep"]["nested"]["item"].should be_true
      end
    end
  end

  describe "#cloud?" do
    it "returns true if the cloud automatic attribute is set" do
      subject.automatic = {
        "cloud" => Hash.new
      }

      subject.cloud?.should be_true
    end

    it "returns false if the cloud automatic attribute is not set" do
      subject.automatic.delete(:cloud)

      subject.cloud?.should be_false
    end
  end

  describe "#eucalyptus?" do
    it "returns true if the node is a cloud node using the eucalyptus provider" do
      subject.automatic = {
        "cloud" => {
          "provider" => "eucalyptus"
        }
      }

      subject.eucalyptus?.should be_true
    end

    it "returns false if the node is not a cloud node" do
      subject.automatic.delete(:cloud)

      subject.eucalyptus?.should be_false
    end

    it "returns false if the node is a cloud node but not using the eucalyptus provider" do
      subject.automatic = {
        "cloud" => {
          "provider" => "ec2"
        }
      }

      subject.eucalyptus?.should be_false
    end
  end

  describe "#ec2?" do
    it "returns true if the node is a cloud node using the ec2 provider" do
      subject.automatic = {
        "cloud" => {
          "provider" => "ec2"
        }
      }

      subject.ec2?.should be_true
    end

    it "returns false if the node is not a cloud node" do
      subject.automatic.delete(:cloud)

      subject.ec2?.should be_false
    end

    it "returns false if the node is a cloud node but not using the ec2 provider" do
      subject.automatic = {
        "cloud" => {
          "provider" => "rackspace"
        }
      }

      subject.ec2?.should be_false
    end
  end

  describe "#rackspace?" do
    it "returns true if the node is a cloud node using the rackspace provider" do
      subject.automatic = {
        "cloud" => {
          "provider" => "rackspace"
        }
      }

      subject.rackspace?.should be_true
    end

    it "returns false if the node is not a cloud node" do
      subject.automatic.delete(:cloud)

      subject.rackspace?.should be_false
    end

    it "returns false if the node is a cloud node but not using the rackspace provider" do
      subject.automatic = {
        "cloud" => {
          "provider" => "ec2"
        }
      }

      subject.rackspace?.should be_false
    end
  end

  describe "#cloud_provider" do
    it "returns the cloud provider if the node is a cloud node" do
      subject.automatic = {
        "cloud" => {
          "provider" => "ec2"
        }
      }

      subject.cloud_provider.should eql("ec2")
    end

    it "returns nil if the node is not a cloud node" do
      subject.automatic.delete(:cloud)

      subject.cloud_provider.should be_nil
    end
  end

  describe "#public_ipv4" do
    it "returns the public ipv4 address if the node is a cloud node" do
      subject.automatic = {
        "cloud" => {
          "provider" => "ec2",
          "public_ipv4" => "10.0.0.1"
        }
      }

      subject.public_ipv4.should eql("10.0.0.1")
    end

    it "returns the ipaddress if the node is not a cloud node" do
      subject.automatic = {
        "ipaddress" => "192.168.1.1"
      }
      subject.automatic.delete(:cloud)

      subject.public_ipv4.should eql("192.168.1.1")
    end
  end

  describe "#public_hostname" do
    it "returns the public hostname if the node is a cloud node" do
      subject.automatic = {
        "cloud" => {
          "public_hostname" => "reset.cloud.riotgames.com"
        }
      }

      subject.public_hostname.should eql("reset.cloud.riotgames.com")
    end

    it "returns the FQDN if the node is not a cloud node" do
      subject.automatic = {
        "fqdn" => "reset.internal.riotgames.com"
      }
      subject.automatic.delete(:cloud)

      subject.public_hostname.should eql("reset.internal.riotgames.com")
    end
  end

  describe "#chef_solo" do
    pending
  end

  describe "#chef_client" do
    pending
  end
end
