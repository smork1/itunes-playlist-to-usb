#!/usr/bin/env ruby

require 'rubygems'
require 'thor'
require 'plist'
require 'uri'
require 'fileutils'

class PlaylistExporter < Thor
  desc "process", "process playlist"
  method_option :verbose, :type => :boolean, :default => false, :aliases => "-v",
:desc => "running in verbose mode will also show each file as it's copied"
  method_option :debug, :type => :boolean, :default => false, :aliases => "-d",
:desc => "in debug mode files will not actually be copied"
  method_option :force, :type => :boolean, :default => false, :aliases => "-f",
:desc => "normally, copying a file is skipped if a file with the same name and size already exists in the destination. Force mode always copies."

  def process
    puts "*** Verbose Mode" if options.verbose?
    puts "*** Debug Mode" if options.debug?
    puts "*** Force Mode" if options.force?

    get_exported_file
    get_target_directory

    read_plist

    initialize_catalog
    process_tracks

    copy_catalog
  end

  private
  def get_exported_file
    found = false

    until found
      @exported_file = ask("Location of Playlist [~/Desktop/usb/playlist.xml]")
      @exported_file = "~/Desktop/usb/playlist.xml" if @exported_file == ""
      @exported_file = File.expand_path(@exported_file) 

      if File.exists?(@exported_file)
        found = true
      else
        say "File #{@exported_file} does not exist", :red
      end
    end
  end

  def get_target_directory
    found = false

    until found
      @target_directory = ask("Location to which music should be copied [~/Desktop/usb]")
      @target_directory = "~/Desktop/usb/" if @target_directory == ""
      @target_directory += "/" unless ("/" == @target_directory[-1])

      @target_directory = File.expand_path(@target_directory) 

      if File.exists?(@target_directory)
        found = true
      else
        say "Directory #{@target_directory} does not exist", :red
      end
    end
  end

  def read_plist
    say "Reading #{@exported_file}", :green
    @export = Plist::parse_xml(@exported_file)
    @tracks = @export["Tracks"]
  end

  def initialize_catalog
    @catalog = {}
  end

  def process_tracks
    @tracks.each do |id, info|
      add_track_to_catalog(info)
    end
  end

  def add_track_to_catalog(info)
	puts "DBG: #{info}"
    name = clean_string(info["Name"])
    album = clean_string(info["Album"], 25)
    genre = clean_string(info["Genre"], 20)
    artist = clean_string(info["Artist"], 25)
    album_artist = clean_string(info["Album Artist"], 25)
    track_number = info["Track Number"] || 0
    file_uri = URI(info["Location"])

    original_file = URI.decode(file_uri.path)
    original_file =~ /.*\.(.*)/
    file_type = $1

	 if album_artist != 'Blank'
		 @catalog[album_artist] ||= {}
		 @catalog[album_artist][album] ||= []

		 if options.verbose?
			puts "    Cataloging   : #{name} / #{album} / #{genre} / #{track_number}"
		 end
		 target_name = "%02d-#{name}.#{file_type}" % track_number
		 @catalog[album_artist][album] << {:name => target_name, :file => original_file}
	 else
		 @catalog[artist] ||= {}
		 @catalog[artist][album] ||= []

		 if options.verbose?
			puts "    Cataloging   : #{name} / #{album} / #{genre} / #{track_number}"
		 end
		 target_name = "%02d-#{name}.#{file_type}" % track_number
		 @catalog[artist][album] << {:name => target_name, :file => original_file}
	 end

  end

  def clean_string(s, cutoff_at = nil)
    unless s.is_a?(String)
      s = 'Blank'
    end

    if cutoff_at
      s = s[0, cutoff_at]
    end

    s && s.gsub(/\/|\(|\)/, '_')
  end

  def copy_catalog
  sorted_catalog = @catalog.sort_by {|e| [e[0], e[1]]}
    sorted_catalog.each do |artist, albums|
      puts "Artist: #{artist}"
      artist_path = "#{@target_directory}/#{artist}"

      unless options.debug?
        FileUtils.mkdir(artist_path) unless File.exists?(artist_path)
      end

		sorted_albums = albums.sort_by {|e| [e[0], e[1]]}
      sorted_albums.each do |album, tracks|
        puts "  Album: #{album}"
        album_path = "#{@target_directory}/#{artist}/#{album}"

        unless options.debug?
          FileUtils.mkdir(album_path) unless File.exists?(album_path)
        end

#		  puts "Tracks: #{tracks}"


		  sorted_tracks = tracks.sort {|a,b| a[:name] <=> b[:name]}
#		  puts "Tracks SORTED: #{sorted_tracks}"

        sorted_tracks.each do |track|
          full_destination = "#{@target_directory}/#{artist}/#{album}/#{track[:name]}"
          source = track[:file]

          if options.verbose?
            puts "    Creating   : #{track[:name]}"
            puts "       source  : #{track[:file]}"
          end

          if File.exists?(source)
            if options.force?
              copy_file(source, full_destination)
            else
              if File.exists?(full_destination) && (File.size(source) == File.size(full_destination))
                puts "       *** Destination file already exists"
              else
                copy_file(source, full_destination)
              end
            end
          else
            puts "       *** Source does not exist"
          end
        end
      end
    end
  end

  def copy_file(source, full_destination)
    unless options.debug?
      FileUtils.copy_file(source, full_destination)
    end
  end
end

PlaylistExporter.start
