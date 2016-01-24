require 'dotenv'
Dotenv.load

require 'droplet_kit'
require 'net/ssh'
require 'curb'

class InsurgencyManager
  def initialize(digital_ocean_client)
    @client = digital_ocean_client
    @snapshot_id = get_snapshot_id()
  end

  def get_snapshot_id()
    images = @client.images.all(public:false)
    images.each do |image|
      if image.name == "insurgency-server"
        return image.id
      end
    end
  end

  def update_duckdns(new_ip)
    Curl::Easy.perform("https://www.duckdns.org/update?domains=where-napoleon-died&token=#{ENV['DUCKDNS_TOKEN']}&ip=#{new_ip}")
  end
end

im = InsurgencyManager.new(DropletKit::Client.new(access_token: ENV['DO_TOKEN']))
