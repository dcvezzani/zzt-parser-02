require 'byebug'
require 'json'

class ZztParser02
  
  attr_accessor :src_file, :game_header, :boards

  FDEBUG = false

  def initialize(src_file = nil)
    @src_file = src_file
    @game_header = {}
    @boards = {}

    if @src_file
      file_content = IO.read(@src_file)
      @game_header, self.boards = Deserializer.new(file_content).go(true)
    end
  end

  def self.import(src_file = './matt.json')
    parser = ZztParser02.new

    file_content = IO.read(src_file)
    game = JSON::load(file_content)["game"]
    parser.game_header, parser.boards = Importer.new(game).go
    parser
  end

  def serialize(dst_file = './game.zzt')
    Serializer.new(dst_file, self.game_header, self.boards).go
  end

  def deserialize(dst_file = './game.txt')
    File.open(dst_file, "w"){|f| f.write ({game: {header: self.game_header, boards: self.boards}}.to_json) }
  end

  class Importer
    
    attr_accessor :json, :_game_header, :_boards, :_board_header, :_board_info, :_tiles, :_objects

    def initialize(json)
      @json = json

      @_game_header = {}
      @_boards = {}
      
      @_board_header = {}
      @_board_info = {}
      @_tiles = []
      @_objects = {0 => nil}
    end
      
    def go
      game = self.json
      
      self._game_header = game['header'].inject({}){|a,b| a.merge!({b[0].to_sym => b[1]})}
      self._game_header[:boards_cnt_z] = (game['boards'].length - 1)

      game['boards'].each do |idx, board|

        game_board_objects = board["objects"]
        self._board_header = board['header'].inject({}){|a,b| a.merge!({b[0].to_sym => b[1]})}
        self._tiles = board['tiles']
        self._board_info = board['info'].inject({}){|a,b| a.merge!({b[0].to_sym => b[1]})}
        self._board_info[:obj_cnt] = (game_board_objects.length - 1)
        
        self._objects = {}
        board['objects'].each do |idx, object|
          self._objects[idx] = game_board_objects[idx]['info'].inject({}){|a,b| a.merge!({b[0].to_sym => b[1]})}
        end

        self._boards[idx] = {header: self._board_header, info: self._board_info, tiles: self._tiles, objects: self._objects}

      end

      [self._game_header, self._boards]
    end
  end

  # convert from json back to zzt file format
  class Serializer

    #attr_accessor :content, :start, :board_stop, :_game_header, :_boards, :_board_header, :_board_info, :_tiles, :_objects
    attr_accessor :dst_file, :_game_header, :_boards

    def initialize(dst_file, game_header, boards)
      @_game_header = game_header
      @_boards = boards
      @dst_file = dst_file
    end

    def go
      File.open(dst_file, "wb"){|f| f.write ""}
      File.open(dst_file, "ab"){|f|
        game_header{|content| f.write(content)}
        boards{|content| f.write(content)}
      }
    end

    def game_header(&blk)
      self._game_header[:boards_cnt_z] = (self._boards.size - 1)
      
      (1...9).each do |idx|
        self._game_header["flg#{idx}_cnt".to_sym] = (self._game_header["flg#{idx}".to_sym]).length
      end
      
      # TODO: fill spaces with '00' instead of '20'
      blk.call [:magic_num, :boards_cnt_z, :ammo, :gems, :bk, :gk, :ck, :rk, :pk, :yk, :wk, :health, :board_str, :torch_cnt, :tcycle_cnt, :ecycle_cnt, :pad_01, :score, :title_cnt, :title, :flg1_cnt, :flg1, :flg2_cnt, :flg2, :flg3_cnt, :flg3, :flg4_cnt, :flg4, :flg5_cnt, :flg5, :flg6_cnt, :flg6, :flg7_cnt, :flg7, :flg8_cnt, :flg8, :flg9_cnt, :flg9, :pad_02, :timeleft, :pad_03, :saved_game, :pad_04 ].map{|key| self._game_header[key]}.pack(GAME_HEADER_PARSE)
    end

    def boards(&blk)
      self._boards.each do |idx, board|

        board[:header][:title_cnt] = (board[:header][:title]).length

        board_content = ''
        board_content += [:title_cnt, :title, :pad_01].map{|key| board[:header][key]}.pack(BOARD_HEADER_LESS_PARSE)

          # repeat_cnt, code, raw_data = tour_content[start..board_stop].unpack("CH2A")
          #   colour = raw_data.unpack('H*')[0]
            # tiles << [repeat_cnt, code, text]
        
        tile_pos = 0
        (0...board[:tiles].length).each do |tile_idx|
          tile_pos += (board[:tiles][tile_idx])[0]
          row = (tile_pos/60).round + 1
          col = (tile_pos%60)
          
          # debugger if tile_pos == 1500
          puts ">>> #{tile_pos}: #{col},#{row} #{(board[:tiles][tile_idx])}" if FDEBUG
          code = (board[:tiles][tile_idx])[1]
          decimal_code = code.to_i(16)
          tile = (board[:tiles][tile_idx])
          
          if (decimal_code >= "2f".to_i(16))
            character = [[(board[:tiles][tile_idx][2])].pack("A")].first
            tile = board[:tiles][tile_idx][0..1] + [character.ord.to_s(16)]
          end

          board_content += (tile.pack(TILE_PARSE))
        end

        board[:info][:message_len] = (board[:info][:message]).length
        board[:info][:obj_cnt] = (board[:objects].size - 1)

        board_content += [:max_shots, :darkness, :bn, :bs, :bw, :be, :reenter, :message_len, :message, :pad_01, :time_limit, :pad_02, :obj_cnt].map{|key| board[:info][key]}.pack(BOARD_INFO_PARSE)

        board[:objects].each do |idx, object|
          board_content += [:x, :y, :x_step, :y_step, :cycle, :p1, :p2, :p3, :follower, :leader, :under_id, :under_color, :pointer, :cur_ins, :len, :pad_01].map{|key| object[key]}.pack(OBJECT_PARSE)

          if object[:data]
            board_content += object[:data].pack(OBJECT_DATA_PARSE)
          end
        end

        blk.call ([board_content.length].pack("S") + board_content)
      end
    end
  end

  # convert from zzt file format to json
  class Deserializer

    attr_accessor :content, :start, :board_stop, :_game_header, :_boards, :_board_header, :_board_info, :_tiles, :_objects, :current_board_idx

    def initialize(content)
      @content = content
      @start = nil
      @board_stop = nil

      @_game_header = {}
      @_boards = {}
      @current_board_idx = nil

      # TODO: shouldn't be instance variables
      @_board_header = {}
      @_board_info = {}
      @_tiles = []
      @_objects = {0 => nil}
    end

    def go(reparse = true)
      self.start = ("00".to_i(16))
      self.board_stop = 0

      self.boards(true)
      
      [ self.game_header, self.boards ]
    end

    def boards(reparse = false)
      return self._boards if self._boards.size > 0 and !reparse

      (0..self.game_header(reparse)[:boards_cnt_z]).each do |board_idx|
        self.current_board_idx = board_idx
        self._boards[board_idx] = {
          header: self.board_header(true), 
          tiles: self.tiles(true), 
          info: self.board_info(true), 
          objects: self.objects(true)
        }
      end

      self._boards
    end

    def objects(reparse = false)
      return self._objects if self._objects.size > 0 and !reparse

      (0..self._board_info[:obj_cnt]).each do |obj_idx|
        keys = [:x, :y, :x_step, :y_step, :cycle, :p1, :p2, :p3, :follower, :leader, :under_id, :under_color, :pointer, :cur_ins, :len, :pad_01]
        values = self.content[(self.start)..self.board_stop].unpack(ZztParser02::OBJECT_PARSE)
        object_info = keys.zip(values).inject({}){ |h,(k,v)| h[k] = v; h }

        self.start += 33
        
        if object_info[:len] > 0
          object_info[:data] = self.content[(self.start)...(self.start + object_info[:len])].unpack(ZztParser02::OBJECT_DATA_PARSE)
          self.start += object_info[:len]
        end

        File.open("./chk.txt", "a"){|f| f.write "<< #{object_info[:x]},#{object_info[:y]}: #{object_info}\n" } if ZztParser02::FDEBUG
        
        begin
          fnd_idx = self._objects.select{|idx, obj| ((obj[:x] == object_info[:x]) && (obj[:y] == object_info[:y]))}.first.first
        rescue
          err = {board_idx: self.current_board_idx, board_header: board_header, board_info: board_info, obj_cnt: [board_info[:obj_cnt], self._objects.size], obj_idx: obj_idx, object_info: object_info, all_objects: self._objects}
          throw "Error: #{err}"
        end

        
        self._objects[fnd_idx][:type] = ZztParser02::CODES[self._objects[fnd_idx][:tile][1]]
        self._objects[fnd_idx][:details] = {}
        self._objects[fnd_idx][:color] = ZztParser02::color_desc(self._objects[fnd_idx][:tile][2])
        self._objects[fnd_idx][:info] = object_info

        self._objects[fnd_idx][:details] = {type: ZztParser02::CODES[self._objects[fnd_idx][:tile][1]]}.merge(object_details(self._objects[fnd_idx]))
      end

      self._objects
    end

    def object_details(obj)
      code = obj[:tile][1]
      keys = [:x, :y]
      trans = nil

      case code
      when "00" #=> "Empty", 
      when "01" #=> "Board Edge", 
      when "02" #=> "Messenger", 
      when "03" #=> "Monitor", 

      when "04" #=> "Player", 
        keys = [:cycle]

      when "05" #=> "Ammo", 
      when "06" #=> "Torch", 
      when "07" #=> "Gem", 
      when "08" #=> "Key", 
      when "09" #=> "Door", 
        
      when "0a" #=> "Scroll", 
        keys = [:cycle, :cur_ins, :len, :data]
      when "0b" #=> "Passage", 
        keys = [:p3]
      when "0c" #=> "Duplicator", 
        keys = [:x_step, :y_step, :p2]

      when "0d" #=> "Bomb", 
      when "0e" #=> "Energizer", 

      when "0f" #=> "Star", 
        keys = [:x_step, :y_step, :cycle, :p1]

      when "10" #=> "Clockwise conveyer", 
      when "11" #=> "Counterclockwise conveyor", 
        
      when "12" #=> "Bullet", 
        keys = [:x_step, :y_step, :cycle, :p1]

      when "13" #=> "Water", 
      when "14" #=> "Forest", 
      when "15" #=> "Solid", 
      when "16" #=> "Normal", 
      when "17" #=> "Breakable", 
      when "18" #=> "Boulder", 
      when "19" #=> "Slider: North-South", 
      when "1a" #=> "Slider: East-West", 
      when "1b" #=> "Fake", 
      when "1c" #=> "Invisible wall", 
        
      when "1d" #=> "Blink Wall", 
        keys = [:x_step, :y_step, :cycle, :p1, :p2]
      when "1e" #=> "Transporter", 
        keys = [:x_step, :y_step, :cycle]

      when "1f" #=> "Line", 
      when "20" #=> "Ricochet", 
      when "21" #=> "Horizontal blink wall ray", 
      when "2b" #=> "Vertical blink wall ray", 
        
      when "22" #=> "Bear", 
        keys = [:cycle, :p1]
        trans = {p1: :sensitivity}
      when "23" #=> "Ruffian", 
        keys = [:cycle, :p1, :p2]
      when "24" #=> "Object", 
        keys = [:cycle, :p1, :p2, :cur_ins, :len, :data]
      when "25" #=> "Slime", 
        keys = [:cycle, :p2]
      when "26" #=> "Shark", 
        keys = [:cycle, :p1]
      when "27" #=> "Spinning gun", 
        keys = [:cycle, :p1, :p2]
      when "28" #=> "Pusher", 
        keys = [:x_step, :y_step, :cycle]
      when "29" #=> "Lion", 
        keys = [:cycle, :p1]
      when "2a" #=> "Tiger", 
        keys = [:cycle, :p1, :p2, :p3]
        trans = {p1: :intelligence, p2: :firing_rate, p3: :firing_type, firing_type: {0 => :bullet, 1 => :star}}
      when "2c" #=> "Centipede head", 
        keys = [:cycle, :p1, :p2]
      when "2d", "2e", "2f" #=> "Centipede segment", 
        keys = [:cycle]
      end

      trans_attrs = {}
      filtered_obj = (keys.concat([:under_id, :under_color])).inject({}){|filtered_obj, attr| 
        if trans && trans.has_key?(attr)
          trans_attr = trans.delete(attr)
          trans_value = obj[:info][attr]

          if trans.has_key?(trans_attr)
            trans_value = {value: trans_value, description: trans[trans_attr][trans_value]}
          end

          trans_attrs.merge!({attr => {name: trans_attr, details: trans_value}})
        end

        filtered_obj.merge!({ attr => obj[:info][attr]})
      }

      filtered_obj[:under_id] = {code: filtered_obj[:under_id], description: ZztParser02::CODES[filtered_obj[:under_id]]}
      filtered_obj[:under_color] = ZztParser02::color_desc(filtered_obj[:under_color])

      #debugger if trans_attrs.size > 0

      filtered_obj.merge(trans_attrs)
    end

    def board_info(reparse = false)
      return self._board_info if self._board_info.size > 0 and !reparse

      keys = [:max_shots, :darkness, :bn, :bs, :bw, :be, :reenter, :message_len, :message, :pad_01, :time_limit, :pad_02, :obj_cnt]
      values = self.content[self.start..self.board_stop].unpack(ZztParser02::BOARD_INFO_PARSE)
      self._board_info = keys.zip(values).inject({}){ |h,(k,v)| h[k] = v; h }

      message_len = (self._board_info[:message_len])
      self._board_info[:message] = (self._board_info[:message]).slice(0, message_len)

      self.start += ZztParser02::hex_length("00-57") #88

      self._board_info
    end

    def tiles(reparse = false)
      return self._tiles if self._tiles.length > 0 and !reparse

      tile_cnt = 0

      self._tiles = []
      self._objects = {0 => nil}

      while (tile_cnt < ZztParser02::MAX_TILE_CNT)
        repeat_cnt, code, raw_data = self.content[self.start..self.board_stop].unpack(ZztParser02::TILE_PARSE)

        decimal_code = code.to_i(16)
        colour = text = nil
        
        if (decimal_code >= "2f".to_i(16))
          tile_pos = (tile_cnt + 1)
          row = (tile_pos/60).round + 1
          col = (tile_pos%60)
          
          # puts ">>> #{tile_pos}: #{col},#{row} #{[repeat_cnt, code, raw_data]}"
          # debugger
          text = raw_data.to_i(16).chr
          
          self._tiles << [repeat_cnt, code, text]
          tile_cnt += repeat_cnt

          File.open("./chk.txt", "a"){|f| f.write "<< #{tile_cnt}, #{self._tiles.last}, #{col},#{row}: #{ZztParser02::CODES[code]}\n" } if ZztParser02::FDEBUG

        else
          colour = raw_data

          if ZztParser02::VALID_OBJECTS.include?(code)
            (1..repeat_cnt).each do
              tile_pos = (tile_cnt + 1)
              if (tile_pos != 0 && (tile_pos%60) == 0)
                row = (tile_pos/60)
                col = 60
              else
                row = (tile_pos/60).round + 1
                col = (tile_pos%60)
              end
              
              self._tiles << [1, code, colour]

              if code == "04"
                self._objects[0] = {x: col, y: row, tile: self._tiles.last}
              else
                self._objects[self._objects.size] = {x: col, y: row, tile: self._tiles.last}
              end

              tile_cnt += 1

              File.open("./chk.txt", "a"){|f| f.write "<< #{tile_cnt}, #{self._tiles.last}, #{col},#{row}: #{ZztParser02::CODES[code]}\n" } if ZztParser02::FDEBUG
            end

          else
            tile_pos = (tile_cnt + 1)
            row = (tile_pos/60).round + 1
            col = (tile_pos%60)

            self._tiles << [repeat_cnt, code, colour]
            tile_cnt += repeat_cnt

            File.open("./chk.txt", "a"){|f| f.write "<< #{tile_cnt}, #{self._tiles.last}, #{col},#{row}: #{ZztParser02::CODES[code]}\n" } if ZztParser02::FDEBUG
          end
        end

        self.start += 3
      end

      self._tiles
    end

    def board_header(reparse = false)
      return self._board_header if self._board_header.size > 0 and !reparse

      keys = [:board_size, :title_cnt, :title_x, :pad_01]
      values = self.content[(start)...(start + ZztParser02::hex_length("00-34"))].unpack(ZztParser02::BOARD_HEADER_PARSE)
      self._board_header = keys.zip(values).inject({}){ |h,(k,v)| h[k] = v; h }
      self._board_header[:title] = self._board_header[:title_x].slice(0, self._board_header[:title_cnt])
      self._board_header.delete(:title_x)
      self.board_stop = (self.start + self._board_header[:board_size] + 2)

      self.start = self.start + ZztParser02::hex_length("00-34")
      
      self._board_header
    end

    def game_header(reparse = false)
      return self._game_header if self._game_header.size > 0 and !reparse

      keys = [:magic_num, :boards_cnt_z, :ammo, :gems, :bk, :gk, :ck, :rk, :pk, :yk, :wk, :health, :board_str, :torch_cnt, :tcycle_cnt, :ecycle_cnt, :pad_01, :score, :title_cnt, :title_x, :flg1_cnt, :flg1, :flg2_cnt, :flg2, :flg3_cnt, :flg3, :flg4_cnt, :flg4, :flg5_cnt, :flg5, :flg6_cnt, :flg6, :flg7_cnt, :flg7, :flg8_cnt, :flg8, :flg9_cnt, :flg9, :pad_02, :timeleft, :pad_03, :saved_game, :pad_04 ]
      values = self.content[("00".to_i(16))..("200".to_i(16))].unpack(ZztParser02::GAME_HEADER_PARSE)
      self._game_header = keys.zip(values).inject({}){ |h,(k,v)| h[k] = v; h }
      self._game_header[:title] = self._game_header[:title_x].slice(0, self._game_header[:title_cnt])
      self._game_header.delete(:title_x)

      (1...9).each do |idx|
        flg_cnt = (self._game_header["flg#{idx}_cnt".to_sym])
        self._game_header["flg#{idx}".to_sym] = self._game_header["flg#{idx}".to_sym].slice(0, flg_cnt)
      end

      self.start = ("200".to_i(16))

      self._game_header
    end
  end

  private

  def self.hex_add_dec(hex, dec, zero=false)
    offset = (zero) ? (dec - 1) : dec
    (hex.to_i(16) + offset).to_s(16)
  end

  def self.hex_length(exp)
    parts = exp.split(/-/)
    (parts[1].to_i(16) - parts[0].to_i(16)) + 1
  end

  def self.color_desc(color)
    keys = [:background, :foreground]
    background, foreground = color.split("")
    # res = keys.zip(values).inject({}){ |h,(k,v)| h[k] = v; h }
    {code: color, foreground: {code: foreground, description: FOREGROUND_COLORS[foreground]}, background: {code: background, description: BACKGROUND_COLORS[background]}}
  end

  GAME_HEADER_PARSE = "H4S3C7S7CA20CA20CA20CA20CA20CA20CA20CA20CA20CA20H40SH4CH496"
  BOARD_HEADER_PARSE = "SCA33H34"
  BOARD_HEADER_LESS_PARSE = "CA33H34"
  BOARD_SIZE_PARSE = "S"
  BOARD_INFO_PARSE = "C8H116H4SH32S"
  TILE_PARSE = "CH2H2"
  # OBJECT_PARSE = "CCSSSCCCH8CCH8SSH16"
  OBJECT_PARSE = "CCSSSCCCH4H4H2H2H8SSH16"
  OBJECT_DATA_PARSE = "A*"

  VALID_OBJECTS = %w{04 0a 0b 0c 0d 0f 10 11 12 1d 1e 22 23 24 25 26 27 28 29 2a 21 2b 2c 2d}

  public

  MAX_TILE_CNT = 60*25 #1500
  
  FOREGROUND_COLORS = {
   "0" => "Black", 
   "1" => "Dark blue", 
   "2" => "Dark green", 
   "3" => "Dark cyan", 
   "4" => "Dark red", 
   "5" => "Dark purple", 
   "6" => "Dark yellow (brown)", 
   "7" => "Light grey", 
   "8" => "Dark grey", 
   "9" => "Light blue", 
   "a" => "Light green", 
   "b" => "Light cyan", 
   "c" => "Light red", 
   "d" => "Light purple", 
   "e" => "Light yellow", 
   "f" => "White"
  }

  BACKGROUND_COLORS = {
   "0" => "Black", 
   "1" => "Dark blue", 
   "2" => "Dark green", 
   "3" => "Dark cyan", 
   "4" => "Dark red", 
   "5" => "Dark purple", 
   "6" => "Dark yellow (brown)", 
   "7" => "Light grey", 
   "8" => "Black (blinking)", 
   "9" => "Dark blue (blinking)", 
   "a" => "Dark green (blinking)", 
   "b" => "Dark cyan (blinking)", 
   "c" => "Dark red (blinking)", 
   "d" => "Dark purple (blinking)", 
   "e" => "Dark yellow (brown) (blinking)",
   "f" => "Light grey (blinking)"
  }

  CODES = {
   "00" => "Empty Space", 
   "01" => "Special: acts like edge of board", 
   "04" => "Player", 
   "05" => "Ammo", 
   "06" => "Torch", 
   "07" => "Gem", 
   "08" => "Key", 
   "09" => "Door", 
   "0a" => "Scroll", 
   "0b" => "Passage", 
   "0c" => "Duplicator", 
   "0d" => "Bomb", 
   "0e" => "Energizer", 
   "0f" => "Star", 
   "10" => "Clockwise conveyer", 
   "11" => "Counterclockwise conveyor", 
   "12" => "Bullet", 
   "13" => "Water", 
   "14" => "Forest", 
   "15" => "Solid", 
   "16" => "Normal", 
   "17" => "Breakable", 
   "18" => "Boulder", 
   "19" => "Slider: North-South", 
   "1a" => "Slider: East-West", 
   "1b" => "Fake", 
   "1c" => "Invisible wall", 
   "1d" => "Blink Wall", 
   "1e" => "Transporter", 
   "1f" => "Line", 
   "20" => "Ricochet", 
   "21" => "Horizontal blink wall ray", 
   "22" => "Bear", 
   "23" => "Ruffian", 
   "24" => "Object", 
   "25" => "Slime", 
   "26" => "Shark", 
   "27" => "Spinning gun", 
   "28" => "Pusher", 
   "29" => "Lion", 
   "2a" => "Tiger", 
   "2b" => "Vertical blink wall ray", 
   "2c" => "Centipede head", 
   "2d" => "Centipede segment", 
   "2f" => "Blue text", 
   "30" => "Green text", 
   "31" => "Cyan text", 
   "32" => "Red text", 
   "33" => "Purple text", 
   "34" => "Yellow text", 
   "35" => "White text", 
   "36" => "White blinking text", 
   "37" => "Blue blinking text", 
   "38" => "Green blinking text", 
   "39" => "Cyan blinking text", 
   "3a" => "Red blinking text", 
   "3b" => "Purple blinking text", 
   "3c" => "Yellow blinking text", 
   "3d" => "Grey blinking text"
  }
  # ZztParser02::hex_length("13-26")
  # ZztParser02::hex_length("108-200")
  
end

# cd "/Users/davidvezzani/DOS Games/Zzt.boxer/C.harddisk/zzt"
# ln -s /Users/davidvezzani/ruby_apps/zzt-parser-02/zzt/tour.zzt
zzt_parser_path = '/Users/davidvezzani/ruby_apps/zzt-parser-02'
# zzt_parser_path = '/Users/davidvezzani/ruby-app/zzt-parser.new'

game = ZztParser02.new("#{zzt_parser_path}/zzt/caves.zzt")
game.deserialize("#{zzt_parser_path}/matt.json")

game = ZztParser02.import("#{zzt_parser_path}/matt.json")
# cat /Users/davidvezzani/zzt_parser_path/matt.json | jq '.'
game.serialize("#{zzt_parser_path}/MATT.ZZT")
