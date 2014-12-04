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

tour_content = IO.read("./UNTITLED.ZZT")
puts tour_content[0...2].to_hex_string

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

    def parse(info, str, offset=0)
      # bubble prioritized properties to the top
      # perhaps one property depends on one already being extracted
      keys = info.keys.sort{|x, y| 
        info[y][:priority].to_i <=> info[x][:priority].to_i
      }

      offset = (offset.is_a?(String)) ? offset.hex_to_integer : offset

      keys.select{|k| !(info[:excludes][:properties] + [:excludes]).include?(k)}.each do |key|
        start = info[key][:start].hex_to_integer + offset
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

        self.instance_variable_set("@#{key.to_s}", value)
      end
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
      excludes: {properties: [:keys, :flags]}
    }
    
    def initialize()
      super(INFO)
    end
  end

  class Boards < Common
    attr_accessor :header
    def initialize(header)
      @header = header
    end

    def parse(str)
      offset = "200".hex_to_integer
      next_offset = offset
      tiles_cnt_max = (60*25)
      board_tiles_size = BoardTile.new.size

      [0..(header.boards_count)].each do |idx|

        # board header
        board_header = BoardHeader.new
        start = offset
        stop = start + (board_header.size-1)
        board_header.parse(str[offset..stop])
        #next_offset += board_header.size #byte count for a single board header
        next_offset = stop+1
        puts ">>> offset: #{offset}"
        puts ">>> board_header.size: #{board_header.size}"
        puts ">>> next_offset: #{next_offset}"

        # board tiles
        tiles_cnt = 0
        board_tiles = []
        while(tiles_cnt < tiles_cnt_max)
          start = stop
          stop += board_tiles_size
          board_tiles << BoardTile.new
          board_tiles.last.parse(str[start..stop])

          tiles_cnt += board_tiles.last.length
        end
        #next_offset += (board_tiles_size * board_tiles.length)
        next_offset = stop+1
        puts ">>> board_tiles_length: #{board_tiles_size * board_tiles.length}"
        puts ">>> next_offset: #{next_offset}"

        # board information
        board_info = BoardInfo.new
        start = stop
        stop = start + (board_info.size-1)
        board_info.parse(str[start..stop])
        next_offset = stop+1
        puts ">>> board_info.size: " + board_info.size.to_s
        puts ">>> next_offset: #{next_offset}"

        # board objects
        board_objects = []

        # add player for index 0
        board_objects = []
        (0..board_info.objects_count).each do |idx|
          board_obj = BoardObject.new
          start = stop+1
          stop = start + (board_obj.size-1)
          board_obj.parse(str[start..str.length])
          stop += board_obj.data_length
          puts ">#{idx}>> board_obj.size: " + board_obj.size.to_s

          next_offset = stop+1
          puts ">>> next_offset: #{next_offset}"

          board_objects << board_obj
        end
      end

      next_offset
    end
  end

  class BoardHeader < Common
    INFO = {
      board_size: {start: "00", size: 2, type: :integer}, 
      title_length: {start: "02", size: 1, type: :integer, priority: 100},
      title: {start: "03", size: 33, type: :string, display_size: :title_length, default: nil},
      padding: {start: "24", size: 18, type: :raw}, 
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
      puts ">>> board_size: #{board_size}"
    end
  end

  class BoardTile < Common
    INFO = {
      length: {start: "00", size: 1, type: :integer}, 
      code: {start: "01", size: 1, type: :raw},
      colour: {start: "02", size: 1, type: :raw}, 
      excludes: {properties: []}
      #excludes: {properties: [:message_length, :message]}
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

  class BoardObject < Common
    INFO = {
      x: {start: "00", size: 1, type: :integer}, 
      y: {start: "01", size: 1, type: :integer}, 
      x_step: {start: "02", size: 2, type: :integer}, 
      y_step: {start: "04", size: 2, type: :integer}, 
      cycle: {start: "06", size: 2, type: :integer}, 
      p1: {start: "08", size: 1, type: :integer}, 
      p2: {start: "09", size: 1, type: :integer}, 
      p3: {start: "0A", size: 1, type: :integer}, 
      p4: {start: "0B", size: 4, type: :integer}, 
      ut: {start: "0F", size: 1, type: :integer}, 
      uc: {start: "10", size: 1, type: :integer}, 
      pointer: {start: "11", size: 4, type: :integer}, 
      cur_ins: {start: "15", size: 2, type: :integer}, 
      data_length: {start: "17", size: 2, type: :integer, default: 0, priority: 100}, 
      padding: {start: "19", size: 8, type: :raw}, 
      data: {start: "21", size: :data_length, type: :string}, 
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
      super(self.instance_variables.select{|v| ![:@padding].include?(v) })
    end
  end

end

header = Zzt::Header.new()
header.parse(Zzt::Header::INFO, tour_content)
puts header
puts header.boards_count

boards = Zzt::Boards.new(header)
puts ">>> " + boards.parse(tour_content).to_s


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

puts 1000.to_s(16)


