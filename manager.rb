#!/usr/bin/env ruby

require 'dotenv'
Dotenv.load

require 'droplet_kit'
require 'net/ssh'
require 'curb'

class InsurgencyManager
  def initialize(digital_ocean_client)
    @client = digital_ocean_client
    @snapshot_id = get_snapshot_id()
    @ssh_id = get_ssh_id()
    @vps = nil

    check_for_vps_and_set_if_found()

    # If our VPS exists, do some things.
    if (@vps != nil)
      update_duckdns()
    end
  end

  def get_snapshot_id()
    images = @client.images.all(public:false)
    images.each do |image|
      if image.name == "insurgency-server"
        return image.id
      end
    end

    return false
  end

  def get_ssh_id()
    keys = @client.ssh_keys.all()
    keys.each do |key|
      if key.name == "Personal SSH Key"
        return key.id
      end
    end
  end

  def check_for_vps_and_set_if_found()
    droplets = @client.droplets.all
    droplets.each do |droplet|
      if droplet.name == "insurgency-server"
        @vps = droplet

        return true
      end
    end

    return false
  end

  def create_vps()
    if (@vps == nil)
      droplet = DropletKit::Droplet.new(name: 'insurgency-server', region: 'tor1', size: '1gb', ssh_keys: [@ssh_id], image: @snapshot_id)
      @vps = @client.droplets.create(droplet)
    end
  end

  def destroy_vps()
    if (@vps != nil)
      @client.droplets.delete(id: @vps.id)
    end
  end

  def get_vps_ip()
    return @vps.networks.v4[0].ip_address
  end

  def start_server()
    begin
      puts "Trying to set the environment variable..."
      Net::SSH.start(get_vps_ip(), 'root') do |ssh|
        ssh.exec!("echo \"INS_SERVER_IP=\"#{get_vps_ip()}\"\" >> /etc/environment")
      end
    rescue Net::SSH::HostKeyMismatch => e
      puts "The host key mismatched! Remembering and retrying."
      e.remember_host!
      retry
    end
    puts "Starting the Insurgency server..."
    Net::SSH.start(get_vps_ip(), 'insserver') do |ssh|
      output = ssh.exec!("./insserver start")
      puts output
    end
  end

  def stop_server()
    Net::SSH.start(get_vps_ip(), 'insserver') do |ssh|
      output = ssh.exec!("./insserver stop")
      puts output
    end
  end

  def restart_server()
    Net::SSH.start(get_vps_ip(), 'insserver') do |ssh|
      output = ssh.exec!("./insserver restart")
      puts output
    end
  end

  def update_duckdns(new_ip=get_vps_ip())
    Curl::Easy.perform("https://www.duckdns.org/update?domains=where-napoleon-died&token=#{ENV['DUCKDNS_TOKEN']}&ip=#{new_ip}")
  end
end

im = InsurgencyManager.new(DropletKit::Client.new(access_token: ENV['DO_TOKEN']))
im.send(ARGV[0])
