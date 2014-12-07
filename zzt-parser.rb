require "rubygems"
require "bundler/setup"
Bundler.require

class String
  #assumes that bytes don't need to be reversed (default behavior)
  def hex_to_integer(reverse=false)
    if(reverse)
      bytes = []
      idx = 0
      while(idx < self.length)
        bytes.unshift(self[idx..(idx+2)])
      end
      bytes.join('').convert_base(16, 10).to_i

    else
      self.convert_base(16, 10).to_i
    end
  end

  def hex_to_bin
    [self.gsub(/ /, '')].pack('H*')
  end

  def convert_base(from, to)
    self.to_i(from).to_s(to)
    # In Ruby 1.9.2+ the more strict below is possible:
    # Integer(self, from).to_s(to)
  end
end

#puts File.read("./TOUR.ZZT")[0..3].to_hex_string

#tour_content = IO.read("./UNTITLED.ZZT")
tour_content = IO.read("./TOUR.ZZT")
#puts tour_content[0...2].to_hex_string

module Zzt

  class Hex
    def self.get(str, idx, len=1)
      if(idx.is_a?(String))
        idx = idx.upcase.hex_to_integer
      end
      
      if(len.is_a?(String))
        idx2 = len.upcase.hex_to_integer
        len = idx2 - idx
      end

      str[idx..(idx+len)].to_hex_string.split(/ /).join(' ')
    end

    def self.get_integer(str, idx, len=1)
      if(idx.is_a?(String))
        idx = idx.upcase.hex_to_integer
      end

      if(len.is_a?(String))
        idx2 = len.upcase.hex_to_integer
        len = idx2 - idx
      end

      #puts "idx: #{idx}, len: #{len}, str: #{str[idx..(idx+len)].to_hex_string}"

      hex_string = str[idx..(idx+len)].to_hex_string.split(/ /).reverse.join('')
      (hex_string.hex_to_integer)
    end

    def self.get_string(str, idx, len=1)
      if(idx.is_a?(String))
        idx = idx.upcase.hex_to_integer
      end

      if(len.is_a?(String))
        idx2 = len.upcase.hex_to_integer
        len = idx2 - idx
      end

      hex_string = str[idx..(idx+len)].to_hex_string.split(/ /).join('')
      [hex_string].pack('H*')
    end
  end

  class Common
    def to_s(instance_variables=nil)
      if(instance_variables.nil?)
        self.inspect().gsub(/, /, "\n")
        
      else
        variables = instance_variables.map do |v|
          value = self.instance_variable_get(v)
          value = "\"#{value}\"" if value.is_a?(String)
          "#{v}: #{value}"
        end

        object_id = ('%x' % (self.object_id << 1)).rjust(14, "0")
        "#<#{self.class.name}:0x#{object_id} #{variables.join(", ")}>"
      end
    end

    def initialize(info)
      info.keys.each do |key|
        if info[key].keys.include?(:default)
          value = info[key][:default]
          self.instance_variable_set("@#{key.to_s}", value)
        end

        self.class.instance_eval do
          attr_accessor key
        end
      end
    end

    def size(info)
      info.keys.select{|k| info[k].keys.include?(:size)}.inject(0){|total,key| 
        value = (info[key][:size].is_a?(Symbol)) ? self.send(info[key][:size]) : info[key][:size]
        value + total
      }
    end

    def parse(info, str, offset=0, &blk)
      # bubble prioritized properties to the top
      # perhaps one property depends on one already being extracted
      keys = info.keys.sort{|x, y| 
        info[y][:priority].to_i <=> info[x][:priority].to_i
      }

      offset = (offset.is_a?(String)) ? offset.hex_to_integer : offset

      keys.select{|k| !(info[:excludes][:properties] + [:excludes]).include?(k)}.each do |key|
        start = ((info[key][:start].is_a?(String)) ? info[key][:start].hex_to_integer : info[key][:start]) + offset
        size_value = (info[key][:size].is_a?(Symbol)) ? self.send(info[key][:size]) : info[key][:size]
        size = size_value - 1
        zero_indexed = info[key][:zero_indexed]

        if( info[key].keys.include?( :display_size ) )
          if(info[key][:display_size].is_a?(Symbol))
            size = instance_variable_get("@#{info[key][:display_size].to_s}")
          else
            size = info[key][:display_size]
          end

          # take into account zero-based counting
          size -= 1
        end

        case(info[key][:type])
        when :raw
          value = Hex.get(str, start, size)
        when :integer
          value = Hex.get_integer(str, start, size)
          value += 1 if zero_indexed
        else
          value = Hex.get_string(str, start, size)
        end

        if(block_given?)
          blk.call(key, value)
        else
          self.instance_variable_set("@#{key.to_s}", value)
        end
      end
    end

    alias_method :super_parse, :parse
  end

  class Flag < Common
    INFO = {
      name_length: {start: "00", size: 1, type: :integer, priority: 100}, 
      name: {start: "01", size: 20, display_size: :name_length, type: :string}, 
      excludes: {properties: []}
    }

    def initialize()
      super(INFO)
    end

    def parse(str)
      super(INFO, str)
    end
  end

  class Header < Common
    # the order of key appearance is very important
    # perhaps create a separate array to ensure that the order always remains the same?
    INFO = {
      magic_number: {start: "00", size: 2, type: :raw}, 
      boards_count: {start: "02", size: 2, type: :integer, zero_indexed: true}, 
      ammo: {start: "04", size: 2, type: :integer, default: 0}, 
      gems: {start: "06", size: 2, type: :integer, default: 0}, 
      keys: {start: "08", size: 7, item: {size: 1, type: :integer}, default: {blue: 0, green: 0, cyan: 0, red: 0, purple: 0, yellow: 0, white: 0}}, 
      health: {start: "0F", size: 2, type: :integer, default: 100}, 
      starting_board_index: {start: "11", size: 2, type: :integer, default: 0}, 
      torches: {start: "13", size: 2, type: :integer, default: 0}, 
      torch_cycles: {start: "15", size: 2, type: :integer, default: 0}, 
      energizer_cycles: {start: "17", size: 2, type: :integer, default: 0}, 
      padding: {start: "19", size: 2, type: :raw}, 
      score: {start: "1B", size: 2, type: :integer, default: 0}, 
      title_length: {start: "1D", size: 1, type: :integer, priority: 100}, 
      title: {start: "1E", size: 20, type: :string, display_size: :title_length, default: nil}, 
      flags: {start: "32", size: 210, item: {length: {size: 1, type: :integer}, name: {size: 20, type: :string}}, default: {}}, 
      time_left: {start: "104", size: 2, type: :integer, default: 0}, 
      saved_game: {start: "108", size: 1, type: :integer, default: 0},

      # excludes from parsing
      excludes: {properties: [:keys, :flags]}
    }
    
    def initialize()
      super(INFO)
    end

    def parse(str)
      super(INFO, str)

      start = "08".hex_to_integer
      stop = start+7
      parse_keys(str[start..stop])

      debugger

      start = "32".hex_to_integer
      stop = start+210
      parse_flags(str[start..stop])
    end

    # priority makes sure keys are processed in the expected order
    KEY_INFO = {
      blue: {start: "00", size: 1, type: :integer, priority: 100, default: 0}, 
      green: {start: "01", size: 1, type: :integer, priority: 99, default: 0}, 
      cyan: {start: "02", size: 1, type: :integer, priority: 98, default: 0}, 
      red: {start: "03", size: 1, type: :integer, priority: 97, default: 0}, 
      purple: {start: "04", size: 1, type: :integer, priority: 96, default: 0}, 
      yellow: {start: "05", size: 1, type: :integer, priority: 95, default: 0}, 
      white: {start: "06", size: 1, type: :integer, priority: 94, default: 0}, 
      excludes: {properties: []}
    }

    def parse_keys(str)
      super_parse(KEY_INFO, str){|key, value|
        keys[key] = value
      }
    end

    def parse_flags(str)
      size = 21
      start = 0
      (0..9).each do |idx|
        stop = start + size

        flag = Flag.new
        flag.parse(str[start..stop])

        if(flag.name_length > 0)
          flags[flag.name.to_sym] = true
        end
        
        start = stop
      end
    end

    # FLAG_INFO = {
    #   flag: length: {size: 1, type: :integer}, name: {size: 20, type: :string}, 
    #   excludes: {properties: []}
    # }

    # def parse_flags(str)
    #   flag_info = {}
    #   start = 0
    #   size = 21
    #   (0..9).each do |idx|
    #     flag_info["flag#{idx.to_s.rjust(2, "0")}".to_sym] = {length: {start: start, size: 1, type: :integer}, name: {start: start+1, size: 20, display_size: :title_length, type: :string}}
    #     start += size
    #   end
    #   flag_info[:excludes] = {properties: []}

    #   super_parse(flag_info, str){|key, name|
    #     flags[name] = true if !name.nil? and (name.length > 0)
    #   }
    # end
  end

  class Board
    attr_accessor :header, :tiles, :info, :objects

    def object_at_pos(x, y)
      tile = tiles.find{|t| t.x == x and t.y == y}
      board_object = objects.find{|o| o.x == x and o.y == y}
      return {tile: tile, object: board_object}
    end
  end

  class Game < Common
    attr_accessor :header, :boards
    attr_reader :logger

    def initialize()
      @header = nil
      @boards = []
      @logger = Logger.new File.new('./zzt-game.log', 'w')
      @logger.level = Logger::DEBUG
    end

    def parse(str)

      @header = Header.new()
      @header.parse(str)
      logger.debug @header
      logger.debug @header.boards_count
      
      offset = "200".hex_to_integer
      next_offset = offset
      tiles_cnt_max = (60*25)
      board_tiles_size = BoardTile.new.size

      @boards = (0...(@header.boards_count)).map do |idx|

        board = Board.new

        # board header
        board.header = BoardHeader.new
        start = offset
        stop = start + (board.header.size-1)
        board.header.parse(str[offset..stop])
        #next_offset += board_header.size #byte count for a single board header
        next_offset = stop+1
        logger.debug ""
        logger.debug idx.to_s
        logger.debug ">>> offset: #{offset}"
        logger.debug ">>> board_header.size: #{board.header.size}"
        logger.debug ">>> next_offset: #{next_offset}"

        # board tiles
        tiles_cnt = 0
        board.tiles = []
        while(tiles_cnt < tiles_cnt_max)
          start = stop
          stop += board_tiles_size
          board.tiles << BoardTile.new
          board.tiles.last.parse(str[start..stop])
          board.tiles.last.x = (tiles_cnt % 60) + 1
          board.tiles.last.y = (tiles_cnt / 60).floor + 1

          tiles_cnt += board.tiles.last.length
        end
        #next_offset += (board_tiles_size * board_tiles.length)
        next_offset = stop+1
        logger.debug ">>> board_tiles_length: #{board_tiles_size * board.tiles.length}"
        logger.debug ">>> next_offset: #{next_offset}"

        # board information
        board.info = BoardInfo.new
        start = stop
        stop = start + (board.info.size-1)
        board.info.parse(str[start..stop])
        next_offset = stop+1
        logger.debug ">>> board_info.size: " + board.info.size.to_s
        logger.debug ">>> next_offset: #{next_offset}"

        # board objects
        board_objects = []

        # add player for index 0
        board.objects = []
        (0..board.info.objects_count).each do |idx|
          board.objects << Zzt::BoardObject.new
          start = stop+1
          stop = start + (board.objects.last.size-1)
          board.objects.last.parse(str[start..str.length])
          stop += board.objects.last.data_length
          logger.debug ">#{idx}>> board_obj.size: " + board.objects.last.size.to_s

          next_offset = stop+1
          logger.debug ">>> next_offset: #{next_offset}"
        end

        offset = next_offset

        board
      end

      next_offset
    end
  end

  class BoardHeader < Common
    attr_reader :logger

    INFO = {
      board_size: {start: "00", size: 2, type: :integer}, 
      title_length: {start: "02", size: 1, type: :integer, priority: 100},
      title: {start: "03", size: 33, type: :string, display_size: :title_length, default: nil},
      padding: {start: "24", size: 18, type: :raw}, 
      excludes: {properties: []}
    }

    def initialize()
      super(INFO)
      @logger = Logger.new File.open('./zzt-game.log', 'a')
    end

    def size
      super(INFO)
    end

    def parse(str)
      super(INFO, str)
      logger.debug ">>> board_size: #{board_size}"
    end
  end

  class BoardTile < Common
    attr_accessor :x, :y
    INFO = {
      length: {start: "00", size: 1, type: :integer}, 
      code: {start: "01", size: 1, type: :raw},
      colour: {start: "02", size: 1, type: :raw}, 
      excludes: {properties: []}
      #excludes: {properties: [:message_length, :message]}
    }

    def initialize()
      super(INFO)
      @x = -1
      @y = -1
    end

    def size
      super(INFO)
    end
    
    def parse(str)
      super(INFO, str)
    end

    def contians_object?
      !(["00", "01"].include?(code.upcase))
    end

    def contians_configurable_object?
      CODE_TABLE_BY_CODE_FOR_CONFIGURABLE_OBJECTS.keys.include?(code.upcase)
    end

    def object_code
      Zzt::BoardObject::CODE_TABLE_BY_CODE[code.upcase]
    end

    def to_s
      @object_desc = object_code[:desc] unless object_code.nil?
      super()
    end
  end

  class BoardInfo < Common
    INFO = {
      maximum_shots_fired: {start: "00", size: 1, type: :integer}, 
      darkness: {start: "01", size: 1, type: :integer, default: 0}, 
      north: {start: "02", size: 1, type: :integer, default: 0}, 
      south: {start: "03", size: 1, type: :integer, default: 0}, 
      west: {start: "04", size: 1, type: :integer, default: 0}, 
      east: {start: "05", size: 1, type: :integer, default: 0}, 
      reenter_when_zapped: {start: "06", size: 1, type: :integer, default: 0}, 
      message_length: {start: "07", size: 1, type: :integer}, 
      message: {start: "08", size: 58, type: :string}, 
      padding_01: {start: "42", size: 2, type: :raw}, 
      time_limit: {start: "44", size: 2, type: :integer}, 
      padding_02: {start: "46", size: 16, type: :raw}, 
      objects_count: {start: "56", size: 2, type: :integer, default: 0}, 
      excludes: {properties: []}
    }

    def initialize()
      super(INFO)
    end

    def size
      super(INFO)
    end
    
    def parse(str)
      super(INFO, str)
    end

    def to_s
      super(self.instance_variables.select{|v| ![:@message_length, :@message, :@padding_01, :@padding_02].include?(v) })
    end
  end

