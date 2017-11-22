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

        
        self._objects[fnd_idx][:type] = ZztParser02::code_description(self._objects[fnd_idx][:tile][1])
        self._objects[fnd_idx][:details] = {}
        self._objects[fnd_idx][:color] = ZztParser02::color_desc(self._objects[fnd_idx][:tile][2])
        self._objects[fnd_idx][:info] = object_info

        self._objects[fnd_idx][:details] = {type: ZztParser02::code_details(self._objects[fnd_idx][:tile][1])}.merge(object_details(self._objects[fnd_idx]))
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
        #TODO: trans = {p3: :room, room: lambda{|idx| {id: idx, name: @_boards[idx][:header][:title]}}}
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
        trans = {p1: :character, p2: :zeros, character: lambda{|int| {character: ZztParser02::dos_ascii(int)} }}
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
            case trans[trans_attr].class.name
            when "Proc"
              trans_value = {value: trans_value}.merge(trans[trans_attr].call(trans_value))
            else
              trans_value = {value: trans_value, description: trans[trans_attr][trans_value]}
            end
          end

          trans_attrs.merge!({attr => {name: trans_attr, details: trans_value}})
        end

        filtered_obj.merge!({ attr => obj[:info][attr]})
      }

      filtered_obj[:under_id] = {code: filtered_obj[:under_id], description: ZztParser02::code_description(filtered_obj[:under_id])}
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

          File.open("./chk.txt", "a"){|f| f.write "<< #{tile_cnt}, #{self._tiles.last}, #{col},#{row}: #{ZztParser02::code_description(code)}\n" } if ZztParser02::FDEBUG

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

              File.open("./chk.txt", "a"){|f| f.write "<< #{tile_cnt}, #{self._tiles.last}, #{col},#{row}: #{ZztParser02::code_description(code)}\n" } if ZztParser02::FDEBUG
            end

          else
            tile_pos = (tile_cnt + 1)
            row = (tile_pos/60).round + 1
            col = (tile_pos%60)

            self._tiles << [repeat_cnt, code, colour]
            tile_cnt += repeat_cnt

            File.open("./chk.txt", "a"){|f| f.write "<< #{tile_cnt}, #{self._tiles.last}, #{col},#{row}: #{ZztParser02::code_description(code)}\n" } if ZztParser02::FDEBUG
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

  def self.code_description(id)
    (CODES[id][:description])
  end

  def self.code_details(id)
    if CODES[id][:character_code]
      CODES[id].merge({character: dos_ascii(CODES[id][:character_code])})
    else
      {}
    end
  end

  CODES = {
    "00"=>{:character_code=>"20", :description=>"Empty Space"},
    "01"=>{:character_code=>"20", :description=>"Board Edge"},
    "02"=>{:character_code=>"20", :description=>"Messenger"},
    "03"=>{:character_code=>"20", :description=>"Monitor"},
    "04"=>{:character_code=>"02", :description=>"Player"},
    "05"=>{:character_code=>"84", :description=>"Ammo"},
    "06"=>{:character_code=>"9D", :description=>"Torch"},
    "07"=>{:character_code=>"04", :description=>"Gem"},
    "08"=>{:character_code=>"0C", :description=>"Key"},
    "09"=>{:character_code=>"0A", :description=>"Door"},
    "0a"=>{:character_code=>"E8", :description=>"Scroll"},
    "0b"=>{:character_code=>"F0", :description=>"Passage"},
    "0c"=>{:character_code=>"FA", :description=>"Duplicator"},
    "0d"=>{:character_code=>"0B", :description=>"Bomb"},
    "0e"=>{:character_code=>"7F", :description=>"Energizer"},
    "0f"=>{:character_code=>"53", :description=>"Star"},
    "10"=>{:character_code=>"2F", :description=>"Clockwise conveyer"},
    "11"=>{:character_code=>"5C", :description=>"Counterclockwise conveyor"},
    "12"=>{:character_code=>"F8", :description=>"Bullet"},
    "13"=>{:character_code=>"B0", :description=>"Water"},
    "14"=>{:character_code=>"B0", :description=>"Forest"},
    "15"=>{:character_code=>"DB", :description=>"Solid"},
    "16"=>{:character_code=>"B2", :description=>"Normal"},
    "17"=>{:character_code=>"B1", :description=>"Breakable"},
    "18"=>{:character_code=>"FE", :description=>"Boulder"},
    "19"=>{:character_code=>"12", :description=>"Slider: North-South"},
    "1a"=>{:character_code=>"1D", :description=>"Slider: East-West"},
    "1b"=>{:character_code=>"B2", :description=>"Fake"},
    "1c"=>{:character_code=>"B0", :description=>"Invisible wall"},
    "1d"=>{:character_code=>"CE", :description=>"Blink Wall"},
    "1e"=>{:character_code=>"C5", :description=>"Transporter"},
    "1f"=>{:character_code=>"CE", :description=>"Line"},
    "20"=>{:character_code=>"2A", :description=>"Ricochet"},
    "21"=>{:character_code=>"CD", :description=>"Horizontal blink wall ray"},
    "22"=>{:character_code=>"99", :description=>"Bear"},
    "23"=>{:character_code=>"05", :description=>"Ruffian"},
    "24"=>{:character_code=>nil,  :description=>"Object"},
    "25"=>{:character_code=>"2A", :description=>"Slime"},
    "26"=>{:character_code=>"5E", :description=>"Shark"},
    "27"=>{:character_code=>"18", :description=>"Spinning gun"},
    "28"=>{:character_code=>"10", :description=>"Pusher"},
    "29"=>{:character_code=>"EA", :description=>"Lion"},
    "2a"=>{:character_code=>"E3", :description=>"Tiger"},
    "2b"=>{:character_code=>"BA", :description=>"Vertical blink wall ray"},
    "2c"=>{:character_code=>"E9", :description=>"Centipede head"},
    "2d"=>{:character_code=>"4F", :description=>"Centipede segment"},
    "2f"=>{:character_code=>"20", :description=>"Blue text"},
    "30"=>{:character_code=>"20", :description=>"Green text"},
    "31"=>{:character_code=>"20", :description=>"Cyan text"},
    "32"=>{:character_code=>"20", :description=>"Red text"},
    "33"=>{:character_code=>"20", :description=>"Purple text"},
    "34"=>{:character_code=>"20", :description=>"Yellow text"},
    "35"=>{:character_code=>"20", :description=>"White text"},
    "36"=>{:character_code=>"20", :description=>"White blinking text"},
    "37"=>{:character_code=>"20", :description=>"Blue blinking text"},
    "38"=>{:character_code=>"20", :description=>"Green blinking text"},
    "39"=>{:character_code=>"20", :description=>"Cyan blinking text"},
    "3a"=>{:character_code=>"20", :description=>"Red blinking text"},
    "3b"=>{:character_code=>"20", :description=>"Purple blinking text"},
    "3c"=>{:character_code=>"20", :description=>"Yellow blinking text"},
    "3d"=>{:character_code=>"20", :description=>"Grey blinking text"}
  }
  
  XCODES = {
   "00" => "Empty Space", 
   "01" => "Special: acts like edge of board", 
   "02" => "Messenger", 
   "03" => "Monitor", 
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

  # DOS_ASCII = (' ☺☻♥♦♣♠•◘○◙♂♀♪♫☼►◄↕‼¶§▬↨↑↓→←∟↔▲▼ !"#$%&' + "'" + '()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~⌂ÇüéâäàåçêëèïîìÄÅÉæÆôöòûùÿÖÜ¢£¥₧ƒáíóúñÑªº¿⌐¬½¼¡«»░▒▓│┤╡╢╖╕╣║╗╝╜╛┐└┴┬├─┼╞╟╚╔╩╦╠═╬╧╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀αßΓπΣσµτΦΘΩδ∞φε∩≡±≥≤⌠⌡÷≈°∙·√ⁿ²■ ').split('')
  # mac_ords = DOS_ASCII.map{|x| x.ord}
  # asdf = mac_ords.zip DOS_ASCII
  # dos_ords = (0..255).map{|x| x}
  # qwer = dos_ords.zip asdf
  #
  # qwer.inject({}){|obj, item|
  #   obj.merge!({item[0] => {code: item[1][0], character: item[1][1]}})
  # }

  def self.dos_ascii(int)
    ascii_ord = case int.class.name
    when "String"
      int.to_i(16)
    else
      int
    end

    DOS_ASCII[ascii_ord][:character]
  end

  DOS_ASCII = {
    0=>{:code=>32, :character=>" "},
    1=>{:code=>9786, :character=>"☺"},
    2=>{:code=>9787, :character=>"☻"},
    3=>{:code=>9829, :character=>"♥"},
    4=>{:code=>9830, :character=>"♦"},
    5=>{:code=>9827, :character=>"♣"},
    6=>{:code=>9824, :character=>"♠"},
    7=>{:code=>8226, :character=>"•"},
    8=>{:code=>9688, :character=>"◘"},
    9=>{:code=>9675, :character=>"○"},
    10=>{:code=>9689, :character=>"◙"},
    11=>{:code=>9794, :character=>"♂"},
    12=>{:code=>9792, :character=>"♀"},
    13=>{:code=>9834, :character=>"♪"},
    14=>{:code=>9835, :character=>"♫"},
    15=>{:code=>9788, :character=>"☼"},
    16=>{:code=>9658, :character=>"►"},
    17=>{:code=>9668, :character=>"◄"},
    18=>{:code=>8597, :character=>"↕"},
    19=>{:code=>8252, :character=>"‼"},
    20=>{:code=>182, :character=>"¶"},
    21=>{:code=>167, :character=>"§"},
    22=>{:code=>9644, :character=>"▬"},
    23=>{:code=>8616, :character=>"↨"},
    24=>{:code=>8593, :character=>"↑"},
    25=>{:code=>8595, :character=>"↓"},
    26=>{:code=>8594, :character=>"→"},
    27=>{:code=>8592, :character=>"←"},
    28=>{:code=>8735, :character=>"∟"},
    29=>{:code=>8596, :character=>"↔"},
    30=>{:code=>9650, :character=>"▲"},
    31=>{:code=>9660, :character=>"▼"},
    32=>{:code=>32, :character=>" "},
    33=>{:code=>33, :character=>"!"},
    34=>{:code=>34, :character=>"\""},
    35=>{:code=>35, :character=>"#"},
    36=>{:code=>36, :character=>"$"},
    37=>{:code=>37, :character=>"%"},
    38=>{:code=>38, :character=>"&"},
    39=>{:code=>39, :character=>"'"},
    40=>{:code=>40, :character=>"("},
    41=>{:code=>41, :character=>")"},
    42=>{:code=>42, :character=>"*"},
    43=>{:code=>43, :character=>"+"},
    44=>{:code=>44, :character=>","},
    45=>{:code=>45, :character=>"-"},
    46=>{:code=>46, :character=>"."},
    47=>{:code=>47, :character=>"/"},
    48=>{:code=>48, :character=>"0"},
    49=>{:code=>49, :character=>"1"},
    50=>{:code=>50, :character=>"2"},
    51=>{:code=>51, :character=>"3"},
    52=>{:code=>52, :character=>"4"},
    53=>{:code=>53, :character=>"5"},
    54=>{:code=>54, :character=>"6"},
    55=>{:code=>55, :character=>"7"},
    56=>{:code=>56, :character=>"8"},
    57=>{:code=>57, :character=>"9"},
    58=>{:code=>58, :character=>":"},
    59=>{:code=>59, :character=>";"},
    60=>{:code=>60, :character=>"<"},
    61=>{:code=>61, :character=>"="},
    62=>{:code=>62, :character=>">"},
    63=>{:code=>63, :character=>"?"},
    64=>{:code=>64, :character=>"@"},
    65=>{:code=>65, :character=>"A"},
    66=>{:code=>66, :character=>"B"},
    67=>{:code=>67, :character=>"C"},
    68=>{:code=>68, :character=>"D"},
    69=>{:code=>69, :character=>"E"},
    70=>{:code=>70, :character=>"F"},
    71=>{:code=>71, :character=>"G"},
    72=>{:code=>72, :character=>"H"},
    73=>{:code=>73, :character=>"I"},
    74=>{:code=>74, :character=>"J"},
    75=>{:code=>75, :character=>"K"},
    76=>{:code=>76, :character=>"L"},
    77=>{:code=>77, :character=>"M"},
    78=>{:code=>78, :character=>"N"},
    79=>{:code=>79, :character=>"O"},
    80=>{:code=>80, :character=>"P"},
    81=>{:code=>81, :character=>"Q"},
    82=>{:code=>82, :character=>"R"},
    83=>{:code=>83, :character=>"S"},
    84=>{:code=>84, :character=>"T"},
    85=>{:code=>85, :character=>"U"},
    86=>{:code=>86, :character=>"V"},
    87=>{:code=>87, :character=>"W"},
    88=>{:code=>88, :character=>"X"},
    89=>{:code=>89, :character=>"Y"},
    90=>{:code=>90, :character=>"Z"},
    91=>{:code=>91, :character=>"["},
    92=>{:code=>92, :character=>"\\"},
    93=>{:code=>93, :character=>"]"},
    94=>{:code=>94, :character=>"^"},
    95=>{:code=>95, :character=>"_"},
    96=>{:code=>96, :character=>"`"},
    97=>{:code=>97, :character=>"a"},
    98=>{:code=>98, :character=>"b"},
    99=>{:code=>99, :character=>"c"},
    100=>{:code=>100, :character=>"d"},
    101=>{:code=>101, :character=>"e"},
    102=>{:code=>102, :character=>"f"},
    103=>{:code=>103, :character=>"g"},
    104=>{:code=>104, :character=>"h"},
    105=>{:code=>105, :character=>"i"},
    106=>{:code=>106, :character=>"j"},
    107=>{:code=>107, :character=>"k"},
    108=>{:code=>108, :character=>"l"},
    109=>{:code=>109, :character=>"m"},
    110=>{:code=>110, :character=>"n"},
    111=>{:code=>111, :character=>"o"},
    112=>{:code=>112, :character=>"p"},
    113=>{:code=>113, :character=>"q"},
    114=>{:code=>114, :character=>"r"},
    115=>{:code=>115, :character=>"s"},
    116=>{:code=>116, :character=>"t"},
    117=>{:code=>117, :character=>"u"},
    118=>{:code=>118, :character=>"v"},
    119=>{:code=>119, :character=>"w"},
    120=>{:code=>120, :character=>"x"},
    121=>{:code=>121, :character=>"y"},
    122=>{:code=>122, :character=>"z"},
    123=>{:code=>123, :character=>"{"},
    124=>{:code=>124, :character=>"|"},
    125=>{:code=>125, :character=>"}"},
    126=>{:code=>126, :character=>"~"},
    127=>{:code=>8962, :character=>"⌂"},
    128=>{:code=>199, :character=>"Ç"},
    129=>{:code=>252, :character=>"ü"},
    130=>{:code=>233, :character=>"é"},
    131=>{:code=>226, :character=>"â"},
    132=>{:code=>228, :character=>"ä"},
    133=>{:code=>224, :character=>"à"},
    134=>{:code=>229, :character=>"å"},
    135=>{:code=>231, :character=>"ç"},
    136=>{:code=>234, :character=>"ê"},
    137=>{:code=>235, :character=>"ë"},
    138=>{:code=>232, :character=>"è"},
    139=>{:code=>239, :character=>"ï"},
    140=>{:code=>238, :character=>"î"},
    141=>{:code=>236, :character=>"ì"},
    142=>{:code=>196, :character=>"Ä"},
    143=>{:code=>197, :character=>"Å"},
    144=>{:code=>201, :character=>"É"},
    145=>{:code=>230, :character=>"æ"},
    146=>{:code=>198, :character=>"Æ"},
    147=>{:code=>244, :character=>"ô"},
    148=>{:code=>246, :character=>"ö"},
    149=>{:code=>242, :character=>"ò"},
    150=>{:code=>251, :character=>"û"},
    151=>{:code=>249, :character=>"ù"},
    152=>{:code=>255, :character=>"ÿ"},
    153=>{:code=>214, :character=>"Ö"},
    154=>{:code=>220, :character=>"Ü"},
    155=>{:code=>162, :character=>"¢"},
    156=>{:code=>163, :character=>"£"},
    157=>{:code=>165, :character=>"¥"},
    158=>{:code=>8359, :character=>"₧"},
    159=>{:code=>402, :character=>"ƒ"},
    160=>{:code=>225, :character=>"á"},
    161=>{:code=>237, :character=>"í"},
    162=>{:code=>243, :character=>"ó"},
    163=>{:code=>250, :character=>"ú"},
    164=>{:code=>241, :character=>"ñ"},
    165=>{:code=>209, :character=>"Ñ"},
    166=>{:code=>170, :character=>"ª"},
    167=>{:code=>186, :character=>"º"},
    168=>{:code=>191, :character=>"¿"},
    169=>{:code=>8976, :character=>"⌐"},
    170=>{:code=>172, :character=>"¬"},
    171=>{:code=>189, :character=>"½"},
    172=>{:code=>188, :character=>"¼"},
    173=>{:code=>161, :character=>"¡"},
    174=>{:code=>171, :character=>"«"},
    175=>{:code=>187, :character=>"»"},
    176=>{:code=>9617, :character=>"░"},
    177=>{:code=>9618, :character=>"▒"},
    178=>{:code=>9619, :character=>"▓"},
    179=>{:code=>9474, :character=>"│"},
    180=>{:code=>9508, :character=>"┤"},
    181=>{:code=>9569, :character=>"╡"},
    182=>{:code=>9570, :character=>"╢"},
    183=>{:code=>9558, :character=>"╖"},
    184=>{:code=>9557, :character=>"╕"},
    185=>{:code=>9571, :character=>"╣"},
    186=>{:code=>9553, :character=>"║"},
    187=>{:code=>9559, :character=>"╗"},
    188=>{:code=>9565, :character=>"╝"},
    189=>{:code=>9564, :character=>"╜"},
    190=>{:code=>9563, :character=>"╛"},
    191=>{:code=>9488, :character=>"┐"},
    192=>{:code=>9492, :character=>"└"},
    193=>{:code=>9524, :character=>"┴"},
    194=>{:code=>9516, :character=>"┬"},
    195=>{:code=>9500, :character=>"├"},
    196=>{:code=>9472, :character=>"─"},
    197=>{:code=>9532, :character=>"┼"},
    198=>{:code=>9566, :character=>"╞"},
    199=>{:code=>9567, :character=>"╟"},
    200=>{:code=>9562, :character=>"╚"},
    201=>{:code=>9556, :character=>"╔"},
    202=>{:code=>9577, :character=>"╩"},
    203=>{:code=>9574, :character=>"╦"},
    204=>{:code=>9568, :character=>"╠"},
    205=>{:code=>9552, :character=>"═"},
    206=>{:code=>9580, :character=>"╬"},
    207=>{:code=>9575, :character=>"╧"},
    208=>{:code=>9576, :character=>"╨"},
    209=>{:code=>9572, :character=>"╤"},
    210=>{:code=>9573, :character=>"╥"},
    211=>{:code=>9561, :character=>"╙"},
    212=>{:code=>9560, :character=>"╘"},
    213=>{:code=>9554, :character=>"╒"},
    214=>{:code=>9555, :character=>"╓"},
    215=>{:code=>9579, :character=>"╫"},
    216=>{:code=>9578, :character=>"╪"},
    217=>{:code=>9496, :character=>"┘"},
    218=>{:code=>9484, :character=>"┌"},
    219=>{:code=>9608, :character=>"█"},
    220=>{:code=>9604, :character=>"▄"},
    221=>{:code=>9612, :character=>"▌"},
    222=>{:code=>9616, :character=>"▐"},
    223=>{:code=>9600, :character=>"▀"},
    224=>{:code=>945, :character=>"α"},
    225=>{:code=>223, :character=>"ß"},
    226=>{:code=>915, :character=>"Γ"},
    227=>{:code=>960, :character=>"π"},
    228=>{:code=>931, :character=>"Σ"},
    229=>{:code=>963, :character=>"σ"},
    230=>{:code=>181, :character=>"µ"},
    231=>{:code=>964, :character=>"τ"},
    232=>{:code=>934, :character=>"Φ"},
    233=>{:code=>920, :character=>"Θ"},
    234=>{:code=>937, :character=>"Ω"},
    235=>{:code=>948, :character=>"δ"},
    236=>{:code=>8734, :character=>"∞"},
    237=>{:code=>966, :character=>"φ"},
    238=>{:code=>949, :character=>"ε"},
    239=>{:code=>8745, :character=>"∩"},
    240=>{:code=>8801, :character=>"≡"},
    241=>{:code=>177, :character=>"±"},
    242=>{:code=>8805, :character=>"≥"},
    243=>{:code=>8804, :character=>"≤"},
    244=>{:code=>8992, :character=>"⌠"},
    245=>{:code=>8993, :character=>"⌡"},
    246=>{:code=>247, :character=>"÷"},
    247=>{:code=>8776, :character=>"≈"},
    248=>{:code=>176, :character=>"°"},
    249=>{:code=>8729, :character=>"∙"},
    250=>{:code=>183, :character=>"·"},
    251=>{:code=>8730, :character=>"√"},
    252=>{:code=>8319, :character=>"ⁿ"},
    253=>{:code=>178, :character=>"²"},
    254=>{:code=>9632, :character=>"■"},
    255=>{:code=>32, :character=>" "}
  }

  
  
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
