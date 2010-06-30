require 'sinatra/base'
require 'json'
require 'haml'
require 'fileutils'

$timeline = []
if File.exist?('timeline.bin')
  File.open('timeline.bin', 'rb') do |fd|
    $timeline = Marshal.load(fd.read)
  end
end
FileUtils.mkdir_p('tweets')

module TwTester
  class Web < Sinatra::Base
    enable :sessions

    helpers do
      include Rack::Utils; alias_method :h, :escape_html

      def protected!
        unless authorized?
          response['WWW-Authenticate'] = %(Basic realm="TwTester HTTP Auth")
          throw(:halt, [401, "Not authorized\n"])
        end
      end

      def authorized?
        @auth ||= Rack::Auth::Basic::Request.new(request.env)
        @auth.provided? && @auth.basic? && @auth.credentials
      end

      def post_tweet(text, account)
        digest = Digest::MD5.hexdigest(account[:pass])
        now = Time.now
        tid = now.to_i * 1000 + now.usec / 1000
        tweet = {
          'text' => text,
          'created_at' => now.to_s,
          'id' => tid,
          'user' => {
            'name' => digest,
            'screen_name' => account[:user],
            'profile_image_url' => "http://www.gravatar.com/avatar/#{digest}?s=48&default=identicon",
          },
        }
        $timeline << tweet
        $timeline.shift if $timeline.size > 20
        File.open("tweets/#{tid}.bin", 'wb') do |fd|
          fd.write(Marshal.dump(tweet))
        end
        File.open('timeline.bin', 'wb') do |fd|
          fd.write(Marshal.dump($timeline))
        end
      end
    end

    CONTENT_TYPES = {
      :html => 'text/html',
      :css => 'text/css',
      :js => 'application/javascript',
      :txt => 'text/plain',
    }

    before do
      session[:user], session[:pass] = @auth.credentials if @auth
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
      haml :index, :locals => { :timeline => $timeline, :user => session[:user] }
    end

    post '/login' do
      session[:user] = params['user']
      session[:pass] = params['pass']
      redirect '/'
    end

    get '/logout' do
      session[:user] = nil
      session[:pass] = nil
      redirect '/'
    end

    get '/:screen_name/status/:tid' do |screen_name, tid|
      tweet = File.open("tweets/#{tid}.bin", 'rb') do |fd|
        Marshal.load(fd.read)
      end
      haml :tweet, :locals => { :tid => tid, :tweet => tweet }
    end

    post '/update' do
      account = session
      unless account[:user]
        pass = request.env['REMOTE_ADDR']
        digest = Digest::MD5.hexdigest(pass)
        account = { :user => "anonym_#{digest[0,4]}", :pass => pass }
      end
      post_tweet(params['status'], account)
      redirect '/'
    end

    get '/rss.xml' do
      haml :rss, :locals => {  :timeline => $timeline,
          :baseurl => 'http://localhost:4567' }
    end

    get '/1/statuses/public_timeline.json' do
      $timeline.reverse.to_json
    end

    get '/1/statuses/home_timeline.json' do
      protected!
      $timeline.reverse.to_json
    end

    post '/1/statuses/update.json' do
      protected!
      post_tweet(params['status'], session)
      response = [
      ]
      response.to_json
    end

    get '/1/account/rate_limit_status.json' do
      protected!
      {'remaining_hits' => 150}.to_json
    end
  end
end
