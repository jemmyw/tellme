#!/usr/bin/env ruby
#
# This file is gererated by ruby-glade-create-template 1.1.4.
#
require 'libglade2'

class PreferencesGlade
  include GetText

  attr :glade
  
  def initialize(path_or_data, root = nil, domain = nil, localedir = nil, flag = GladeXML::FILE)
    bindtextdomain(domain, localedir, nil, "UTF-8")
    @glade = GladeXML.new(path_or_data, root, domain, localedir, flag) {|handler| method(handler)}
    
  end
  
  def on_cancel_button_clicked(widget)
    puts "on_cancel_button_clicked() is not implemented yet."
  end
  def on_save_button_clicked(widget)
    puts "on_save_button_clicked() is not implemented yet."
  end
end

# Main program
if __FILE__ == $0
  # Set values as your own application. 
  PROG_PATH = "preferences.glade"
  PROG_NAME = "YOUR_APPLICATION_NAME"
  PreferencesGlade.new(PROG_PATH, nil, PROG_NAME)
  Gtk.main
end
