#!/usr/bin/ruby

require 'rubygems'
require 'time'
require 'gtk2'
require 'monitor'
require 'timeout'
require 'RMagick'
require 'sparklines'
require 'libglade2'
require 'gconf2'
require File.dirname(__FILE__) + '/telstra'

PIE_BACKGROUND = '#800080'
PIE_FOREGROUND = '#e200e2'

module Gtk
	GTK_PENDING_BLOCKS = []
	GTK_PENDING_BLOCKS_LOCK = Monitor.new

	def Gtk.queue &block
		if Thread.current == Thread.main
			block.call
		else
			GTK_PENDING_BLOCKS_LOCK.synchronize do
				GTK_PENDING_BLOCKS << block
			end
		end
	end

	def Gtk.main_with_queue timeout
		Gtk.timeout_add timeout do
			GTK_PENDING_BLOCKS_LOCK.synchronize do
				for block in GTK_PENDING_BLOCKS
					block.call
				end
				GTK_PENDING_BLOCKS.clear
			end
			true
		end

		Gtk.main
	end
end

GCONF_KEY = '/apps/telstra'
GCONF_PIK_KEY = GCONF_KEY + '/pik'
GCONF_PASSWORD_KEY = GCONF_KEY + '/password'

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

class PreferencesWindow
  def initialize
    @gconf = GConf::Client.default
  end

  def show
    if @window
      @window.show
    else
      glade = GladeXML.new(File.dirname(__FILE__) + '/glade/preferences.glade') do |handler|
        method(handler)
      end

      @window = glade.get_widget('preferences_window')
      @pik_input = glade.get_widget('pik_input')
      @password_input = glade.get_widget('password_input')

      self.load
    end
  end

  def hide
    @window.hide if @window
    dispose
  end

  def load
    @pik_input.text = @gconf[GCONF_PIK_KEY]
    @password_input.text = @gconf[GCONF_PASSWORD_KEY]
  end

  def save
    @gconf[GCONF_PIK_KEY] = @pik_input.text
    @gconf[GCONF_PASSWORD_KEY] = @password_input.text
  end

  def on_cancel_button_clicked(widget)
    hide
  end

  def on_save_button_clicked(widget)
    save
    hide
  end

  def dispose
    @window = nil
    @pik_input = nil
    @password_input = nil
  end
end

class TelstraApplication
  def initialize
    setup_gconf
    setup_tray
    setup_menu
  end

  def setup_gconf
    @gconf = GConf::Client.default
    @gconf.add_dir(GCONF_KEY)
    @gconf.notify_add(GCONF_KEY) do |client, entry|
      update
    end
  end

  def setup_tray
    @tray = Gtk::StatusIcon.new
    @tray.file = File.dirname(__FILE__) + '/telstra.png'
    @tray.visible = true
  end

  def setup_menu
    @xml = <<-EOF
    <ui>
      <popup name="tray">
        <menuitem name="Update" action="update" />
        <menuitem name="Preferences" action="preferences" />
        <separator/>
        <menuitem name="Quit" action="quit" />
      </popup>
    </ui>
    EOF

    @ui = Gtk::UIManager.new

    @action_group = Gtk::ActionGroup.new('tray_actions')
    @action_group.add_actions(
      [
        ['update', Gtk::Stock::REFRESH, 'Update', nil, 'Fetch latest info', Proc.new{|aq,a| update }],
        ['preferences', Gtk::Stock::PREFERENCES, 'Preferences', nil, 'Show preferences', Proc.new{|ag,a| preferences.show }],
        ['quit', Gtk::Stock::QUIT, 'Quit', nil, 'Quit', Proc.new{|aq,a| quit }]
      ]
    )

    @ui.insert_action_group(@action_group, 0)
    @ui.add_ui(@xml)
    @ui.ensure_update

    @menu = @ui.get_toplevels(Gtk::UIManager::POPUP).first

    @tray.signal_connect('popup-menu') do |widget,event|
      @menu.popup(nil,nil,2,0)
    end
  end

  def quit
    Gtk.main_quit
  end

  def preferences
    @preferences ||= PreferencesWindow.new
  end

  def update
    updater.wakeup
  end

  def updater
    @updater ||= Thread.new do
      sleep 1

      while true
        actual_update
        sleep 60*10
      end
    end
  end

  def show_fetching
    if @fetching
      @fetch_frame = 0 if @fetch_frame > @fetch_animation.length-1
      @image = @fetch_animation[@fetch_frame]
      @fetch_frame+=1
      update_image

      true
    else
      false
    end
  end

  def actual_update
    puts "Starting update"

    pik = @gconf[GCONF_PIK_KEY]
    password = @gconf[GCONF_PASSWORD_KEY]

    if pik.blank? || password.blank?
      @tooltip = "Set your PIK and password first!"
    else
      begin
        @fetching = true
        @fetch_animation = loading_image
        @fetch_frame = 0

        Gtk.timeout_add 100 do
          show_fetching
        end
        
        telstra = TelstraUsage.new(pik, password)
        telstra.fetch(30)
        
        @fetching = false

        @tooltip = '%d%% used' % telstra.percent
        @tooltip << (' in %d%% of the period' % telstra.percent_of_date) if telstra.percent_of_date
        @tooltip << "\n%dGB used, %dGB left" % [telstra.used, telstra.left]

        @image = generate_pie(telstra.percent)
      rescue Exception => e
        puts "Error occured in fetch: #{e}"
      end
    end
    
    puts "Update complete"

    update_tooltip
    update_image
  end

  def update_tooltip
    Gtk.queue do
      @tray.tooltip = @tooltip unless @tooltip.blank?
    end
  end

  def update_image
    if @image && @image.respond_to?(:to_blob)
      Gtk.queue do
        loader = Gdk::PixbufLoader.new
        loader.signal_connect('area-prepared') do |l|
          @tray.pixbuf = l.pixbuf
        end

        loader.write(@image.to_blob{|i| i.format = 'GIF'})
        loader.close
      end
    end
  end

  def generate_pie(percent)
    size = @tray.size

    rimage = Sparklines.plot_to_image([percent, 100],
      :type => 'pie',
      :diameter => size,
      :background_color => 'transparent',
      :share_color => PIE_FOREGROUND,
      :remain_color => PIE_BACKGROUND)
    rimage.format = 'PNG'
    rimage
  end

  def loading_image
    percent = 0
    frames = []

    20.times do
      frames << generate_pie(percent)
      percent += 5
    end

    20.times do
      frames << generate_pie(percent)
      percent -= 5
    end
    
    frames
  end
end

Gtk.init_add do
  application = TelstraApplication.new
  Gtk.timeout_add 250 do
    application.update
    false
  end
end

Gtk.main_with_queue(100)
