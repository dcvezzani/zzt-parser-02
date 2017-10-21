tour_content = IO.read("./TOUR.ZZT")
tour_content = IO.read("./XXX.ZZT")

tour_content[0..10]

hex_length("1E-31")
hex_length("33-46")
hex_length("F1-104")
hex_length("106-104")
hex_length("108-200")
hex_length("00-108")
hex_add_dec("33", 190)

def hex_add_dec(hex, dec, zero=false)
  offset = (zero) ? (dec - 1) : dec
  (hex.to_i(16) + offset).to_s(16)
end

def hex_length(exp)
  parts = exp.split(/-/)
  (parts[1].to_i(16) - parts[0].to_i(16)) + 1
end




# game_header
keys = [:magic_num, :boards_cnt_z, :ammo, :gems, :bk, :gk, :ck, :rk, :pk, :yk, :wk, :health, :board_str, :torch_cnt, :tcycle_cnt, :ecycle_cnt, :pad_01, :score, :title_cnt, :title_x, :flg1_cnt, :flg1, :flg2_cnt, :flg2, :flg3_cnt, :flg3, :flg4_cnt, :flg4, :flg5_cnt, :flg5, :flg6_cnt, :flg6, :flg7_cnt, :flg7, :flg8_cnt, :flg8, :flg9_cnt, :flg9, :pad_02, :timeleft, :pad_03, :saved_game, :pad_04 ]
values = tour_content[("00".to_i(16))..("200".to_i(16))].unpack("H4S3C7S7CA20CA20CA20CA20CA20CA20CA20CA20CA20CA20H20SH2CH249")
game_header = keys.zip(values).inject({}){ |h,(k,v)| h[k] = v; h }

# board_header
start = ("200".to_i(16))
board_size = tour_content[start..start+1].unpack("S").first #5138
board_stop = hex_add_dec("200", board_size+1).to_i(16)

keys = [:board_size, :title_cnt, :title, :pad_01]
values = tour_content[(start+2)..board_stop].unpack("CA33H16").unshift(board_size)
board_header = keys.zip(values).inject({}){ |h,(k,v)| h[k] = v; h }

# board_tiles
start = ("200".to_i(16))

max_tile_cnt = 60*25 #1500
# start = ("235".to_i(16))
start = start + hex_length("00-33") + 1
tile_cnt = 0
tiles = []

while (tile_cnt < max_tile_cnt)
  repeat_cnt, raw_code, raw_data = tour_content[start..board_stop].unpack("CaA")

  code = raw_code.unpack('H*')[0]
  decimal_code = code.to_i(16)
  colour = text = nil
  if (decimal_code >= "2f".to_i(16))
    text = raw_data
    tiles << [repeat_cnt, code, text]
  else
    colour = raw_data.unpack('H*')[0]
    tiles << [repeat_cnt, code, colour]
  end

  tile_cnt += repeat_cnt
  puts "<< #{tile_cnt}, #{tiles.last}"
  # File.open("./chk.txt", "a"){|f| f.write "<< #{tile_cnt}, #{tiles.last}\n" }
  start += 3
end

# board_info
keys = [:max_shots, :darkness, :bn, :bs, :bw, :be, :reenter, :message_len, :message, :pad_01, :time_limit, :pad_02, :obj_cnt]
values = tour_content[start..board_stop].unpack("C8H58H2SH16SSSSSSSSSSSSSSSSS")
game_board = keys.zip(values).inject({}){ |h,(k,v)| h[k] = v; h }

start = ("1613".to_i(16))


# values = tour_content[("00".to_i(16))..("1D".to_i(16))].unpack("H4S3C7S7C")
# game = keys.zip(values).inject({}){ |h,(k,v)| h[k] = v; h }
# title_len = hex_add_dec("1E", game[:title_cnt], true)
# tour_content[("32".to_i(16))..("46".to_i(16))].unpack("CA*")
