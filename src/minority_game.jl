# Reference:「ゲーム理論アプリケーションブック」の第10章少人数ゲーム
module MinorityGame

# 定数定義
const STRATEGY_COUNT = 2 # 各プレイヤーが持つ戦略の数

struct Player
    memory_length :: Int # 記憶長
    strategies::Vector{Vector{UInt64}} # 戦略
end

# プレイヤー生成。引数は、キー=記憶長,バリュー=人数、の辞書(記憶長の分布)
function create_players(memory_length_dist::Dict{Int,Int})
    players = Player[]
    for (mlen, number) in Iterators.filter(pair -> pair[2] > 0, memory_length_dist)
        bit_size = 2^mlen
        for _ in (1:number)
            strategies = Vector{UInt64}[]
            # ランダムかつ重複なしで戦略を割り当てる
            while length(strategies) < STRATEGY_COUNT
                # Note:戦略の表現について
                #   行動は 0 or 1 なので、記憶長mの履歴は、2^m 通りの値をとる(0~2^m-1)
                #   戦略を2^(2^m)ビットの値で表現し、履歴から算出される値は、そのビット位置を示すと考える。
                #   64ビット整数で考え、64ビットを越える場合、配列の1要素目が1~64ビット、2要素目が65~128ビット...となるようにする。
                _s = bit_size < 64 ? [UInt64(rand(0:2^bit_size-1))] : rand(UInt64, div(bit_size, 64))
                # 戦略の配列に加える
                if false == any(==(_s), strategies); push!(strategies, _s); end
            end
            push!(players, Player(mlen, strategies))
        end
    end
    return players
end

import LinearAlgebra
# 戦略から行動{0,1}を選択する
# 第2引数は、少数派だった行動の履歴。添え字が大きい方が、最近の履歴。
function select_action(strategy::Vector{UInt64}, minority_hist)
    history_value = LinearAlgebra.dot(minority_hist, [2^(i-1) for i in (length(minority_hist):-1:1)])
    s_index = Int(floor(history_value/64)) + 1
    s_bit = history_value%64
    return ((strategy[s_index]) & (1 << s_bit)) >> s_bit
end

# シミュレーション実行
function simulate(players::Vector{Player}, turn_max::Int, get_randomaction = ()->rand(0:1))
    player_number = length(players)
    if player_number < 3 || player_number % 2 == 0; @error ""; end
    threshold_minority = div(player_number - 1,2)
    is_minority(n) = n <= threshold_minority
    # 各ターンで行動0を選択した人数
    history = zeros(Int, turn_max)
    # 各プレイヤーの勝ち数(=少数派を選んだ回数)
    wincount_eachplayer = zeros(Int, player_number)
    # 各プレイヤーの各戦略の勝ち数(戦略のパフォーマンス評価に使用)
    wincount_eachstrategy = zeros(Int, player_number, STRATEGY_COUNT)

    for t in (1:turn_max)
        # このターンで各プレイヤーが選んだ行動
        action_eachplayer = zeros(Int8,player_number)
        # 各プレイヤーの行動選択
        for i in (1:player_number)
            if players[i].memory_length < t
                # パフォーマンスが最大な戦略からランダムに選ぶ
                sorted_s = sort([(wincount_eachstrategy[i,s],s) for s in 1:STRATEGY_COUNT], rev=true)
                s_index = rand(last.(Iterators.filter(pair -> pair[1] == sorted_s[1][1],sorted_s)))
                action_eachplayer[i] = Int8(select_action(players[i].strategies[s_index]
                                                         , map(n -> is_minority(n) ? 0 : 1, history[t-players[i].memory_length:t-1])))
            else
                action_eachplayer[i] = Int8(get_randomaction())
            end
        end
        number_of_selected0 = player_number - sum(action_eachplayer)
        history[t] = number_of_selected0
        minority_action = is_minority(number_of_selected0) ? Int8(0) : Int8(1)

        # 勝ち数集計
        for i in (1:player_number)
            wincount_eachplayer[i] += (action_eachplayer[i] == minority_action) ? 1 : 0

            if players[i].memory_length >= t; continue; end
            for s in (1:STRATEGY_COUNT)
                action = Int8(select_action(players[i].strategies[s]
                                           , map(n -> is_minority(n) ? 0 : 1, history[t-players[i].memory_length:t-1])))
                wincount_eachstrategy[i,s] += (minority_action == action) ? 1 : 0
            end
        end
    end
    return (history, wincount_eachplayer)
end

end # end of module