end

require "./lib/zzt/board_object.rb"

=begin
#load './zzt-parser.rb'
game = Zzt::Game.new()
tour_content = IO.read("./TOUR.ZZT")
game.parse(tour_content)
=end
#puts ">>> " + game.parse(tour_content).to_s


#puts "0A".to_hex_string
# puts "0A".convert_base(16, 10)
# 
# puts Zzt::Hex.get(tour_content, 2, 1)
# puts Zzt::Hex.get_integer(tour_content, 8, 1)
# puts Zzt::Hex.get_integer(tour_content, "0A", 1)
#

# puts tour_content[15..16].to_hex_string
# puts tour_content[15..16]#.hex_to_integer
# puts Zzt::Hex.get_integer(tour_content, 15)

#puts tour_content[15..17]#.convert_base(16, 10).to_i
#

# puts "64".to_i(16).to_s(10)

# puts ["544F5552"].pack('H*')

# File.open("chk.txt", "w"){|f|
# f.write header.magic_number.hex_to_bin
# f.write (header.health.to_s(16).ljust(4, "0")).hex_to_bin
# }


    # def xparse(str)
    #   @magic_number = str[0..1].to_hex_string
    #   @boards = str[2..3].hex_to_integer
    #   @ammo = str[4..5].hex_to_integer
    #   @gems = str[6..7].hex_to_integer

    #   @keys[:blue] = str[8].hex_to_integer
    #   @keys[:green] = str[9].hex_to_integer
    #   @keys[:cyan] = Hex.get_integer(str, "0A", 1)
    #   @keys[:red] = Hex.get_integer(str, "0B", 1)
    #   @keys[:purple] = Hex.get_integer(str, "0C", 1)
    #   @keys[:yellow] = Hex.get_integer(str, "0D", 1)
    #   @keys[:white] = Hex.get_integer(str, "0E", 1)

    #   puts "health: #{Hex.get(str, "0F")}"
    #   @health = Hex.get_integer(str, "0F")
    #   @starting_board_index = Hex.get_integer(str, "11", "12")
    #   @torches = Hex.get_integer(str, "13", "14")
    #   @torch_cycles = Hex.get_integer(str, "15")
    #   @energizer_cycles = Hex.get_integer(str, "17")

    #   @padding = Hex.get_integer(str, "19")

    #   @score = Hex.get_integer(str, "1B")
    #   title_length = Hex.get_integer(str, "1D")
    #   @title = Hex.get_string(str, "1E", (title_length-1))

    #   flag_data = Hex.get(str, "32", "46")
    #   puts "flag_data: #{flag_data.split(/ /).length}"

    #   offset = "32".hex_to_integer
    #   flag_length = Hex.get_integer(str, offset)
    #   @flags[0] = Hex.get_string(str, offset+1, (flag_length-1))

    #   [1...10].each do |idx|
    #     offset += 20
    #     flag_length = Hex.get_integer(str, offset)
    #     @flags[idx] = Hex.get_string(str, offset+1, (flag_length-1))
    #   end
    #   
    #   @time_left = Hex.get_integer(str, "104")
    #   @saved_game = Hex.get_integer(str, "108")
    # end

#puts 1000.to_s(16)


