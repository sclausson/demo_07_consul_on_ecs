#!/usr/bin/env ruby
require 'trollop'
require 'aws-cfn-resources'

@opts = Trollop::options do
  opt :keyname, "Name of the keypair for SSH access", :type => String, :required => true, :short => "k"
  opt :stackname, "Name of this CFN stack we are creating now", :type => String, :required => true, :short => "s"
  opt :vpc_stackname, "Name of the CFN stack used when creating the VPC", :type => String, :required => true, :short => "v"
  opt :template, "Name of the CFN template file", :type => String, :required => true, :short => "t"
  opt :region, "AWS region where the stack will be created", :type => String, :required => true, :short => "r"
  opt :cluster_size, "Size of the ECS cluster", :type => String, :default => "1"
  opt :source_cidr, "Optional - CIDR/IP range for ECS instance outside access - defaults to 0.0.0.0/0", :type => String, :default => "0.0.0.0/0"
  opt :http_passwd, "The HTTP password for access to the Consul GUI", :type => String
end

AWS.config(region: @opts[:region])
cfn = AWS::CloudFormation.new

def ip_plus_two(cidr_block)
  network = cidr_block[/[^\/]+/]
  octets = network.split('.')
  plus_two = octets[3].to_i + 2
  octets[3] = plus_two
  octets.join('.')
end

vpc_stack = cfn.stacks[@opts[:vpc_stackname]]
vpc = vpc_stack.vpc('VPC')
@vpc_id = vpc.id 
subnet = vpc_stack.subnet('Az1PublicSubnet')
@subnet_id = subnet.id
@availability_zone_name = subnet.availability_zone_name
@dns_ip = ip_plus_two(vpc.cidr_block)

def parameters
  parameters = {
    "KeyName"               => @opts[:keyname],
    "ClusterSize"           => @opts[:cluster_size],
    "SourceCidr"            => @opts[:source_cidr],
    "HttpPassword"          => @opts[:http_passwd],
    "VPC"                   => @vpc_id,
    "SubnetId"              => @subnet_id,
    "AZ"                    => @availability_zone_name,
    "AmazonDnsIp"           => @dns_ip
  }
  return parameters
end

puts parameters

def template
  file = "./templates/#{@opts[:template]}"
  body = File.open(file, "r").read
  return body
end

cfn.stacks.create(@opts[:stackname], template, parameters: parameters, capabilities: ["CAPABILITY_IAM"])

print "Waiting for stack #{@opts[:stackname]} to complete"

until cfn.stacks[@opts[:stackname]].status == "CREATE_COMPLETE"
  print "."
  sleep 5
end