#!/usr/bin/ruby
require './weather.rb'

project = '...'
apikey = '...'

puts "Willkommen im WetterFinder 0.1!"
puts "Womit willst du deinen Ort suchen?"
puts "  1: Name des Orts"
puts "  2: Postleitzahl"
puts "  3: gemischte Suche"
puts "  0: Programm beenden"
print "Bitte triff deine Wahl: "
choice = gets
begin
  if not choice.numeric?
    raise Weather::CustomException
  end
  case Integer(choice)
    when 0
      raise Weather::CustomException
    when 1
      print "Bitte gib den Namen des Orts ein: "
      input = gets
      input.strip!
      if input.length == 0
        puts "-----"
        puts "Eingabe invalid."
        raise Weather::CustomException
      else
        api = Weather::API.new(project, apikey)
        response = api.get_citycodes_from_name(input)
      end
    when 2
      print "Bitte gib die PLZ ein: "
      input = gets
      input.strip!
      if input.length == 0 or not input.numeric?
        puts "-----"
        puts "Eingabe invalid."
        raise Weather::CustomException
      else
        api = Weather::API.new(project, apikey)
        response = api.get_citycodes_from_plz(input)
      end
    when 3
      print "Bitte gib den Suchbegriff ein: "
      input = gets
      input.strip!
      if input.length == 0
        puts "-----"
        puts "Eingabe invalid."
        raise Weather::CustomException
      else
        api = Weather::API.new(project, apikey)
        response = api.get_citycodes_from_mixed(input)
      end
  end
rescue Weather::CustomException
  puts "Programm wird beendet."
else
  # go on with response
  begin
    case response['hits']
      when 0
        puts "-----"
        puts "Keine Ergebnisse."
        raise Weather::CustomException
      when 1
        if response['exact_match'] == true
          puts "Nur ein Ergebnis (exakter Treffer):"
        else
          puts "Nur ein Ergebnis (kein exakter Treffer):"
        end
        puts "  CityCode: " + response['results'][0]['citycode']
        puts "  PLZ: " + response['results'][0]['plz']
        puts "  Name: " + response['results'][0]['name']
        puts "  Stadtteil: " + response['results'][0]['quarter']
        puts "  ADM1 Code: " + response['results'][0]['adm1_code']
        puts "  ADM1 Name: " + response['results'][0]['adm1_name']
        puts "  ADM2 Name: " + response['results'][0]['adm2_name']
        puts "  ADM4 Name: " + response['results'][0]['adm4_name']
        print "Soll das Wetter fuer diesen Ort gesucht werden? (1=ja) "
        choice = gets
        choice.strip!
        if choice == "1"
          citycode = response['results'][0]['citycode']
        else
          raise Weather::CustomException
        end
      else
        if response['exact_match'] == true
          puts "Mehrere Ergebnisse (exakter Treffer):"
        else
          puts "Mehrere Ergebnisse (kein exakter Treffer):"
        end
        citycodes = Array.new
        i = 1
        response['results'].each {
          |result|
          x = String(i)
          if x.length == 1
            x = "0" + x
          end
          puts "  (" + x + ") CityCode: " + result['citycode']
          puts "       PLZ: " + result['plz']
          puts "       Name: " + result['name']
          puts "       Stadtteil: " + result['quarter']
          puts "       ADM1 Code: " + result['adm1_code']
          puts "       ADM1 Name: " + result['adm1_name']
          puts "       ADM2 Name: " + result['adm2_name']
          puts "       ADM4 Name: " + result['adm4_name']
          citycodes[i-1] = result['citycode']
          i += 1
        }
        print "Bitte waehle den passenden Ort: "
        choice = gets
        if not choice.numeric?
          raise Weather::CustomException
        end
        choice = Integer(choice)
        if choice < 1
          raise Weather::CustomException
        end
        if choice > citycodes.length
          raise Weather::CustomException
        end
        citycode = citycodes[choice-1]
    end
  rescue Weather::CustomException
    puts "Programm wird beendet."
  else
    # go on with citycode
    result = api.get_forecast_from_citycode(citycode)
    puts "===== WETTERVORHERSAGE fuer: " + result['plz'] + " " + result['name'] + " ====="
    puts "siehe auch: " + result['url']
    result['forecast'].each {
      |day|
      puts "  " + day['date_local'].strftime('%a %d %b %Y')
      puts "    Regen: " + String(day['chance_rain_percent']) + "%"
      puts "    Wind: " + String(day['wind_speed']) + " km/h @ " + String(day['wind_direction_degrees']) + " Grad"
      day['times'].each {
        |time|
        puts "    " + time['date_local'].strftime('%H:%M')
        puts "      Allgemein: " + time['weather_txt']
        puts "      Regen: " + String(time['chance_rain_percent']) + "%"
        puts "      Temperatur: " + String(time['temp_min']) + " bis " + String(time['temp_max']) + " Grad Celsius"
        puts "      Wind: " + String(time['wind_speed']) + " km/h @ " + String(time['wind_direction_degrees']) + " Grad (" + time['wind_direction_txt'] + ")"
      }
    }
    puts " => " + api.credits['text'] + " (" + api.credits['link'] + ")"
  end
end
