require 'sinatra'
require_relative 'find_shows'

get '/' do
	"You're probably looking for emersontv.ryancatalani.com."
end

get '/update' do
	generate_page('update')
	"Uploaded OK."
end

# get '/test' do
# 	generate_page('show')
# end