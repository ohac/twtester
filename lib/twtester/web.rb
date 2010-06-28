require 'sinatra/base'
require 'json'

module TwTester
  class Web < Sinatra::Base
    get '/1/statuses/home_timeline.json' do
      timeline = [
        {
          'text' => 'hello',
          'in_reply_to_status_id' => 1234,
          'user' => {
            'screen_name' => 'someone',
            'verified' => true,
            'protected' => true,
          },
        }
      ]
      timeline.to_json
    end

    post '/1/statuses/update.json' do
      status = params['status']
      p status
      response = [
      ]
      response.to_json
    end

    get '/1/account/rate_limit_status.json' do
      {'remaining_hits' => 150}.to_json
    end
  end
end
