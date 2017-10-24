require 'byebug'
require 'json'

class ZztParser02
  
  def initialize(src_file = nil)
    self.src_file = src_file
    self.game_header = {}
    self.boards = {}

    if src_file
      file_content = IO.read(src_file)
      self.game_header, self.boards = Deserializer.new(file_content).go(true)
    end
  end

  def self.import(src_file = './matt.json')
    parser = ZztParser02.new

    file_content = IO.read(src_file)
    game = JSON::load(file_content)["game"]
    self.game_header, self.boards = Importer.new(game).go

  end

  def deserialize(dst_file = './game.txt')
    File.open(dst_file, "w"){|f| f.write ({game: {header: self.game_header, boards: self.boards}}.to_json) }
  end

  class Importer
    def initialize(json)
      self.json = json

      self._game_header = {}
      self._boards = {}
      
      self._board_header = {}
      self._board_info = {}
      self._tiles = []
      self._objects = {0 => nil}
    end
      
    def go
      game = self.json
      
      self._game_header = game['header'].inject({}){|a,b| a.merge!({b[0].to_sym => b[1]})}
      self._game_header[:boards_cnt_z] = (game['boards'].length - 1)

      game['boards'].each do |idx, board|

        self._board_header = board['header'].inject({}){|a,b| a.merge!({b[0].to_sym => b[1]})}
        self._tiles = board['tiles']
        self._board_info = board['info'].inject({}){|a,b| a.merge!({b[0].to_sym => b[1]})}
        self._board_info[:obj_cnt] = (game['objects'].length - 1)
        
        self._objects = {}
        board['objects'].each do |idx, object|
          self._objects[idx.to_i(10)] = game['objects'][idx]['info'].inject({}){|a,b| a.merge!({b[0].to_sym => b[1]})}
        end

        self._boards[idx.to_i(10)] = {header: self._board_header, info: self._board_info, tiles: self._tiles, objects: self._objects}

        [self._game_header, self._boards]
      end
    end
  end

  class Deserializer
    def initialize(content)
      self.content = content
      self.start = nil
      self.board_stop = nil

      self._game_header = {}
      self._boards = {}

      # TODO: shouldn't be instance variables
      self._board_header = {}
      self._board_info = {}
      self._tiles = []
      self._objects = {0 => nil}
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
        keys = [:x, :y, :x_step, :y_step, :cycle, :p1, :p2, :p3, :p4, :ut, :uc, :pointer, :cur_ins, :len, :pad_01]
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
          err = {board_idx: board_idx, board_header: board_header, board_info: board_info, obj_cnt: [board_info[:obj_cnt], self._objects.size], obj_idx: obj_idx, object_info: object_info}
          throw "Error: #{err}"
        end

        
        self._objects[fnd_idx][:type] = ZztParser02::CODES[self._objects[fnd_idx][:tile][1]]
        self._objects[fnd_idx][:color] = ZztParser02::color_desc(self._objects[fnd_idx][:tile][2])
        self._objects[fnd_idx][:info] = object_info
      end

      self._objects
    end

    def board_info(reparse = false)
      return self._board_info if self._board_info.size > 0 and !reparse

      keys = [:max_shots, :darkness, :bn, :bs, :bw, :be, :reenter, :message_len, :message, :pad_01, :time_limit, :pad_02, :obj_cnt]
      values = self.content[self.start..self.board_stop].unpack(ZztParser02::BOARD_INFO_PARSE)
      self._board_info = keys.zip(values).inject({}){ |h,(k,v)| h[k] = v; h }

      message_len = (self._board_info[:message_len])
      self._board_info[:message] = (self._board_info[:message]).slice(0, message_len)

      self.start += hex_length("00-57") #88

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

          if %w{04 0a 0b 0c 0d 0f 10 11 12 1d 22 23 24 25 26 27 28 29 2a 21 2b 2c 2d}.include?(code)
            (1..repeat_cnt).each do
              tile_pos = (tile_cnt + 1)
              row = (tile_pos/60).round + 1
              col = (tile_pos%60)
              
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
      values = self.content[(start)...(start + hex_length("00-34"))].unpack(ZztParser02::BOARD_HEADER_PARSE)
      self._board_header = keys.zip(values).inject({}){ |h,(k,v)| h[k] = v; h }
      self._board_header[:title] = self._board_header[:title_x].slice(0, self._board_header[:title_cnt])
      self._board_header.delete(:title_x)
      self.board_stop = (self.start + self._board_header[:board_size] + 2)

      self.start = self.start + hex_length("00-34")
      
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

  def hex_add_dec(hex, dec, zero=false)
    offset = (zero) ? (dec - 1) : dec
    (hex.to_i(16) + offset).to_s(16)
  end

  def hex_length(exp)
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
  OBJECT_PARSE = "CCSSSCCCH8CCH8SSH16"
  OBJECT_DATA_PARSE = "A*"

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
  # hex_length("13-26")
  # hex_length("108-200")
  
end

game = ZztParser02.new('/Users/davidvezzani/ruby_apps/zzt-parser-02/matt.zzt')
game.deserialize('/Users/davidvezzani/ruby_apps/zzt-parser-02/matt.json')

game = ZztParser02.import('/Users/davidvezzani/ruby_apps/zzt-parser-02/matt.json')
game.serialize('/Users/davidvezzani/ruby_apps/zzt-parser-02/matt.zzt')
