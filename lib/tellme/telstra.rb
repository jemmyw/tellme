require 'rubygems'
require 'mechanize'
require 'hpricot'
require 'logger'
require 'chronic'
require 'time'

class TelstraUsage
  USAGE_PAGE = "https://www.telstraclear.co.nz/usagemeter/"

  attr_reader :percent
  attr_reader :percent_of_date
  attr_reader :used
  attr_reader :left
  attr_reader :end_date
  attr_reader :start_date

  attr_writer :pik
  attr_writer :password

  def initialize(pik = nil, password = nil)
    @pik = pik
    @password = password
    
    @agent = WWW::Mechanize.new #{|a| a.log = Logger.new($stderr)}
  end

  def fetched?
    @fetched
  end
  
  def fetch(timeout = 30)
    raise ArgumentError, "Account number and password not set" if @pik.blank? || @password.blank?

    @agent.open_timeout = timeout
    @agent.read_timeout = timeout

    doc = fetch_usage_page

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
    
    @fetched = true
  end

  private

  def fetch_usage_page
    page = @agent.get(USAGE_PAGE)
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

    doc
  end
end

