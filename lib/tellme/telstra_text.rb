#!/usr/bin/ruby
require 'telstra'

t = TelstraUsage.new
t.fetch
output = "#{t.percent}% used"
output << " in #{t.percent_of_date}% of the period" if t.percent_of_date

puts output
puts "#{t.used}GB used, #{t.left}GB left"
puts "Period #{t.start_date.strftime("%d %B %Y")} to #{t.end_date.strftime("%d %B %Y")}"
