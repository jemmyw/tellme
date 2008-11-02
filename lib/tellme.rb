require 'tellme/telstra'

module Tellme
  VERSION = '1.0.0'

  def self.start(ui = 'text')
    require 'tellme/%s' % ui
  end
end

class String
  def blank?
    length == '' ? true : false
  end
end

class NilClass
  def blank?
    true
  end
end
