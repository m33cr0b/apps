## -*- ruby -*- ##############################################################
#
#  System        :
#  Module        :
#  Object Name   : $RCSfile$
#  Revision      : $Revision$
#  Date          : $Date$
#  Author        : $Author$
#  Created By    : Michel Lacle
#  Created       : Sat Dec 3 15:16:33 2011
#  Last Modified : <111204.1104>
#
#  Description
#
#  Notes
#
#  History
#
##############################################################################
#
#  Copyright (c) 2011 Michel Lacle.
#
#  All Rights Reserved.
#
#  This  document  may  not, in  whole  or in  part, be  copied,  photocopied,
#  reproduced,  translated,  or  reduced to any  electronic  medium or machine
#  readable form without prior written consent from Michel Lacle.
#
##############################################################################

require 'simple_worker'
require 'net/http'
require 'date'
require 'json'



class Video
  attr_accessor :url, :thumbnail_url, :title, :description, :date, :category
end



#http://vid3.tsn.ua/2011/11/24/383523337-2.mp4
class RailscastsVideoListCreator

  @@videos_url="http://media.railscasts.com/assets/episodes/videos/"
  @@video_filename="videos.xml"
  @@host="railscasts.com"

  @@tag_category_map = {
    2 => 'Active Record',
    19 => 'Active Resource',
    3 => 'Active Support',
    9 => 'Administration' ,
    11 => 'Ajax',
    25 => 'Authentication',
    26 => 'Authorization',
    32 => 'Background Jobs',
    18 => 'Caching',
    8 => 'Controllers',
    10 => 'Debugging',
    21 => 'Deployment',
    23 => 'eCommerce',
    15 => 'Forms',
    28 => 'Mailing',
    16 => 'Models',
    1 => 'Performance',
    13 => 'Plugins',
    33 => 'Production',
    17 => 'Rails 2.0',
    20 => 'Rails 2.1',
    22 => 'Rails 2.2',
    24 => 'Rails 2.3',
    27 => 'Rails 3.0',
    31 => 'Rails 3.1',
    6 => 'Refactoring',
    14 => 'Routing',
    30 => 'Search',
    5 => 'Security',
    7 => 'Testing',
    12 => 'Tools',
    4 => 'Views'
  }

  @@headers = {
    'User-Agent' =>	'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:6.0.1) Gecko/20100101 Firefox/6.0.1',
    'Accept' =>	'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language' =>	'en-us,en;q=0.5',
    'Accept-Encoding' =>	'gzip, deflate',
    'Accept-Charset' =>	'ISO-8859-1,utf-8;q=0.7,*;q=0.7',
  }

  def write_video_list_to_file
    string_xml = create_xml_string

    File.open(@@video_filename, "w") do |file|
      file.write string_xml
    end
  end

  def create_xml_string
    videos = []

    @@tag_category_map.each_key do |tag_id|
      videos.concat(parse_page(tag_id))
    end

    return to_xml(videos)
  end

  def to_xml videos

    #	puts "video list size: #{videos.length}"

    string_xml = '<?xml version="1.0" encoding="utf-8"?>'
    string_xml += '<tvStation>'
    string_xml += '<categories>'

    videos_by_categories = {}

    videos.each do |video|
      if videos_by_categories.key? video.category
      videos_by_categories[video.category] << video
      else
        videos_by_categories[video.category] = [video]
      end
    end

    #	tc = videos_by_categories[videos[0].date].length
    #	puts "found #{tc} videos for today"

    videos_by_categories.keys.each do |category|

      string_xml += "<category>"
      string_xml += "<name>#{category}</name>"
      string_xml += "<videos>"

      videos_by_categories[category].each do |video|
        string_xml += "<video>"
        string_xml += "<title>#{video.title}</title>"
        string_xml += "<description>#{video.description}</description>"
        string_xml += "<url>#{video.url}</url>"
        string_xml += "<thumbnail_url>#{video.thumbnail_url}</thumbnail_url>"
        string_xml += "<date>#{video.date}</date>"
        string_xml += "</video>"
      end

      string_xml += "</videos>"
      string_xml += "</category>"
    end

    string_xml += '</categories>'
    string_xml += '</tvStation>'
  end

  def parse_page(tag_id)
    @@path="?tag_id=#{tag_id}&type=free"

    category = @@tag_category_map[tag_id]

    begin
      resp = Net::HTTP::get_response(@@host, @@path)

      data = resp.body

      #	    puts data
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
    date = ''
    description = ''
    title = ''

    data.lines.each do |line|

    # find open li
      if state == 0 && /.*<div class=\"episode\">.*/.match(line)
        puts "found open div class episode"
      state = 1
      end

      # find thumbnail url
      if state == 1 && /.*<img .* src="(.*?)".*/.match(line)
        puts "in state 1, found thumbnail url: #{$1}"
        thumbnail_url = "http://#{@@host}/#{$1}"

        /\/assets\/episodes\/stills\/(.*?).png/.match($1)

        puts "media_id: #{$1}"
      media_id = $1

      state = 2
      end

      if state == 2 && /.*<span class="published_at">(.*)<\/span>.*/.match(line)
        puts "in state 2, found date: #{$1}"

      date = $1

      state = 3
      end

      if state == 3 && /<h2>/.match(line)
        puts "in state 3"
      state = 4
      end

      if state == 4 && /<a href="(.*)">(.*)<\/a>/.match(line)
        puts "in state 4, #{$1} #{$2}"

        title = $2

        puts "title: #{title}"

      state = 5
      end

      if state == 5 && /<div class="description">/.match(line)
        puts "in state 5"
      state = 6
      next
      end

      if state == 6
        puts "in state #{state}"
      description = line.strip

      state = 7
      end

      if state == 7
        puts "in state #{state}, saving data, going to state 0"

        video = Video.new
        #http://media.railscasts.com/assets/episodes/videos/284-active-admin.mp4
        video.url = "#{@@videos_url}/#{media_id}.mp4"
      video.thumbnail_url = thumbnail_url
      video.title = title
      video.category = category
      video.date = date
      video.description = description

      #		puts "videos length: #{videos.length}"

      videos << video

      state = 0
      end
    end

    #	puts "server category: #{}"

    return videos
  end
end



class RailscastsParserWorker < SimpleWorker::Base

  @@host = "michel.f1kart.com"
  @@path = "/video_lists/3"
  @@headers = {'Content-Type' => 'application/json'}

  def run
    log "Starting TnsParserWorker #{Time.now}\n"

    t = RailscastsVideoListCreator.new
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

r = RailscastsParserWorker.new
r.run

