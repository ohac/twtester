require 'sinatra/base'
require 'json'
require 'haml'
require 'fileutils'
require 'time'

$timeline = []
if File.exist?('timeline.bin')
  File.open('timeline.bin', 'rb') do |fd|
    $timeline = Marshal.load(fd.read)
  end
end
FileUtils.mkdir_p('tweets')

module TwTester

  class Web < Sinatra::Base
    TWTESTER_HOME = File.dirname(__FILE__) + '/../../'
    set :public, TWTESTER_HOME + 'public'
    set :views, TWTESTER_HOME + 'views'
    enable :sessions

    helpers do
      include Rack::Utils; alias_method :h, :escape_html

      def protected!
        unless authorized?
          response['WWW-Authenticate'] = %(Basic realm="TwTester HTTP Auth")
          throw(:halt, [401, "Not authorized\n"])
        end
      end

      def screen_name?(name)
        /\A[0-9a-zA-Z_]+\z/ === name && name.size <= 20
      end

      def authorized?
        @auth ||= Rack::Auth::Basic::Request.new(request.env)
        if @auth.provided? && @auth.basic?
          cr = @auth.credentials
          cr && screen_name?(cr[0])
        end
      end

      def partial(renderer, template, options = {})
        options = options.merge({:layout => false})
        template = "_#{template.to_s}".to_sym
        m = method(renderer)
        m.call(template, options)
      end

      def partial_haml(template, options = {})
        partial(:haml, template, options = {})
      end

      def post_tweet(text, account, reply_to_id = nil, reply_to = nil)
        return if text.size == 0
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
        if reply_to_id and !reply_to_id.empty?
          tweet['in_reply_to_status_id'] = reply_to_id.to_i
          unless reply_to
            reply_to = load_tweet(reply_to_id)['user']['screen_name']
          end
          raise unless screen_name?(reply_to)
          tweet['in_reply_to'] = reply_to
        end
        $timeline << tweet
        $timeline.shift if $timeline.size > 20
        File.open("tweets/#{tid}.bin", 'wb') do |fd|
          fd.write(Marshal.dump(tweet))
        end
        File.open('timeline.bin', 'wb') do |fd|
          fd.write(Marshal.dump($timeline))
        end
        tweet
      end

      def timestr(time)
        t = Time.parse(time)
        diff = Time.now.to_i - t.to_i
        if diff < 20
          'less than 20 seconds ago'
        elsif diff < 30
          'half a minute ago'
        elsif diff < 60
          'less than a minute ago'
        elsif diff < 3600
          "#{diff / 60} minute(s) ago"
        elsif diff < 24 * 3600
          "#{diff / 3600} hour(s) ago"
        else
          t.strftime('%Y-%m-%d %H:%M')
        end
      end

      def load_tweet(tid)
        raise unless tid.to_i.to_s == tid # check
        File.open("tweets/#{tid}.bin", 'rb') do |fd|
          Marshal.load(fd.read)
        end
      end
    end

    CONTENT_TYPES = {
      :html => 'text/html',
      :xml => 'text/xml',
      :css => 'text/css',
      :js => 'application/javascript',
      :txt => 'text/plain',
    }

    before do
      request_uri =
          case request.env['REQUEST_URI']
          when /\.css$/ ; :css
          when /\.js$/ ; :js
          when /\.txt$/ ; :txt
          when /\.xml$/ ; :xml
          else :html
          end
      content_type CONTENT_TYPES[request_uri], :charset => 'utf-8'
      response.headers['Cache-Control'] = 'no-cache'
    end

    get '/' do
      since = (params['since_id'] || '0').to_i
      tl = $timeline.select{|t|t['id'] > since}
      haml :index, :locals => { :timeline => tl, :user => session[:user] }
    end

    get '/login' do
      haml :login
    end

    post '/login' do
      user = params['user']
      pass = params['pass']
      digest = Digest::MD5.hexdigest(pass)
      user = screen_name?(user) ? user : "anonym_#{digest[0,4]}"
      session[:user] = user
      session[:pass] = pass
      redirect '/'
    end

    get '/logout' do
      session[:user] = nil
      session[:pass] = nil
      redirect '/'
    end

    get '/:screen_name/status/:tid' do |screen_name, tid|
      tweet = load_tweet(tid)
      haml :tweet, :locals => { :tid => tid, :tweet => tweet }
    end

    post '/update' do
      account = session
      unless account[:user]
        pass = ['REMOTE_ADDR', 'HTTP_USER_AGENT', 'HTTP_ACCEPT',
          'HTTP_ACCEPT_ENCODING', 'HTTP_ACCEPT_LANGUAGE',
          'HTTP_ACCEPT_CHARSET'].map{|k|request.env[k]}.join
        session[:salt] = rand.to_s if params['salt']
        salt = session[:salt] || ''
        pass = salt + pass
        digest = Digest::MD5.hexdigest(pass)
        account = { :user => "anonym_#{digest[0,4]}", :pass => pass }
      end
      text = params['status']
      text = text.split(//u)[0, 140].join
      post_tweet(text, account, params['in_reply_to_status_id'],
          params['in_reply_to'])
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
      since = (params['since_id'] || '0').to_i
      session[:user], session[:pass] = @auth.credentials if @auth
      $timeline.select{|t|t['id'] > since}.reverse.to_json
    end

    post '/1/statuses/update.:ext' do |ext|
      protected!
      session[:user], session[:pass] = @auth.credentials if @auth
      text = params['status']
      text = text.split(//u)[0, 140].join
      response = post_tweet(text, session, params['in_reply_to_status_id'],
          params['in_reply_to'])
      response.to_json
    end

    get '/1/statuses/show/:tid.json' do |tid|
      tweet = load_tweet(tid)
      tweet.to_json
    end

    get '/1/users/show/:uid.xml' do
      protected!
      haml :timeline, :locals => { :tweets => [] }
    end

    get '/1/account/verify_credentials.json' do
      protected!
      session[:user], session[:pass] = @auth.credentials if @auth
      response = {
        'user' => {
          'name' => session[:user],
          'screen_name' => session[:user],
        }
      }
      response.to_json
    end

    get '/1/account/verify_credentials.xml' do
      protected!
      session[:user], session[:pass] = @auth.credentials if @auth
      response = {
        'user' => {
          'name' => session[:user],
          'screen_name' => session[:user],
        }
      }
      haml :verify_credentials, :locals => { :response => response }
    end

    get '/1/account/rate_limit_status.json' do
      protected!
      session[:user], session[:pass] = @auth.credentials if @auth
      {'remaining_hits' => 150}.to_json
    end

    get '/1/:screen_name/lists.json' do |screen_name|
      response = {
        'lists' => [],
        'next_cursor' => 0,
        'previous_cursor' => 0,
      }
      response.to_json
    end

    get '/1/account/rate_limit_status.xml' do
      protected!
      haml :rate_limit_status
    end

    get '/1/followers/ids.xml' do
      haml :ids
    end

    get '/1/statuses/home_timeline.xml' do
      protected!
      since = (params['since_id'] || '0').to_i
      session[:user], session[:pass] = @auth.credentials if @auth
      tweets = $timeline.select{|t|t['id'] > since}.reverse
      haml :timeline, :locals => { :tweets => tweets }
    end

    get '/1/statuses/mentions.xml' do
      haml :mentions
    end

    get '/1/direct_messages.xml' do
      haml :direct_messages
    end

    get '/1/favorites.xml' do
      haml :favorites
    end

    get '/search' do
      q = params[:q]
      since_id = params[:since_id] # TODO
      max_id = params[:max_id] # TODO
      since = params[:since] # TODO
      untilt = params[:until] # TODO
      tl = Dir.glob('tweets/*.bin').map do |fn|
        File.open(fn, 'rb') do |fd|
          Marshal.load(fd.read)
        end
      end
      unless q.nil?
        tl = tl.select do |tw|
          tw['text'].index(q)
        end
      end
      haml :index, :locals => { :timeline => tl, :user => session[:user] }
    end
  end
end
