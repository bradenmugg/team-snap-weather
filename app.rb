require 'sinatra'
require 'json'
require 'httparty'
require 'pry'
require 'geocoder'

set :port, 3000
set :views, "views"

get '/' do
  erb :index
end

get '/oauth2/callback' do
  if params['code']
    @token = get_token(params['code'])
    @id = get_user_id(@token)
    @team_id = get_user_teams(@token, @id)
    @events = get_team_events(@token, @team_id)
    @data = build_events(@token, @events)
    erb :callback
  end
end

def get_token(code)
  response = HTTParty.post("https://auth.teamsnap.com/oauth/token?client_id=94ff5443c6026c1a30765180b8a4700f5ded6630175386b46995728132e3cc36&client_secret=043700e9324f83cbe6ee68cf1655b410a9358eb0582efc26c0090134c3105f89&redirect_uri=https%3A%2F%2Fteam-snap-weather.herokuapp.com%2Foauth2%2Fcallback&code=#{code}&grant_type=authorization_code")
  result = JSON.parse(response.body)
  result['access_token']
end

def send_http_request(token, url)
  headers = { "Authorization" => "Bearer #{token}" }
  response = HTTParty.get(
      url, 
      :headers => headers
    )
  result = JSON.parse(response.body)
end

def get_user_id(token)
  result = send_http_request(token, "https://api.teamsnap.com/v3/me")
  id = result['collection']['items'][0]['data'][0]['value']
end

def get_user_teams(token, user_id)
  result = send_http_request(token, "https://api.teamsnap.com/v3/teams/search?user_id=#{user_id}")
  team_id = result['collection']['items'][0]['data'][0]['value']
end

def get_team_events(token, team_id)
  result = send_http_request(token, "https://api.teamsnap.com/v3/events/search?team_id=#{team_id}")
  events = result['collection']['items']
end

def build_events(token, events)
  event_array = []
  Struct.new("Event", :name, :start_time, :end_time, :location, :temperature, :precipitation_chance, :precipitation_type)
  events.each do |event|
    name = event['data'][20]['value']
    start_time = event['data'][7]['value']
    end_time = event['data'][32]['value']
    if DateTime.iso8601(start_time).to_time.to_i > DateTime.now.to_time.to_i
      location = get_location(token, event)
      coords = Geocoder.search(location)[0].coordinates
      weather_data = get_weather_data(coords[0], coords[1], start_time)
      temperature = weather_data['currently']['temperature']
      precipitation_type = weather_data['currently']['precipType']
      precipitation_chance = weather_data['currently']['precipProbability']
      event_data = Struct::Event.new(name, end_time, start_time, location, temperature, precipitation_chance, precipitation_type)
      event_array.push(event_data)
    end
  end
  event_array
end

def get_location(token, event)
  result = send_http_request(token, "#{event['links'][5]['href']}")
  result['collection']['items'][0]['data'][2]['value']
end

def get_weather_data(lat, long, start_time)
  response = HTTParty.get("https://api.forecast.io/forecast/44d96faaa733feaf374291fe606474af/#{lat},#{long},#{start_time}")
end




