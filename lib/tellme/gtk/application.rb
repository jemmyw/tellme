module Tellme
  GCONF_KEY = '/apps/telstra'
  GCONF_PIK_KEY = GCONF_KEY + '/pik'
  GCONF_PASSWORD_KEY = GCONF_KEY + '/password'
  
  PIE_BACKGROUND = '#800080'
  PIE_FOREGROUND = '#e200e2'
  
  class Application
    def initialize
      @fetch_semaphore = Mutex.new
      @client = TelstraUsage.new

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
      @tray.visible = true
      @tray.signal_connect('size-changed') do |tray, size|
        update_from_client
      end
      
      update_from_client

      Gtk.timeout_add(500) do
        screen, rect, orientation = @tray.geometry
        puts [rect.x, rect.y, rect.width, rect.height].inspect
        false
      end
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

    def update
      updater.wakeup
    end

    def fetching
      @fetch_semaphore.synchronize do
        @fetching
      end
    end

    def fetching=(value)
      @fetch_semaphore.synchronize do
        start_animation = value && !@fetching
        @fetching = value
        show_fetching if start_animation
      end
    end

    private

    def preferences
      @preferences ||= PreferencesWindow.new
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
      @fetch_animation = loading_image
      @fetch_frame = 0

      Gtk.timeout_add 100 do
        if self.fetching
          @fetch_frame = 0 if @fetch_frame > @fetch_animation.length-1
          self.image = @fetch_animation[@fetch_frame]
          @fetch_frame+=1

          true
        else
          false
        end
      end
    end

    def actual_update
      puts "Starting update"

      pik = @gconf[GCONF_PIK_KEY]
      password = @gconf[GCONF_PASSWORD_KEY]

      if pik.blank? || password.blank?
        self.tooltip = "Set your PIK and password first!"
      else
        begin
          self.fetching = true

          @client.pik = pik
          @client.password = password
          @client.fetch(30)

          self.fetching = false
        rescue Exception => e
          puts "Error occured in fetch: #{e}"
        ensure
          self.fetching = false
        end
      end

      update_from_client

      puts "Update complete"
    end

    # Set the tray image and tooltip using the client information. If the client
    # has not yet fetched information then call update_from_default to set
    # the default tray image and tooltip. Thread safe
    def update_from_client
      if @client.fetched?
        self.image = generate_pie(@client.percent)
        self.tooltip = "%d%% used in %d%% of the period\n%dGB used, %dGB left" %
        [@client.percent, @client.percent_of_date, @client.used, @client.left]
      else
        update_from_default
      end
    end

    # Set the default tray image and tooltip. Thread safe
    def update_from_default
      self.tooltip = "Waiting for update"
      self.image = File.dirname(__FILE__) + '/telstra.png'
    end

    # Set the tray tooltip. Thread safe
    def tooltip=(value)
      Gtk.queue do
        @tray.tooltip = value
      end unless value.blank?
    end

    # Set the tray image. The passed image can either be an RMagick object
    # or a string holding a path to a file. Thread safe.
    def image=(image)
      if image.respond_to?(:to_blob)
        Gtk.queue do
          loader = Gdk::PixbufLoader.new
          loader.signal_connect('area-prepared') do |l|
            @tray.pixbuf = l.pixbuf
          end

          loader.write(image.to_blob)
          loader.close
        end
      elsif image.respond_to?(:to_s) && File.exists?(image.to_s)
        Gtk.queue do
          @tray.file = image.to_s
        end
      end
    end

    # Generate a pie chart showing a given percentage
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

    # Create a set of frames with a pie chart going up and down
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
end