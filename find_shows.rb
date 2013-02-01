require 'sinatra'
require 'nokogiri'
require 'open-uri'
require 'json'


get '/shows' do
	content_type :json
	current_shows_json
end


private

def print_url
	hour_slug = Time.now.hour
	min_slug = '00'
	cur_min = Time.now.min
	if cur_min < 20
		min_slug = '00'
	elsif cur_min < 50
		min_slug = '30'
	else
		min_slug = '00'
		hour_slug += 1
	end
	time_slug = "%Y-%m-%d/#{hour_slug}:#{time_slug}"
	url = "http://tvlistings.aol.com/listings/ma/boston/emerson-college/MA63993/print/#{time_slug}"
end

def main_url
	return "http://tvlistings.aol.com/listings/ma/boston/emerson-college/MA63993"
end

def find_shows
	channels = {}
		# channels["123456"] => { channel_number: 100, shows: ["Show Name"], show_times: ["3:30 pm"] }
		# where "123456" is the TV guide ID

	doc = Nokogiri::HTML(open(main_url))
	doc.css('.grid-source').each do |channel_div|
		id = channel_div.attr('id').gsub('grid-source-','')
		channels[id] = {}
		channels[id][:channel_number] = channel_div.css('.grid-channel').inner_text.to_i
		channels[id][:shows] = []
		channels[id][:show_times] = []
	end

	doc.css('.grid-event').each do |show_div|
		id = show_div.attr('id').gsub('id-','')
		id_comps = id.split('_')
		channel_id = id_comps.first
		shour, smin = id_comps.last.split('X').map(&:to_i)
		show_name = show_div.attr('title')

		pm = false
		shour -= Time.now.dst? ? 4 : 5
		shour += 24 if shour < 0
		if shour >= 12
			pm = true
			shour -= 12
		end
		smin = smin.to_s
		smin << '0' if smin.length == 1
		show_time = "#{shour}:#{smin} "
		show_time += pm ? 'p.m.' : 'a.m.'

		channels[channel_id][:shows] << show_name
		channels[channel_id][:show_times] << show_time
	end


	current_shows = []
	channels.each do |k,v|
		channel = v[:channel_number]
		current_show = v[:shows].first
		current_show_time = v[:show_times].first

		current_shows[channel] = []
		current_shows[channel] << current_show
		current_shows[channel] << current_show_time
	end

	return current_shows

end

def current_shows_json

	shows = find_shows
	return shows.to_json

end