#!/usr/bin/ruby
# -*- coding: utf-8 -*-
require './weather.rb'
require 'gtk2'

project = '...'
apikey = '...'
$search_request_running = false

def show_dialog (title, message)
  dlg = Gtk::Dialog.new(
    title,
    $window,
    Gtk::Dialog::DESTROY_WITH_PARENT,
    [ Gtk::Stock::OK, Gtk::Dialog::RESPONSE_NONE ]
  )
  dlg.signal_connect('response') {
    dlg.destroy
  }
  dlg.vbox.add(Gtk::Label.new(message))
  dlg.show_all
end

def handle_search_response (response)
  case response['hits']
    when 0
      show_dialog("Fehler", "Keine Ergebnisse.")
      $search_request_running = false
    when 1
      dlg = Gtk::Dialog.new(
        "Ergebnis",
        $window,
        Gtk::Dialog::DESTROY_WITH_PARENT,
        [ Gtk::Stock::OK, Gtk::Dialog::RESPONSE_ACCEPT ],
        [ Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_REJECT ]
      )
      dlg.signal_connect('response') {
        |d, r|
        dlg.destroy
        case r
          when Gtk::Dialog::RESPONSE_ACCEPT
            puts "accepted"
            code = response['results'][0]['citycode']
            handle_citycode(code)
          when Gtk::Dialog::RESPONSE_REJECT
            puts "rejected"
        end
      }
      dlg.vbox.add(Gtk::Label.new("Name: " + response['results'][0]['name']))
      dlg.vbox.add(Gtk::Label.new("PLZ: " + response['results'][0]['plz']))
      dlg.vbox.add(Gtk::Label.new("Stadtteil: " + response['results'][0]['quarter']))
      dlg.vbox.add(Gtk::Label.new("CityCode: " + response['results'][0]['citycode']))
      dlg.vbox.add(Gtk::Label.new("ADM1 Code: " + response['results'][0]['adm1_code']))
      dlg.vbox.add(Gtk::Label.new("ADM1 Name: " + response['results'][0]['adm1_name']))
      dlg.vbox.add(Gtk::Label.new("ADM2 Name: " + response['results'][0]['adm2_name']))
      dlg.vbox.add(Gtk::Label.new("ADM4 Name: " + response['results'][0]['adm4_name']))
      dlg.show_all
      $search_request_running = false
    else
      quit = false
      i = 0
      response['results'].each {
        |result|
        if not quit
          dlg = Gtk::Dialog.new(
            "Ergebnis " + String(i+1) + " von " + String(response['hits']),
            $window,
            Gtk::Dialog::DESTROY_WITH_PARENT,
            [ Gtk::Stock::OK, Gtk::Dialog::RESPONSE_ACCEPT ],
            [ Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_REJECT ]
          )
          dlg.signal_connect('response') {
            |d, r|
            dlg.destroy
            case r
              when Gtk::Dialog::RESPONSE_ACCEPT
                puts "accepted"
                quit = true
              when Gtk::Dialog::RESPONSE_REJECT
                puts "rejected"
                i += 1
            end
          }
          dlg.vbox.add(Gtk::Label.new("Name: " + result['name']))
          dlg.vbox.add(Gtk::Label.new("PLZ: " + result['plz']))
          dlg.vbox.add(Gtk::Label.new("Stadtteil: " + result['quarter']))
          dlg.vbox.add(Gtk::Label.new("CityCode: " + result['citycode']))
          dlg.vbox.add(Gtk::Label.new("ADM1 Code: " + result['adm1_code']))
          dlg.vbox.add(Gtk::Label.new("ADM1 Name: " + result['adm1_name']))
          dlg.vbox.add(Gtk::Label.new("ADM2 Name: " + result['adm2_name']))
          dlg.vbox.add(Gtk::Label.new("ADM4 Name: " + result['adm4_name']))
          dlg.show_all
          dlg.run
        end
      }
      if quit
        code = response['results'][i]['citycode']
        handle_citycode(code)
      end
      $search_request_running = false
  end
end

