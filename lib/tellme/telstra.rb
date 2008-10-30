require 'rubygems'
require 'mechanize'
require 'hpricot'
require 'logger'
require 'chronic'
require 'time'

class TelstraUsage
  attr_reader :percent
  attr_reader :percent_of_date
  attr_reader :used
  attr_reader :left
  attr_reader :end_date
  attr_reader :start_date

  def initialize(pik, password)
    @pik = pik
    @password = password
    
    @agent = WWW::Mechanize.new #{|a| a.log = Logger.new($stderr)}
  end

  def fetch(timeout = 30)
    @agent.open_timeout = timeout
    @agent.read_timeout = timeout

    page = @agent.get("https://www.telstraclear.co.nz/usagemeter/")
    form = page.forms[1]
    form.fields.find{|f| f.name == 'acc' }.value = @pik
    form.fields.find{|f| f.name == 'pik' }.value = @password
    page = @agent.submit(form, form.buttons.first)

    doc = Hpricot(page.body)

    if page.body =~ /main menu for account/i
      link = (doc/"a").detect do |a|
        a.inner_text =~ /\d+\s+-\s+today/i
      end
      
      link = link.attributes['href']
      
      page = @agent.get(link)
      doc = Hpricot(page.body)
    end

    text_elements = (doc/"#usg_content_info").first
    text = text_elements.inner_text
    
    text =~ /you have used\s+(\d+(\.\d+)?)\s?(MB|GB)/i
    used = $1.to_f
    used = used / 1024 if $2 == 'MB'
    @used = used
    
    text =~ /(\d+)%/
    @percent = $1.to_i

    text =~ /(\d+(\.\d+)?)\s?(MB|GB)\s+left/
    left = $1.to_f
    left = left / 1024 if $2 == 'MB'
    @left = left
    
    text_elements = (doc/".usg_content_hdr_txt").first
    text = text_elements.inner_text
    
    text =~ /Usage Summary Graph:(.*?)- Today/i
    @start_date = Chronic.parse($1)
    text =~ /ends on:\s*(.*)/i
    @end_date = Chronic.parse($1)

    percent_date = ((((Time.now - @start_date).to_i).to_f / ((@end_date - @start_date).to_i).to_f)*100).round
    @percent_of_date = percent_date
  end
end

