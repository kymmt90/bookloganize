require 'bookmeter_scraper'
require 'csv'
require 'thor'

class Bookloganize
  class BookloganizeError < StandardError; end

  STATUS = { read: '読み終わった', reading: 'いま読んでる', tsundoku: '積読', wish: '読みたい' }

  def initialize(email, password)
    @bookmeter = BookmeterScraper::Bookmeter.log_in(email, password)
    raise BookloganizeError, 'email or password not correct' unless @bookmeter.logged_in?
    @today = Time.now.strftime('%Y-%m-%d')
  end

  def csv
    result = ''
    result << read_books_csv.to_s
    result << reading_books_csv.to_s
    result << tsundoku_csv.to_s
    result << wish_list_csv.to_s
    result
  end

  private

  def read_books_csv
    asins_books_array = @bookmeter.read_books.uniq(&:uri).map { |b| [asin(b), b] }.flatten
    asins_books = Hash[*asins_books_array]
    CSV.generate(force_quotes: true) do |csv|
      asins_books.each do |asin, book|
        finished_date = book.read_dates[-1] # last finished date
        csv << row(asin, :read, finished_date)
      end
    end
  end

  def reading_books_csv
    asins = @bookmeter.reading_books.map { |b| asin(b) }
    CSV.generate(force_quotes: true) do |csv|
      asins.each do |asin|
        csv << row(asin, :reading)
      end
    end
  end

  def tsundoku_csv
    asins = @bookmeter.tsundoku.map { |b| asin(b) }
    CSV.generate(force_quotes: true) do |csv|
      asins.each do |asin|
        csv << row(asin, :tsundoku)
      end
    end
  end

  def wish_list_csv
    asins = @bookmeter.wish_list.map { |b| asin(b) }
    CSV.generate(force_quotes: true) do |csv|
      asins.each do |asin|
        csv << row(asin, :wish)
      end
    end
  end

  def asin(book)
    book.uri.split('/')[-1]
  end

  def row(asin, status_sym, finished_date = nil, registered_date = @today.to_s + ' 00:00:00')
    finished_date = finished_date.strftime('%Y-%m-%d') + ' 00:00:00' if finished_date
    # refs: http://booklog.jp/input/file
    # service ID, ASIN, 13-digits ISBN, category, rate, status, review, tag, memo, registered date, finished date
    [1, asin, '', '-', 3, STATUS[status_sym], '', '', '', registered_date.to_s, finished_date.to_s]
  end
end

class BookloganizeCLI < Thor
  desc 'csv EMAIL PASSWORD', 'csv'
  def csv(email, password)
    puts Bookloganize.new(email, password).csv
  end
end

BookloganizeCLI.start(ARGV)
