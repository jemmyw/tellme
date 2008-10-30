#!/usr/bin/ruby

require File.dirname(__FILE__) + '/telstra'

unless $options[:pik] && $options[:password]
  puts "You must enter your PIK and password to use the text tool."
  exit
end

t = TelstraUsage.new($options[:pik], $options[:password])
t.fetch(30)

output = "#{t.percent}% used"
output << " in #{t.percent_of_date}% of the period" if t.percent_of_date

puts output
puts "#{t.used}GB used, #{t.left}GB left"
puts "Period #{t.start_date.strftime("%d %B %Y")} to #{t.end_date.strftime("%d %B %Y")}"
