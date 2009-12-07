module BitEngine
  module MeasureBandwidth
    RATE_PERIOD = 5 
    def post_init
      setup_meters
      super
    end

    def receive_data data
      update_meter(data.length, @download_meter).to_s
      super
    end

    def send_data data
      update_meter(data.length, @upload_meter).to_s
      super
    end

    def up_rate
      @upload_meter[:rate] / 1024.0
    end

    def down_rate
      @download_meter[:rate] / 1024.0
    end

    private

    def setup_meters
      now = Time.now - 0.1
      @upload_meter = {
        :rate       => 0.0,
        :total      => 0,
        :ratesince  => now,
        :last       => now
      }

      @download_meter = {
        :rate       => 0.0,
        :total      => 0,
        :ratesince  => now,
        :last       => now
      }
    end

    def update_meter(amount, meter)
      now = Time.now
      meter[:total] += amount
      meter[:rate]   = (meter[:rate] * (meter[:last] - meter[:ratesince]) + amount)/(now - meter[:ratesince])
      meter[:last]   = now

      if meter[:ratesince] < now - RATE_PERIOD
        meter[:ratesince] = now - RATE_PERIOD
      end
    end
  end
end
