require 'simple_worker'
require 'net/http'
require 'date'
require 'json'

class Video
  attr_accessor :url, :thumbnail_url, :title, :description, :date, :category
end

class TsnVideoListCreator

  @@videos_url="http://vid3.tsn.ua/"
  @@video_filename="videos.xml"
  @@host="tsn.ua"
  @@path="/video/video-novini/"
  @@number_of_video_pages_to_parse=8
  @@headers = {
    'Host' =>	'tsn.ua',
    'User-Agent' =>	'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:6.0.1) Gecko/20100101 Firefox/6.0.1',
    'Accept' =>	'*/*',
    'Accept-Language' =>	'en-us,en;q=0.5',
    'Accept-Encoding' =>	'gzip, deflate',
    'Accept-Charset' =>	'ISO-8859-1,utf-8;q=0.7,*;q=0.7',
    'Content-Type' =>	'application/x-www-form-urlencoded; charset=UTF-8',
    'X-Requested-With' =>	'XMLHttpRequest',
    'Server-Request-Connector' =>	'box_tsnua',
    'Server-Request-Point' =>	'bottom_video_list',
    'Server-Request-Additional' =>	'receiver=%23bottom_video_list',
    'Server-Request-URL' =>	'/video/video-novini#bottom_video_list',
    'Server-Request-Referer' =>	'http://tsn.ua/video/video-novini',
    'Referer' =>	'http://tsn.ua/video/video-novini',
    'Content-Length' =>	'51',
    'Cookie' =>	'b=b; b=b; __utma=86753053.539834306.1322098564.1322098564.1322102229.2; __utmc=86753053; __utmz=86753053.1322098564.1.1.utmcsr=(direct)|utmccn=(direct)|utmcmd=(none); focus_index=1; PHPSESSID=u2sgjh0qv68tfvtacbtj42sth2; rtn4p=2; __utmb=86753053.2.10.1322102229',
    'DNT' =>	'1',
    'pragma' =>	'no-cache',
    'Cache-Control' =>	'no-cache',
  }
  @@today = [208, 161, 209, 140, 208, 190, 208, 179, 208, 190, 208, 180, 208, 189, 209, 150, 32]
  @@yesterday = [208, 146, 209, 135, 208, 190, 209, 128, 208, 176, 32]
  @@type_category_map = {
    0 => 'All',
    2 => 'Ukraine',
    14 => 'Politics',
    3 => 'World' ,
    4 => 'Money',
    6 => 'Sport',
    7 => 'Information Technology'
  }

  def write_video_list_to_file
    string_xml = create_xml_string

    File.open(@@video_filename, "w") do |file|
      file.write string_xml
    end
  end

  def create_xml_string
    videos = []

    @@type_category_map.each_key do |type_id|
    (1..@@number_of_video_pages_to_parse).each do |page_number|
        videos.concat(parse_page(type_id, page_number))
      end
    end

    return to_xml(videos)
  end

  def to_xml videos
    string_xml = '<?xml version="1.0" encoding="utf-8"?>'
    string_xml += '<tvStation>'
    string_xml += '<dates>'

    videos_by_categories = {}

    videos.each do |video|
      if videos_by_categories.key? video.category
      videos_by_categories[video.category] << video
      else
        videos_by_categories[video.category] = [video]
      end
    end

    date = DateTime::now

    display_date = date.strftime('%a %b %d %Y')

    videos_by_categories.keys.each do |category|
      string_xml += "<date>"
      string_xml += "<displayDate>#{category}</displayDate>"
      string_xml += "<day>#{date.day}</day>"
      string_xml += "<month>#{date.month}</month>"
      string_xml += "<year>#{date.year}</year>"

      string_xml += "<videos>"

      videos_by_categories[category].each do |video|
        string_xml += "<video>"
        string_xml += "<title>#{video.title}</title>"
        string_xml += "<description>#{video.description}</description>"
        string_xml += "<url>#{video.url}</url>"
        string_xml += "<thumbnail_url>#{video.thumbnail_url}</thumbnail_url>"
        string_xml += "</video>"
      end
      
      string_xml += "</videos>"      
      string_xml += "</date>"

    end

    string_xml += '</dates>'
    string_xml += '</tvStation>'
  end

  def visit_and_extract_mp4_url page_path
    begin
      http = Net::HTTP.new(@@host, 80)
      response = http.get2(page_path) #, @@headers)

      extract_mp4_url response.body
    rescue => e
      puts e.message
      e.backtrace.each do |bt|
        puts bt.to_s
      end
    end
  end

  def extract_mp4_url data
    if /src=.*(http:\/\/.*?[.]mp4)/.match(data)
      puts "extract url #{$1}"
    return $1
    else
      return ""
    end
  end

  def parse_page(type_id, page_num)
    puts "starting to parse category #{@@type_category_map[type_id]} page: #{page_num}"

    post_data="id_section=308&page=#{page_num}&type=#{type_id}&media_id=0&items=24908"

    begin
      http = Net::HTTP.new(@@host, 80)
      
      puts "path #{@@path}"
      
      puts "post_data: #{post_data}"
      resp, data = http.post2(@@path, post_data, @@headers)
    rescue => e
      puts "Caught exception: #{e.to_s}"
      e.backtrace.each do |bt|
        puts bt.to_s
      end
    end

    state=0

    videos = []
    media_id = ''
    thumbnail_url = ''
    is_today = false
    date_today = DateTime.httpdate(resp['Date']).new_offset("+02:00")
    video_url = ''

    puts "date_today: #{date_today}"

    data.lines.each do |line|

    # find open li
      if state == 0 && /.*<li.*/.match(line)
        puts "state 0"
      state = 1
      end

      if state == 1 && /<a href='(.*?)' class='image'>/.match(line)
        puts "state 1"
        video_page_path = $1

        puts "video page path: #{video_page_path}"
        state = 2

        video_url = visit_and_extract_mp4_url video_page_path
      end

      # find thumbnail url
      if state == 2 && /.*<img src='(.*?)'.*/.match(line)
        puts "in state 2, found thumbnail url: #{$1}"
        thumbnail_url = $1

        /.*\/([0-9]*).jpg/.match($1)

        puts "found id: #{$1}"
        media_id = $1.to_i + 1

        puts "found media_id #{media_id}"

        state = 3
      end
      
      if state == 3 && /.*<span class='date'>(.*)<\/span>.*/.match(line)
        puts "in state 3, found date: #{$1}"

        raw_date = []

        $1.bytes do |num|
        #	    puts num
          raw_date  << num
        end

        if raw_date == @@today
          puts "in state 3, found date: today"
        is_today = true
        end

        if raw_date == @@yesterday
          puts "in state 3, found date: yesterday"
        is_today = false
        end

      state = 4
      end

      if state == 4
        puts "in state 4, saving data, going to state 0"

        video = Video.new

        if is_today
        date = date_today
        else
        date = date_today - 1
        end

        day = "%02d" % [date.day]
        month = "%02d" % [date.month]

        video.url = video_url
        video.thumbnail_url = thumbnail_url

        display_date = date.strftime('%a %b %d %Y')

        video.title = "TSN - #{display_date}"
        video.date = date

        video.category = @@type_category_map[type_id]

        puts "videos length: #{videos.length}"

      videos << video

      state = 0
      end
    end

    return videos
  end
end

class TsnParserWorker < SimpleWorker::Base

  @@host = "michel.f1kart.com"
  @@path = "/video_lists/2"
  @@headers = {'Content-Type' => 'application/json'}

  def run
    log "Starting TnsParserWorker #{Time.now}\n"

    t = TsnVideoListCreator.new
    raw_xml = t.create_xml_string

    log "posting to #{@@host}/#{@@path}"

    save_data raw_xml
  end

  def save_data data
    video_list = { :video_list => { :data => data } }

    begin
      http = Net::HTTP.new(@@host, 80)
      resp, data = http.put(@@path, video_list.to_json, @@headers)

      puts resp.code
    rescue => e
      log "Caught exception: #{e.to_s}"
      e.backtrace.each do |bt|
        log bt.to_s
      end
    end
  end
end

t = TsnVideoListCreator.new
t.write_video_list_to_file

