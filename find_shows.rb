require 'nokogiri'
require 'open-uri'
require 'json'
require 'net/ftp'
require 'stringio'
require 'erb'
require 'net/http'
require 'uri'
require 'time'
require 'tzinfo'

def generate_page type=nil
	init_channels = channels
	shows = find_shows(true)
	@channels = []

	init_channels.each do |channel|
		c = channel
		c_show = shows[channel[0]]
		unless c_show.nil? || c_show.count(nil) == c_show.count
			c << c_show
		end
		@channels << c
	end

	if type == 'update'
		index_str = erb :index
	elsif type == 'show'
		return erb :index
	else
		index_str_erb = ERB.new(File.new('views/index.erb').read)
		index_str = index_str_erb.result
	end

	upload(index_str, 'index.html')
end

private

def json_urls
	time_slugs = []
	0.upto(2) do |offset|
		t = Time.now.utc + (offset * 60 * 30)
		hour_slug = t.hour
		min_slug = '00'
		cur_min = t.min
		if cur_min < 20
			min_slug = '00'
		elsif cur_min < 50
			min_slug = '30'
		else
			min_slug = '00'
			hour_slug += 1
		end
		date_slug = t.strftime('%Y-%m-%d')
		time_slugs << "#{date_slug}/#{hour_slug}:#{min_slug}"
	end

	urls = []
	time_slugs.each do |time_slug|
		0.upto(2) do |x|
			urls << "http://tvlistings.aol.com/shows/MA63993/events/#{time_slug}/chunk/#{x}/offset/0.json"
		end
	end

	return urls
end

def find_shows from_json=false
	channels = {}
		# channels["123456"] => { channel_number: 100, shows: ["Show Name"], show_times: ["3:30 pm"] }
		# where "123456" is the TV guide ID

	tv_guide_url = 'http://tvlistings.aol.com/listings/ma/boston/emerson-college/MA63993'
	doc = Nokogiri::HTML(open(tv_guide_url))
	doc.css('.grid-source').each do |channel_div|
		id = channel_div.attr('id').gsub('grid-source-','')
		channels[id] = {}
		channels[id][:channel_number] = channel_div.css('.grid-channel').inner_text.to_i
		channels[id][:shows] = []
		channels[id][:show_times] = []
	end

	tz = TZInfo::Timezone.get('America/New_York')
	dst = tz.period_for_utc(tz.now).dst?

	if from_json
		urls = json_urls
		show_data = []
		urls.each do |url|
			begin
				uri = URI.parse(url)
				res = Net::HTTP.get_response(uri)
				body = res.body
				json = JSON.parse(body)
				show_data << json
			end
		end
		show_data.flatten!
		show_data.each do |h|
			channel_id = h['sourceId']
			time = Time.parse("#{h['dt']} UTC")
			time -= dst ? 4*60*60 : 5*60*60
			show_time = time.strftime('%l:%M %P').strip
			show_name = h['title']

			channels[channel_id][:shows] << show_name
			channels[channel_id][:show_times] << show_time
		end
	else
		doc.css('.grid-event').each do |show_div|
			id = show_div.attr('id').gsub('id-','')
			id_comps = id.split('_')
			channel_id = id_comps.first
			shour, smin = id_comps.last.split('X').map(&:to_i)
			show_name = show_div.attr('title')

			pm = false
			shour -= dst ? 4 : 5
			shour += 24 if shour < 0
			if shour >= 12
				pm = true
				shour -= 12
			end
			shour = 12 if shour == 0
			smin = smin.to_s
			smin << '0' if smin.length == 1
			show_time = "#{shour}:#{smin} "
			show_time += pm ? 'pm' : 'am'

			channels[channel_id][:shows] << show_name
			channels[channel_id][:show_times] << show_time
		end
	end

	current_shows = []
	channels.each do |k,v|
		channel = v[:channel_number]
		current_show = v[:shows][0,2]
		current_show_time = v[:show_times][0,2]

		current_shows[channel] = []
		current_shows[channel] << current_show[0]
		current_shows[channel] << current_show_time[0]
		current_shows[channel] << current_show[1]
		current_shows[channel] << current_show_time[1]
	end

	# => [ ["Show name", "Show start time"], [], ... ]
	# index corresponds to channel number
	return current_shows

end

def channels

	channels = [
		[2, "PBS"],
		[3, "The Emerson Channel"],
		[6, "CBS"],
		[8, "ABC"],
		[9, "NBC"],
		[10, "Fox"],
		[11, "TV 38"],
		[12, "CW"],
		[13, "ESPN"],
		[14, "CNN"],
		[15, "Headline News"],
		[16, "Fox News"],
		[17, "CNBC"],
		[18, "TBS"],
		[21, "ESPN2"],
		[23, "USA"],
		[24, "TNT"],
		[25, "Nickelodeon"],
		[26, "CSPAN"],
		[27, "Weather Channel"],
		[28, "NESN"],
		[29, "Disney"],
		[30, "Discovery"],
		[31, "A&E"],
		[32, "MSNBC"],
		[33, "Travel Chanel"],
		[34, "History Channel"],
		[36, "Fox Sports New England"],
		[37, "Comedy Central"],
		[38, "E! Entertainment"],
		[39, "Lifetime"],
		[40, "Cartoon Network"],
		[41, "VH1"],
		[42, "MTV"],
		[46, "CSPAN2"],
		[47, "BET"],
		[48, "Bravo"],
		[49, "TLC"],
		[56, "The Emerson Channel"],
		[57, "Emerson Info 57"],
		[60, "Emerson Journalism Channel"],
		[63, "mtvU"],
		[65, "WECB"]
	]

	return channels

end

def upload(data, filename)

	Net::FTP.open('ftp.ryancatalani.com') do |ftp|
		ftp.passive = true
		ftp.login(ENV['ECTV_USER'], ENV['ECTV_PASS'])

		# Based on http://stackoverflow.com/questions/5223763/how-to-ftp-in-ruby-without-first-saving-the-text-file
		f = StringIO.new(data)
		begin
			ftp.storlines("STOR #{filename}", f)
		ensure
			f.close
		end

	end

end