def handle_citycode (code)
  # do request:
  puts "Got CityCode: " + code
  result = $api.get_forecast_from_citycode(code)
  # show dialog:
  dlg = Gtk::Dialog.new(
    "Wettervorhersage für: " + result['plz'] + " " + result['name'],
    $window,
    Gtk::Dialog::DESTROY_WITH_PARENT,
    [ Gtk::Stock::OK, Gtk::Dialog::RESPONSE_NONE ]
  )
  dlg.signal_connect('response') {
    dlg.destroy
  }
  hbox1 = Gtk::HBox.new(false, 0)
  dlg.vbox.add(hbox1)
  result['forecast'].each {
    |day|
    vbox1 = Gtk::VBox.new(false, 0)
    hbox1.pack_start(vbox1, true, true, 0)
    vbox1.pack_start(Gtk::Label.new("== " + day['date_local'].strftime('%a %d %b %Y') + " =="), true, true, 0)
    vbox1.pack_start(Gtk::Label.new("Regen: " + String(day['chance_rain_percent']) + "%"), true, true, 0)
    vbox1.pack_start(Gtk::Label.new("Wind: " + String(day['wind_speed']) + " km/h @ " + String(day['wind_direction_degrees']) + " Grad"), true, true, 0)
    day['times'].each {
      |time|
      vbox1.pack_start(Gtk::Label.new("= " + time['date_local'].strftime('%H:%M') + " ="), true, true, 0)
      vbox1.pack_start(Gtk::Label.new("Allgemein: " + time['weather_txt']), true, true, 0)
      vbox1.pack_start(Gtk::Label.new("Regen: " + String(time['chance_rain_percent']) + "%"), true, true, 0)
      vbox1.pack_start(Gtk::Label.new("Temperatur: " + String(time['temp_min']) + " bis " + String(time['temp_max']) + " Grad Celsius"), true, true, 0)
      vbox1.pack_start(Gtk::Label.new("Wind: " + String(time['wind_speed']) + " km/h @ " + String(time['wind_direction_degrees']) + " Grad (" + time['wind_direction_txt'] + ")"), true, true, 0)
    }
  }
  dlg.vbox.add(Gtk::Label.new($api.credits['text'] + " (" + $api.credits['link'] + ")"))
  dlg.show_all
  dlg.run
end

# API:
$api = Weather::API.new(project, apikey)
# window:
$window = Gtk::Window.new
$window.signal_connect('delete_event') {
  puts "delete event occurred"
  false
}
$window.signal_connect('destroy') {
  puts "destroy event occurred"
  Gtk.main_quit
}
# HBOX1:
hbox1 = Gtk::HBox.new(false, 0)
$window.add(hbox1)
# VBOX1:
vbox1 = Gtk::VBox.new(false, 0)
hbox1.pack_start(vbox1, true, true, 0)
# label1:
label1 = Gtk::Label.new('PLZ:')
vbox1.pack_start(label1, true, true, 0)
# label2:
label2 = Gtk::Label.new('Name des Orts:')
vbox1.pack_start(label2, true, true, 0)
# label3:
label3 = Gtk::Label.new('Suchbegriff:')
vbox1.pack_start(label3, true, true, 0)
# VBOX2:
vbox2 = Gtk::VBox.new(false, 0)
hbox1.pack_start(vbox2, true, true, 0)
# entry1:
entry1 = Gtk::Entry.new
vbox2.pack_start(entry1, true, true, 0)
# entry2:
entry2 = Gtk::Entry.new
vbox2.pack_start(entry2, true, true, 0)
# entry3:
entry3 = Gtk::Entry.new
vbox2.pack_start(entry3, true, true, 0)
# VBOX3:
vbox3 = Gtk::VBox.new(false, 0)
hbox1.pack_start(vbox3, true, true, 0)
# button1:
button1 = Gtk::Button.new('Suchen!')
vbox3.pack_start(button1, true, true, 0)
button1.signal_connect('clicked') {
  if $search_request_running
    show_dialog("Fehler", "Bitte warten, es läuft schon eine Suche!")
  else
    puts "button1 (plz search) clicked"
    input = entry1.text
    input.strip!
    if input.length == 0 or not input.numeric?
      show_dialog("Fehler", "Ungültige Eingabe!")
    else
      $search_request_running = true
      begin
        response = $api.get_citycodes_from_plz(input)
      rescue Exception => e
        $search_request_running = false
        show_dialog("Fehler", "Antwort von der API: " + String(e))
      else
        handle_search_response(response)
      end
    end
  end
}
# button2:
button2 = Gtk::Button.new('Suchen!')
vbox3.pack_start(button2, true, true, 0)
button2.signal_connect('clicked') {
  if $search_request_running
    show_dialog("Fehler", "Bitte warten, es läuft schon eine Suche!")
  else
    puts "button2 (name search) clicked"
    input = entry2.text
    input.strip!
    if input.length == 0
      show_dialog("Fehler", "Ungültige Eingabe!")
    else
      $search_request_running = true
      begin
        response = $api.get_citycodes_from_name(input)
      rescue Exception => e
        $search_request_running = false
        show_dialog("Fehler", "Antwort von der API: " + String(e))
      else
        handle_search_response(response)
      end
    end
  end
}
# button3:
button3 = Gtk::Button.new('Suchen!')
vbox3.pack_start(button3, true, true, 0)
button3.signal_connect('clicked') {
  if $search_request_running
    show_dialog("Fehler", "Bitte warten, es läuft schon eine Suche!")
  else
    puts "button3 (mixed search) clicked"
    input = entry3.text
    input.strip!
    if input.length == 0
      show_dialog("Fehler", "Ungültige Eingabe!")
    else
      $search_request_running = true
      begin
        response = $api.get_citycodes_from_mixed(input)
      rescue Exception => e
        $search_request_running = false
        show_dialog("Fehler", "Antwort von der API: " + String(e))
      else
        handle_search_response(response)
      end
    end
  end
}
# main loop:
$window.show_all
Gtk.main
