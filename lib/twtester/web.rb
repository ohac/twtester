require 'sinatra/base'
require 'json'

$timeline = []

module TwTester
  class Web < Sinatra::Base
    enable :sessions

    before do
      auth = Rack::Auth::Basic::Request.new(request.env)
      session[:user], session[:pass] = auth.credentials
    end

    get '/1/statuses/home_timeline.json' do
      $timeline.reverse.to_json
    end

    post '/1/statuses/update.json' do
      status = params['status']
      digest = Digest::MD5.hexdigest(session[:pass])
      $timeline << {
        'text' => status,
        'user' => {
          'name' => digest,
          'screen_name' => session[:user],
          'profile_image_url' => "http://www.gravatar.com/avatar/#{digest}?s=48&default=identicon",
        },
      }
      $timeline.shift if $timeline.size > 20
      response = [
      ]
      response.to_json
    end

    get '/1/account/rate_limit_status.json' do
      {'remaining_hits' => 150}.to_json
    end
  end
end
