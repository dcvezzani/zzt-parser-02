require 'byebug'
require 'json'

FDEBUG = true

# tour_content = IO.read("./TOUR.ZZT")
# tour_content = IO.read("../DEMO.ZZT")
tour_content = IO.read("./MATT2.ZZT")
# tour_content = IO.read("./XXX.ZZT")

# tour_content[0..10]
#
# hex_length("1E-31")
# hex_length("33-46")
# hex_length("F1-104")
# hex_length("106-104")
# hex_length("108-200")
# hex_length("00-108")
# hex_add_dec("33", 190)

def hex_add_dec(hex, dec, zero=false)
  offset = (zero) ? (dec - 1) : dec
  (hex.to_i(16) + offset).to_s(16)
end

def hex_length(exp)
  parts = exp.split(/-/)
  (parts[1].to_i(16) - parts[0].to_i(16)) + 1
end

def color_desc(color)
  keys = [:background, :foreground]
  background, foreground = color.split("")
  # res = keys.zip(values).inject({}){ |h,(k,v)| h[k] = v; h }
  {code: color, foreground: {code: foreground, description: FOREGROUND_COLORS[foreground]}, background: {code: background, description: BACKGROUND_COLORS[background]}}
end

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

codes = {
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

GAME_HEADER_PARSE = "H4S3C7S7CA20CA20CA20CA20CA20CA20CA20CA20CA20CA20H40SH4CH496"
BOARD_HEADER_PARSE = "SCA33H34"
BOARD_HEADER_LESS_PARSE = "CA33H34"
BOARD_SIZE_PARSE = "S"
BOARD_INFO_PARSE = "C8H116H4SH32S"
TILE_PARSE = "CH2H2"
OBJECT_PARSE = "CCSSSCCCH8CCH8SSH16"
OBJECT_DATA_PARSE = "A*"

# game_header
keys = [:magic_num, :boards_cnt_z, :ammo, :gems, :bk, :gk, :ck, :rk, :pk, :yk, :wk, :health, :board_str, :torch_cnt, :tcycle_cnt, :ecycle_cnt, :pad_01, :score, :title_cnt, :title_x, :flg1_cnt, :flg1, :flg2_cnt, :flg2, :flg3_cnt, :flg3, :flg4_cnt, :flg4, :flg5_cnt, :flg5, :flg6_cnt, :flg6, :flg7_cnt, :flg7, :flg8_cnt, :flg8, :flg9_cnt, :flg9, :pad_02, :timeleft, :pad_03, :saved_game, :pad_04 ]
values = tour_content[("00".to_i(16))..("200".to_i(16))].unpack(GAME_HEADER_PARSE)
game_header = keys.zip(values).inject({}){ |h,(k,v)| h[k] = v; h }
game_header[:title] = game_header[:title_x].slice(0, game_header[:title_cnt])
game_header.delete(:title_x)

start = ("200".to_i(16))
boards = {}
board_stops = [512]

(0..game_header[:boards_cnt_z]).each do |board_idx|

  keys = [:board_size, :title_cnt, :title_x, :pad_01]
  values = tour_content[(start)...(start + hex_length("00-34"))].unpack(BOARD_HEADER_PARSE)
  board_header = keys.zip(values).inject({}){ |h,(k,v)| h[k] = v; h }
  board_header[:title] = board_header[:title_x].slice(0, board_header[:title_cnt])
  board_header.delete(:title_x)
  board_stop = (start + board_header[:board_size] + 2)

  # board_tiles
  max_tile_cnt = 60*25 #1500
  start = start + hex_length("00-34")
  tile_cnt = 0
  tiles = []
  objects = {0 => nil}

  while (tile_cnt < max_tile_cnt)
    repeat_cnt, code, raw_data = tour_content[start..board_stop].unpack(TILE_PARSE)

    decimal_code = code.to_i(16)
    colour = text = nil
    
    if (decimal_code >= "2f".to_i(16))
      tile_pos = (tile_cnt + 1)
      row = (tile_pos/60).round + 1
      col = (tile_pos%60)
      
      # puts ">>> #{tile_pos}: #{col},#{row} #{[repeat_cnt, code, raw_data]}"
      # debugger
      text = raw_data.to_i(16).chr
      
      tiles << [repeat_cnt, code, text]
      tile_cnt += repeat_cnt

      File.open("./chk.txt", "a"){|f| f.write "<< #{tile_cnt}, #{tiles.last}, #{col},#{row}: #{codes[code]}\n" } if FDEBUG

    else
      colour = raw_data #.unpack("H*")

      if %w{04 0a 0b 0c 0d 0f 10 11 12 1d 22 23 24 25 26 27 28 29 2a 21 2b 2c 2d}.include?(code)
        (1..repeat_cnt).each do
          tile_pos = (tile_cnt + 1)
          row = (tile_pos/60).round + 1
          col = (tile_pos%60)
          
          tiles << [1, code, colour]

          if code == "04"
            objects[0] = {x: col, y: row, tile: tiles.last}
          else
            objects[objects.size] = {x: col, y: row, tile: tiles.last}
          end

          tile_cnt += 1

          File.open("./chk.txt", "a"){|f| f.write "<< #{tile_cnt}, #{tiles.last}, #{col},#{row}: #{codes[code]}\n" } if FDEBUG
        end

      else
        tile_pos = (tile_cnt + 1)
        row = (tile_pos/60).round + 1
        col = (tile_pos%60)

        tiles << [repeat_cnt, code, colour]
        tile_cnt += repeat_cnt

        File.open("./chk.txt", "a"){|f| f.write "<< #{tile_cnt}, #{tiles.last}, #{col},#{row}: #{codes[code]}\n" } if FDEBUG
      end
    end

    start += 3
  end

   File.open("./chk.txt", "a"){|f| f.write "{board: {idx: #{board_idx}, title: #{board_header[:title]}}}\n" } if FDEBUG
  
  # board_info
  keys = [:max_shots, :darkness, :bn, :bs, :bw, :be, :reenter, :message_len, :message, :pad_01, :time_limit, :pad_02, :obj_cnt]
  values = tour_content[start..board_stop].unpack(BOARD_INFO_PARSE)
  board_info = keys.zip(values).inject({}){ |h,(k,v)| h[k] = v; h }

  start += hex_length("00-57") #88

  (0..board_info[:obj_cnt]).each do |obj_idx|
    # object_info
    keys = [:x, :y, :x_step, :y_step, :cycle, :p1, :p2, :p3, :p4, :ut, :uc, :pointer, :cur_ins, :len, :pad_01]
    values = tour_content[(start)..board_stop].unpack(OBJECT_PARSE)
    object_info = keys.zip(values).inject({}){ |h,(k,v)| h[k] = v; h }

    start += 33
    
    if object_info[:len] > 0
      object_info[:data] = tour_content[(start)...(start + object_info[:len])].unpack(OBJECT_DATA_PARSE)
      start += object_info[:len]
    end

    File.open("./chk.txt", "a"){|f| f.write "<< #{object_info[:x]},#{object_info[:y]}: #{object_info}\n" } if FDEBUG
    
  debugger if obj_idx == 55
    
    begin
      fnd_idx = objects.select{|idx, obj| ((obj[:x] == object_info[:x]) && (obj[:y] == object_info[:y]))}.first.first
    rescue
      err = {board_idx: board_idx, board_header: board_header, board_info: board_info, obj_cnt: [board_info[:obj_cnt], objects.size], obj_idx: obj_idx, object_info: object_info}
      throw "Error: #{err}"
    end

    
    objects[fnd_idx][:type] = codes[objects[fnd_idx][:tile][1]]
    objects[fnd_idx][:color] = color_desc(objects[fnd_idx][:tile][2])
    objects[fnd_idx][:info] = object_info
  end


  # chk = nil
  # if board_idx == 8
  #   debugger 
  #
  #   chk = objects.inject({}){|a, b| 
  #     key = b[1][:tile][1]
  #     val = (a[key]) ? a[key] + b[1][:tile][0] : b[1][:tile][0]
  #     a.merge!(key => val)
  #   }
  #
  #   chk.to_a.sort
  # end


  boards[board_idx] = {header: board_header, info: board_info, tiles: tiles, objects: objects}
end

File.open("./game.txt", "w"){|f| f.write ({game: {header: game_header, boards: boards}}.to_json) }


File.open("./matt.zzt", "wb"){|f| f.write ""}
File.open("./matt.zzt", "ab"){|f|


# TODO: fill spaces with '00' instead of '20'
  f.write [:magic_num, :boards_cnt_z, :ammo, :gems, :bk, :gk, :ck, :rk, :pk, :yk, :wk, :health, :board_str, :torch_cnt, :tcycle_cnt, :ecycle_cnt, :pad_01, :score, :title_cnt, :title_x, :flg1_cnt, :flg1, :flg2_cnt, :flg2, :flg3_cnt, :flg3, :flg4_cnt, :flg4, :flg5_cnt, :flg5, :flg6_cnt, :flg6, :flg7_cnt, :flg7, :flg8_cnt, :flg8, :flg9_cnt, :flg9, :pad_02, :timeleft, :pad_03, :saved_game, :pad_04 ].map{|key| game_header[key]}.pack(GAME_HEADER_PARSE)

# GAME_HEADER_PARSE = "H4S3C7S7CA20CA20CA20CA20CA20CA20CA20CA20CA20CA20H40SH4CH496"
# BOARD_HEADER_PARSE = "SCA33H32"
# BOARD_INFO_PARSE = "C8H116H4SH32S"
# TILE_PARSE = "CH2H2"
# TEXT_PARSE = "A"
# OBJECT_PARSE = "CCSSSCCCH8CCH8SSH16"
# OBJECT_DATA_PARSE = "A*"

# hex_length("03-23")

# boards[board_idx] = {header: board_header, info: board_info, tiles: tiles, objects: objects}
boards.each do |idx, board|

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
    puts ">>> #{tile_pos}: #{col},#{row} #{(board[:tiles][tile_idx])}"
    code = (board[:tiles][tile_idx])[1]
    decimal_code = code.to_i(16)
    tile = (board[:tiles][tile_idx])
    
    if (decimal_code >= "2f".to_i(16))
      character = [[(board[:tiles][tile_idx][2])].pack("A")].first
      tile = board[:tiles][tile_idx][0..1] + [character.ord.to_s(16)]
    end

    board_content += (tile.pack(TILE_PARSE))
  end

  board_content += [:max_shots, :darkness, :bn, :bs, :bw, :be, :reenter, :message_len, :message, :pad_01, :time_limit, :pad_02, :obj_cnt].map{|key| board[:info][key]}.pack(BOARD_INFO_PARSE)

  board[:objects].each do |idx, object|
    board_content += [:x, :y, :x_step, :y_step, :cycle, :p1, :p2, :p3, :p4, :ut, :uc, :pointer, :cur_ins, :len, :pad_01].map{|key| object[:info][key]}.pack(OBJECT_PARSE)

    if object[:info][:data]
      board_content += object[:info][:data].pack(OBJECT_DATA_PARSE)
    end
  end

  f.write ([board_content.length].pack("S") + board_content)
end

}

