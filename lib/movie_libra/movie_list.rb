#!/usr/bin/env ruby

require 'json'
require 'csv'
require 'movie_libra/movie.rb'

module MovieLibra
  # MovieList class
  #
  # @example
  #   list = MovieLibra::MovieList.new('data/movies.json')
  #   list = MovieLibra::MovieList.new('data/movies.csv')
  #
  class MovieList
    include Enumerable
    # Supported file formats
    FORMATS = ['.json', '.csv'].freeze

    attr_accessor :list, :movies, :algos, :filters
    # Creates a new MovieLibra::MovieList object
    # @param [String] path                   Path to your CSV or JSON file
    # @attr [MovieLibra::MovieList] list     Returns self
    # @attr [Array] movies                   Returns array of movies
    # @attr [Hash] algos                     List of algorithms
    # @attr [Hash] filters                   List of filters
    def initialize(path)
      @movies   = load_data(path).map { |movie| Movie.new(self, movie) }
      @list     = self
      @algos    = {}
      @filters  = {}
    end

    # Finds movie by name
    # @return [MovieLibra::Movie] movie information
    # @example
    #   list.find_movie("The Shawshank Redemption")
    def find_movie(name)
      @movies.detect { |movie| movie.name.casecmp(name.downcase).zero? }
    end

    # Prints movies by given block
    # @return [String]
    # @example
    #   list.print { |movie| "#{movie.year}: #{movie.name}" }
    def print
      @movies.map { |i| puts yield(i) } if block_given?
      nil
    end

    # Adds sorting algorithm
    # @param algo [Symbol]  the algorithm name
    # @param block [&block]  the algorithm block
    # @example
    #   list.add_sort_algo(:genres_years) { |movie| [movie.genre, movie.year] }
    def add_sort_algo(algo, &block)
      @algos.store(algo, block)
    end

    # Sorts by algorithm or block
    # @return [Array] the sorted movie list
    # @param algo [Symbol]
    # @param block [&block]
    # @example
    #   list.sorted_by(:years)
    def sorted_by(algo = nil, &block)
      if @algos.include?(algo)
        algo = @algos[algo]
        @movies.sort_by(&algo)
      elsif block
        @movies.sort_by(&block)
      else
        raise ArgumentError, "Unknown algorithm #{algo}"
      end
    end

    # Adds filter for the movie list
    # @param filter [Symbol]  the filter name
    # @param block [&block]  the filter block
    # @example
    #   list.add_filter(:genres) { |movie, *genres| movie.genres?(*genres) }
    def add_filter(filter, &block)
      @filters.store(filter, block)
    end

    # Applies filter for the movie list
    # @return [Array] the filtered movie list
    # @param [Hash] attributes
    # @example
    #   list.filter(genres: ['Comedy', 'Drama'])
    def filter(attributes)
      attributes.inject(@movies) do |result, (title, value)|
        filter = @filters[title]
        raise ArgumentError, "Unknown filter #{title}" unless filter
        result.select { |movie| filter.call(movie, *value) }
      end
    end

    # Displays the longest movies
    # @return [Array] the list of N longest movies
    # @param [Integer] num
    # @example
    #   list.longest(10)
    def longest(num)
      @movies.sort_by(&:duration).last(num)
    end

    # Displays a list of the specified genre movies sorted by release date
    # @param genre [String] movie genre
    # @return [Array] movies list
    # @example
    #   list.sort_by_genre('Comedy')
    def select_by_genre(genre)
      @movies.select { |k| k.genre.include? genre }.sort_by(&:date)
    end

    # Displays all directors sorted by second name
    # @return [Array] directors
    # @example
    #   list.directors
    def directors
      @movies.map(&:director).sort_by { |words| words.split(' ').last }.uniq
    end

    # Displays the count of movies without skipped country
    # @return [Fixnum] the count of movies without skipped country
    # @example
    #   list.skip_country("USA")
    def skip_country(country)
      @movies.count { |k| k.country != country }
    end

    # Displays the count of movies by each director
    # @return [Hash] the count of movies by each director
    # @example
    #   list.count_by_director
    def count_by_director
      @movies.group_by(&:director).map { |k, v| [k, v.count] }.sort_by { |_k, v| v }.reverse.to_h
    end

    # Displays the movies by director
    # @return [Array] the movies by director
    # @example
    #   list.by_director("Frank Darabont")
    def by_director(director)
      @movies.select { |m| m.director == director }.map(&:name)
    end

    # Displays the count of movies by each actor
    # @return [Hash] the count of movies by each actor
    # @example
    #   list.count_by_actor
    def count_by_actor
      @movies.map(&:actors).flatten.each_with_object(Hash.new(0)) { |acc, n| n[acc] += 1 }.sort_by { |_k, v| v }.reverse.to_h
    end

    # Displays the statistics of the movies shot each month
    # @return [Hash] the statistics of the movies shot each month
    # @example
    #   list.month_stats
    def month_stats
      @movies.map { |k| k.date.mon }.each_with_object(Hash.new(0)) { |acc, n| n[acc] += 1 }.sort.to_h
    end

    def each(&block)
      @movies.each(&block)
    end

    protected

    # Loads movies data from JSON or CSV file.
    # @return [Array] the array of movie hashes
    def load_data(path)
      raise ArgumentError, "File #{path} not found or has not incorrect format." unless File.exist?(path) && FORMATS.include?(File.extname(path))
      case File.extname(path)
      when '.json'
        parse_json(path)
      when '.csv'
        parse_csv(path)
      end
    end

    # Parse from JSON
    # @return [Array] the array of movie hashes
    def parse_json(path)
      JSON.parse(open(path).read, symbolize_names: true)
    end

    # Parse from CSV
    # @return [Array] the array of movie hashes
    def parse_csv(path)
      CSV.foreach(path, col_sep: '|', headers: true, header_converters: :symbol, encoding: 'UTF-8').map do |row|
        row.to_h.update(row) { |x, y| row[x] = y.include?(',') ? y.split(',') : y }
      end
    end
  end
end
