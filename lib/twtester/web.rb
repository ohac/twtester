require 'sinatra/base'
require 'json'
require 'haml'

$timeline = []
if File.exist?('timeline.bin')
  File.open('timeline.bin', 'rb') do |fd|
    $timeline = Marshal.load(fd.read)
  end
end

module TwTester
  class Web < Sinatra::Base
    enable :sessions

    helpers do
      include Rack::Utils; alias_method :h, :escape_html
    end

    CONTENT_TYPES = {
      :html => 'text/html',
      :css => 'text/css',
      :js => 'application/javascript',
      :txt => 'text/plain',
    }

    use Rack::Auth::Basic do |username, password|
      true
    end

    before do
      auth = Rack::Auth::Basic::Request.new(request.env)
      session[:user], session[:pass] = auth.credentials if auth
      request_uri =
          case request.env['REQUEST_URI']
          when /\.css$/ ; :css
          when /\.js$/ ; :js
          when /\.txt$/ ; :txt
          else :html
          end
      content_type CONTENT_TYPES[request_uri], :charset => 'utf-8'
      response.headers['Cache-Control'] = 'no-cache'
    end

    get '/' do
      haml :index, :locals => { :timeline => $timeline }
    end

    get '/rss.xml' do
      haml :rss, :locals => {  :timeline => $timeline,
          :baseurl => 'http://localhost:4567' }
    end

    get '/1/statuses/home_timeline.json' do
      $timeline.reverse.to_json
    end

    post '/1/statuses/update.json' do
      status = params['status']
      digest = Digest::MD5.hexdigest(session[:pass])
      now = Time.now
      $timeline << {
        'text' => status,
        'created_at' => now.to_s,
        'id' => now.to_i * 1000 + now.usec / 1000,
        'user' => {
          'name' => digest,
          'screen_name' => session[:user],
          'profile_image_url' => "http://www.gravatar.com/avatar/#{digest}?s=48&default=identicon",
        },
      }
      $timeline.shift if $timeline.size > 20
      File.open('timeline.bin', 'wb') do |fd|
        fd.write(Marshal.dump($timeline))
      end
      response = [
      ]
      response.to_json
    end

    get '/1/account/rate_limit_status.json' do
      {'remaining_hits' => 150}.to_json
    end
  end
end
