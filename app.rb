require 'sinatra'

require 'haml'
require 'dm-core'
require 'dm-migrations'
require 'dm-validations'
require 'dm-timestamps'

require 'net/ping'

URL_REGEX = /^(http|https):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(([0-9]{1,5})?\/.*)?$/ix

def ping(url, options = {})
  port = options[:port] || nil
  timeout = options[:timeout] || 3
  Net::Ping::HTTP.new(url, port, timeout).ping
end

def http(url)
  unless url.match(/^http/)
    "http://#{url}"
  else
    url
  end
end

configure :development do
  DataMapper.setup(:default, "sqlite://#{Dir.pwd}/relink.db")
end

configure :production do
  DataMapper.setup(:default, ENV['DATABASE_URL'])
end

DataMapper::Model.raise_on_save_failure = true

class Link
  include DataMapper::Resource

  property :id, Serial

  property :url, String
  property :mirror, String

  property :last_result, Boolean, :default => false
  property :last_pinged_at, DateTime

  property :created_at, DateTime

  validates_presence_of :url, :mirror
  validates_format_of :url, :with => URL_REGEX
  validates_format_of :mirror, :with => URL_REGEX

  def ping!
    update(:last_result => ping(url), :last_pinged_at => DateTime.now)
  end

  def ping_again?
    diff_seconds = (last_pinged_at - DateTime.now).round
    diff_seconds > 600
  end

  def link
    if last_result
      url
    else
      mirror
    end
  end
end

DataMapper.finalize
DataMapper.auto_upgrade!

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
    url = http(params[:url])
    mirror = http(params[:mirror])

    link = Link.create(
      :url => url,
      :mirror => mirror,
      :last_result => false,
      :last_pinged_at => nil
    )

    if link.nil?
      redirect "/"
    end

    link.ping!
    redirect "/l/#{link.id}/view"
  end

  get '/l/:link' do |l|
    begin
      link = Link.get(l)
    rescue DataMapper::ObjectNotFoundError
      redirect '/'
    end

    if link.ping_again?
      link.ping!
    end

    redirect link.link, 301
  end

  get '/l/:link/view' do |l|
    begin
      @link = Link.get(l)
    rescue DataMapper::ObjectNotFoundError
      redirect '/'
    end

    haml :view
  end
end
