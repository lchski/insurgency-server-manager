require 'dotenv'
Dotenv.load

require 'droplet_kit'
require 'net/ssh'
require 'curb'

class InsurgencyManager
  def initialize(digital_ocean_client)
    @client = digital_ocean_client
    @snapshot_id = get_snapshot_id()
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
      droplet = DropletKit::Droplet.new(name: 'insurgency-server', region: 'tor1', size: '1gb', image: @snapshot_id)
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

  def update_duckdns(new_ip=get_vps_ip())
    Curl::Easy.perform("https://www.duckdns.org/update?domains=where-napoleon-died&token=#{ENV['DUCKDNS_TOKEN']}&ip=#{new_ip}")
  end
end

im = InsurgencyManager.new(DropletKit::Client.new(access_token: ENV['DO_TOKEN']))
