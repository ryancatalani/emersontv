require 'sinatra'
require_relative 'find_shows'

get '/' do
	"You're probably looking for emersontv.ryancatalani.com."
end

get '/update' do

	generate_page(true)

	"Uploaded OK."
end
