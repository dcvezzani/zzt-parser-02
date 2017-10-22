require 'byebug'

# tour_content = IO.read("./TOUR.ZZT")
tour_content = IO.read("../DEMO.ZZT")
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

# hex_length("13-26")
# hex_length("108-200")

# game_header
keys = [:magic_num, :boards_cnt_z, :ammo, :gems, :bk, :gk, :ck, :rk, :pk, :yk, :wk, :health, :board_str, :torch_cnt, :tcycle_cnt, :ecycle_cnt, :pad_01, :score, :title_cnt, :title_x, :flg1_cnt, :flg1, :flg2_cnt, :flg2, :flg3_cnt, :flg3, :flg4_cnt, :flg4, :flg5_cnt, :flg5, :flg6_cnt, :flg6, :flg7_cnt, :flg7, :flg8_cnt, :flg8, :flg9_cnt, :flg9, :pad_02, :timeleft, :pad_03, :saved_game, :pad_04 ]
values = tour_content[("00".to_i(16))..("200".to_i(16))].unpack("H4S3C7S7CA20CA20CA20CA20CA20CA20CA20CA20CA20CA20H40SH4CH498")
game_header = keys.zip(values).inject({}){ |h,(k,v)| h[k] = v; h }

start = ("200".to_i(16))
boards = {}

(0..game_header[:boards_cnt_z]).each do |board_idx|

  # board_header
  board_size = tour_content[start..start+1].unpack("S").first #5138
  # board_stop = hex_add_dec("200", board_size+1).to_i(16)
  board_stop = (start + board_size+1)

  keys = [:board_size, :title_cnt, :title, :pad_01]
  values = tour_content[(start+2)..board_stop].unpack("CA33H32").unshift(board_size)
  board_header = keys.zip(values).inject({}){ |h,(k,v)| h[k] = v; h }

  # board_tiles
  # start = ("200".to_i(16))
  max_tile_cnt = 60*25 #1500
  start = start + hex_length("00-33") + 1
  tile_cnt = 0
  tiles = []
  objects = {}

  while (tile_cnt < max_tile_cnt)
    repeat_cnt, raw_code, raw_data = tour_content[start..board_stop].unpack("CaA")

    code = raw_code.unpack('H*')[0]
    decimal_code = code.to_i(16)
    colour = text = nil

    tile_pos = (tile_cnt + 1)
    row = (tile_pos/60).round + 1
    col = (tile_pos%60)
    
    if (decimal_code >= "2f".to_i(16))
      text = raw_data
      tiles << [repeat_cnt, code, text]
    else
      colour = raw_data.unpack('H*')[0]
      tiles << [repeat_cnt, code, colour]

      if %w{04 0a 0b 0c 0d 22 23 24 25 26 27 28 29 2a 21 2b 2c 2d 12 0f}.include?(code)
        # tile_pos = (tile_cnt + 1)
        # row = (tile_pos/60).round + 1
        # col = (tile_pos%60)

        if code == "04"
          objects[0] = {x: col, y: row, tile: tiles.last}
        else
          objects[objects.size + 1] = {x: col, y: row, tile: tiles.last}
        end
      end
    end

    tile_cnt += repeat_cnt
    puts "<< #{tile_cnt}, #{tiles.last}"
    File.open("./chk.txt", "a"){|f| f.write "<< #{tile_cnt}, #{tiles.last}, #{row},#{col}\n" }
    start += 3
  end

  # board_info
  keys = [:max_shots, :darkness, :bn, :bs, :bw, :be, :reenter, :message_len, :message, :pad_01, :time_limit, :pad_02, :obj_cnt]
  values = tour_content[start..board_stop].unpack("C8H116H4SH32S")
  board_info = keys.zip(values).inject({}){ |h,(k,v)| h[k] = v; h }

  start += hex_length("00-57") #88

  chk = nil
  if board_idx == 3
    debugger 

    # ["04", "0a", "0b", "0c", "29", "2c", "2d"] player, scroll, passage, duplicator, lion, centipede head, centipede segment
    
    chk = objects.inject({}){|a, b| 
      key = b[1][:tile][1]
      val = (a[key]) ? a[key] + b[1][:tile][0] : b[1][:tile][0]
      a.merge!(key => val)
    }

    chk.to_a.sort
  end
    

  (0..board_info[:obj_cnt]).each do |obj_idx|
    # object_info
    keys = [:x, :y, :x_step, :y_step, :cycle, :p1, :p2, :p3, :p4, :ut, :uc, :pointer, :cur_ins, :len, :pad_01]
    values = tour_content[(start)..board_stop].unpack("CCSSSCCCH8CCH8SSH16")
    object_info = keys.zip(values).inject({}){ |h,(k,v)| h[k] = v; h }

    start += 33
    
    if object_info[:len] > 0
      object_info[:data] = tour_content[(start)..(start + object_info[:len])].unpack("A*")
      start += object_info[:len]
    end

    File.open("./chk.txt", "a"){|f| f.write "<< #{object_info}\n" }
    
    # begin
    #   fnd_idx = objects.select{|idx, obj| ((obj[:x] == object_info[:x]) && (obj[:y] == object_info[:y]))}.first.first
    # rescue
    #   err = {board_idx: board_idx, board_header: board_header, board_info: board_info, obj_cnt: [board_info[:obj_cnt], objects.size], obj_idx: obj_idx, object_info: object_info}
    #   throw "Error: #{err}"
    # end
    #
    # objects[fnd_idx][:info] = object_info
  end

  # puts "start hex: #{start.to_s(16)}; start dec: #{start}; stop: #{board_stop}"
  # break;


  boards[board_idx] = {header: board_header, info: board_info, tiles: tiles, objects: objects}

  # values = tour_content[("00".to_i(16))..("1D".to_i(16))].unpack("H4S3C7S7C")
  # game = keys.zip(values).inject({}){ |h,(k,v)| h[k] = v; h }
  # title_len = hex_add_dec("1E", game[:title_cnt], true)
  # tour_content[("32".to_i(16))..("46".to_i(16))].unpack("CA*")
end
