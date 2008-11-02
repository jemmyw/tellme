require 'libglade2'

class PreferencesWindow
  def initialize
    @gconf = GConf::Client.default
  end

  def show
    if @window
      @window.show
    else
      glade = GladeXML.new(File.dirname(__FILE__) + '/preferences.glade') do |handler|
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
