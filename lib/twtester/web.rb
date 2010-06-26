require 'sinatra/base'

module TwTester
  class Web < Sinatra::Base
    get '/' do
      "Hello world!"
    end
  end
end
