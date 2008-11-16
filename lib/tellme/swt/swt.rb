require 'java'

require '/usr/lib/java/swt.jar'
require '/usr/lib/java/swt-gtk.jar'

include_class 'org.eclipse.swt.SWT'

module Widgets
  include_package 'org.eclipse.swt.widgets'
  include_class 'org.eclipse.swt.widgets.Widget'

  module SwtListener
    def listen(type, &block)
      listener = Widgets::Listener.new
      listener.instance_eval do
        def handleEvent(event)
          @block.call event
        end

        @block = block
      end

      self.addListener(type, listener)
    end
  end

  class Widget
    include SwtListener
  end
end

module Graphics
  include_package 'org.eclipse.swt.graphics'
end

class Application
  def initialize
    @display = Widgets::Display.new
    @shell = Widgets::Shell.new(@display)
    @tray = @display.getSystemTray

    unless @tray
      raise "The system tray is not available"
    end

    @item = Widgets::TrayItem.new(@tray, SWT::NONE)
    @image = Graphics::Image.new(@display, 16, 16)

    setup_menu
    @item.setImage(@image)
    @item.setToolTipText("Tellme")
  end

  def setup_menu
    @menu = Widgets::Menu.new(@shell, SWT::POP_UP)

    update = Widgets::MenuItem.new(@menu, SWT::PUSH)
    update.setText("Update")
    update.listen(SWT::Selection) do
      puts "selected"
    end

    @item.listen(SWT::MenuDetect) do
      @menu.setVisible(true)
    end
  end

  def run
    @shell.open

    while !@shell.isDisposed
      @display.sleep unless @display.readAndDispatch
    end

    @image.dispose
    @display.dispose
  end
end

$application = Application.new
$application.run