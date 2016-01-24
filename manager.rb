require 'dotenv'
Dotenv.load

require 'droplet_kit'
require 'net/ssh'

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
end

im = InsurgencyManager.new(DropletKit::Client.new(access_token: ENV['DO_TOKEN']))
