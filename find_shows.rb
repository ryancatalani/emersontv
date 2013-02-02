require 'nokogiri'
require 'open-uri'
require 'json'
require 'net/ftp'
require 'stringio'
require 'erb'

def generate_page for_sinatra=false
	init_channels = channels
	shows = find_shows
	@channels = []

	init_channels.each do |channel|
		c = channel
		c_show = shows[channel[0]]
		unless c_show.nil? || c_show.count(nil) == c_show.count
			c << c_show
		end
		@channels << c
	end

	if for_sinatra
		index_str = erb :index
	else
		index_str_erb = ERB.new(File.new('views/index.erb').read)
		index_str = index_str_erb.result
	end

	upload(index_str, 'index.html')
end

private

def find_shows
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
		shour = 12 if shour == 0
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