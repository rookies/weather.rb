#!/usr/bin/ruby
# -*- coding: utf-8 -*-
# http://www.wetter.com/apps_und_mehr/website/api/projekte/
# NEEDS dhu & dhl in forecast response!!!
require 'net/http'
require 'rubygems'
require 'xml/libxml'
require 'digest/md5'
require 'date'
require 'cgi'

class String
  def numeric?
    Float(self) != nil rescue false
  end
end

module Weather
  module API_QueryType
    SEARCH_MIXED = 1
    SEARCH_NAME = 2
    SEARCH_PLZ = 3
    FORECAST = 4
  end
  
  class CustomException
    def initialize ()
      Exception
    end
  end
  
  class API
    def initialize (project, key)
      @project = project
      @key = key
      @credits = {
        'text' => '',
        'link' => '',
        'logo' => ''
      }
    end
    
    def credits
      @credits
    end
    
    def string_to_bool (str)
      if str == 'yes'
        true
      else
        false
      end
    end
    
    def string_to_integer (str)
      str.strip!
      if str.length == 0
        -1
      else
        Integer(str)
      end
    end
    
    def string_to_float (str)
      str.strip!
      if str.length == 0
        -1
      else
        Float(str)
      end
    end
    
    def fill_credits (doc)
      if doc.child.name == 'search'
        xpath = '//search/credit/'
      elsif doc.child.name == 'city'
        xpath = '//city/credit/'
      else
        raise 'Invalid document.'
      end
      @credits['text'] = doc.find(xpath + 'text')[0].content
      @credits['link'] = doc.find(xpath + 'link')[0].content
      @credits['logo'] = doc.find(xpath + 'logo')[0].content
    end
    
    def do_request (type, arg)
      # create checksum:
      md5sum = Digest::MD5.hexdigest(@project + @key + arg)
      # create url from type:
      case type
        when API_QueryType::SEARCH_MIXED
          url = '/location/index/search/' + CGI::escape(arg) + '/project/' + @project + '/cs/' + md5sum
        when API_QueryType::SEARCH_NAME
          url = '/location/name/search/' + CGI::escape(arg) + '/project/' + @project + '/cs/' + md5sum
        when API_QueryType::SEARCH_PLZ
          url = '/location/plz/search/' + CGI::escape(arg) + '/project/' + @project + '/cs/' + md5sum
        when API_QueryType::FORECAST
          url = '/forecast/weather/city/' + CGI::escape(arg) + '/project/' + @project + '/cs/' + md5sum
        else
          raise ArgumentError, 'Invalid type.'
      end
      # do request:
      xml = Net::HTTP.get('api.wetter.com', url)
      # parse xml:
      doc = XML::Parser.string(xml, :encoding => XML::Encoding::UTF_8).parse
      # return tree:
      doc
    end
    
    def try_search_response_field (doc, nr, name)
      begin
        doc.find('//search/result/item[' + String(nr) + ']/' + name)[0].content
      rescue
        ''
      end
    end
    
    def parse_search_response (doc)
      if doc.child.name == 'search'
        # parse credits:
        self.fill_credits(doc)
        # parse hits:
        hits = Integer(doc.find('//search/hits')[0].content)
        # fill results array:
        results = Array.new(hits)
        1.upto(hits) {
          |i|
          results[i-1] = {
            'citycode' => self.try_search_response_field(doc, i, 'city_code'),
            'plz' => self.try_search_response_field(doc, i, 'plz'),
            'name' => self.try_search_response_field(doc, i, 'name'),
            'quarter' => self.try_search_response_field(doc, i, 'quarter'),
            'adm1_code' => self.try_search_response_field(doc, i, 'adm_1_code'),
            'adm1_name' => self.try_search_response_field(doc, i, 'adm_1_name'),
            'adm2_name' => self.try_search_response_field(doc, i, 'adm_2_name'),
            'adm4_name' => self.try_search_response_field(doc, i, 'adm_4_name')
          }
        }
        # fill return hash:
        {
          'hits' => hits,
          'exact_match' => self.string_to_bool(doc.find('//search/exact_match')[0].content),
          'results' => results
        }
      elsif doc.child.name == 'error'
        raise doc.find('//error/title')[0].content + ': ' + doc.find('//error/message')[0].content
      else
        raise 'Invalid API response.'
      end
    end
    
    def get_citycodes_from_mixed (query)
      # do request:
      doc = self.do_request(API_QueryType::SEARCH_MIXED, query)
      # parse response:
      data = self.parse_search_response(doc)
      # return data:
      data
    end
    
    def get_citycodes_from_name (query)
      # do request:
      doc = self.do_request(API_QueryType::SEARCH_NAME, query)
      # parse response:
      data = self.parse_search_response(doc)
      # return data:
      data
    end
    
    def get_citycodes_from_plz (query)
      # do request:
      doc = self.do_request(API_QueryType::SEARCH_PLZ, query)
      # parse response:
      data = self.parse_search_response(doc)
      # return data:
      data
    end
    
    def try_forecast_response_field_date (doc, nr, name)
      begin
        doc.find('//city/forecast/date[' + String(nr) + ']/' + name)[0].content
      rescue
        ''
      end
    end
    
    def try_forecast_response_field_time (doc, nr1, nr2, name)
      begin
        doc.find('//city/forecast/date[' + String(nr1) + ']/time[' + String(nr2) + ']/' + name)[0].content
      rescue
        ''
      end
    end
    
    def get_forecast_from_citycode (citycode)
      # do request:
      doc = self.do_request(API_QueryType::FORECAST, citycode)
      # check if an error occured:
      if doc.child.name == 'city'
        # parse credits:
        self.fill_credits(doc)
        # fill forecast array:
        forecast = Array.new
        i = 1
        doc.find('//city/forecast/date').each {
         |date|
         times = Array.new
         i2 = 1
         doc.find('//city/forecast/date[' + String(i) + ']/time').each {
           |time|
           times[i2-1] = {
             'date_local' => DateTime.strptime(doc.find('//city/forecast/date[' + String(i) + ']/time[' + String(i2) + ']/dhl')[0].content, '%Y-%m-%d %H:%M'),
             'date_utc' => DateTime.strptime(doc.find('//city/forecast/date[' + String(i) + ']/time[' + String(i2) + ']/dhu')[0].content, '%Y-%m-%d %H:%M'),
             'validity_time' => self.string_to_integer(self.try_forecast_response_field_time(doc, i, i2, 'p')),
             'weather_code' => self.string_to_integer(self.try_forecast_response_field_time(doc, i, i2, 'w')),
             'chance_rain_percent' => self.string_to_integer(self.try_forecast_response_field_time(doc, i, i2, 'pc')),
             'temp_min' => self.string_to_integer(self.try_forecast_response_field_time(doc, i, i2, 'tn')),
             'temp_max' => self.string_to_integer(self.try_forecast_response_field_time(doc, i, i2, 'tx')),
             'wind_direction_degrees' => self.string_to_integer(self.try_forecast_response_field_time(doc, i, i2, 'wd')),
             'wind_speed' => self.string_to_float(self.try_forecast_response_field_time(doc, i, i2, 'ws')),
             'weather_txt' => self.try_forecast_response_field_time(doc, i, i2, 'w_txt'),
             'wind_direction_txt' => self.try_forecast_response_field_time(doc, i, i2, 'wd_txt')
           }
           i2 += 1
         }
         forecast[i-1] = {
           'date_local' => DateTime.strptime(doc.find('//city/forecast/date[' + String(i) + ']/dhl')[0].content, '%Y-%m-%d %H:%M'),
           'date_utc' => DateTime.strptime(doc.find('//city/forecast/date[' + String(i) + ']/dhu')[0].content, '%Y-%m-%d %H:%M'),
           'validity_time' => self.string_to_integer(self.try_forecast_response_field_date(doc, i, 'p')),
           'weather_code' => self.string_to_integer(self.try_forecast_response_field_date(doc, i, 'w')),
           'chance_rain_percent' => self.string_to_integer(self.try_forecast_response_field_date(doc, i, 'pc')),
           'wind_direction_degrees' => self.string_to_integer(self.try_forecast_response_field_date(doc, i, 'wd')),
           'wind_speed' => self.string_to_float(self.try_forecast_response_field_date(doc, i, 'ws')),
           'times' => times
         }
         i += 1
        }
        # return data:
        {
          'name' => doc.find('//city/name')[0].content,
          'url' => 'http://www.wetter.com/' + doc.find('//city/url')[0].content,
          'plz' => doc.find('//city/post_code')[0].content,
          'forecast' => forecast
        }
      elsif doc.child.name == 'error'
        raise doc.find('//error/title')[0].content + ': ' + doc.find('//error/message')[0].content
      else
        raise 'Invalid API response.'
      end
    end
  end
end
