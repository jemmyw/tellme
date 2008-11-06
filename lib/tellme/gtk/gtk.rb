#!/usr/bin/ruby

require 'rubygems' rescue nil
require 'time'
require 'gtk2'
require 'monitor'
require 'timeout'
require 'RMagick'
require 'sparklines'
require 'gconf2'
require 'thread'
require File.dirname(__FILE__) + '/../../tellme'
require File.dirname(__FILE__) + '/application'
require File.dirname(__FILE__) + '/glade/preferences'

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

Gtk.init_add do
  application = Tellme::Application.new
  Gtk.timeout_add 250 do
    application.update
    false
  end
end

Gtk.main_with_queue(100)
