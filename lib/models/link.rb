module Relink
  URL_REGEX = /^(http|https):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(([0-9]{1,5})?\/.*)?$/ix

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
      diff_seconds = (DateTime.now - last_pinged_at).round
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
end
