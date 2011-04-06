require 'sinatra'
require 'dm-core'

require 'haml'

require 'timeout'
require 'net/http'

configure :development do
  DataMapper.setup(:default, "sqlite://#{Dir.pwd}/relink.db")
end

configure :production do
  DataMapper.setup(:default, ENV['DATABASE_URL'])
end

require './lib/core_ext'
require './lib/models'
require './lib/redirect_follower'

def ping(url, options = {})
  timeout = options[:timeout] || 3

  uri = URI.parse(url)
  puts url
  begin
    http = Net::HTTP.new(uri.host)
    http.read_timeout = timeout
    path = uri.path.empty? ? "/" : uri.path
    res = http.get(path)
    if res.code.good?
      false
    else
      true
    end
  rescue Errno::ETIMEDOUT
    false
  end
end

module Relink
  class Relink < Sinatra::Base
    set :haml, {:format => :html5}

    helpers do
      include Rack::Utils
      alias_method :h, :escape_html
    end

    get '/' do
      haml :index
    end

    post '/' do
      if params[:url].empty? || params[:mirror].empty?
        redirect "/"
      end

      url = params[:url].add_scheme
      mirror = params[:mirror].add_scheme

      broken_already = false
      begin
        url = RedirectFollower.new(url.add_scheme).resolve.url
      rescue Timeout::Error
        broken_already = true
      end
      mirror = RedirectFollower.new(mirror.add_scheme).resolve.url

      if URI.parse(url).host == "relink.heroku.com"
        redirect "/"
      end

      link = Link.create(
        :url => url,
        :mirror => mirror,
        :last_result => false,
        :last_pinged_at => DateTime.now
      )

      if link.nil?
        redirect "/"
      end
      
      link.ping! unless broken_already
      redirect "/l/#{link.id}/view"
    end


    get '/l/:link/view/?' do |l|
      begin
        @link = Link.get(l)
      rescue DataMapper::ObjectNotFoundError
        redirect '/'
      end

      haml :view
    end

    get '/l/:link/?' do |l|
      begin
        link = Link.get(l)
      rescue DataMapper::ObjectNotFoundError
        redirect '/'
      end

      if link.nil?
        redirect "/"
      end

      if link.ping_again?
        link.ping!
      end

      if URI.parse(link.link).host == "relink.heroku.com"
        redirect "/"
      end

      redirect link.link, 301
    end

    get '/l/:link/*/?' do |l, star|
      redirect "/l/#{l}/"
    end
  end
end
