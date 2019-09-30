defmodule Rand2d do
  use GenServer

   # DECISION : GOSSIP vs PUSH_SUM
  def init([x,y,n, is_push_sum]) do
    mates = droid_mates(x,y,n)
    case is_push_sum do
      0 -> {:ok, [Active,0, 0, n*n, x, y | mates] } #[ rec_count, sent_count, n, self_number_id-x,y | neighbors ]
      1 -> {:ok, [Active,0, 0, 0, 0, x, 1, n*n , x, y| mates] } #[ rec_count,streak,prev_s_w,to_terminate, s, w, n, self_number_id-x,y | neighbors ]
    end
  end


  # GOSSIP - RECIEVE Main
  def handle_cast({:message_gossip, _received}, [status,count,sent,size,x,y| mates ] = state ) do
    case count < 20 do
      true ->
        GenServer.cast(Master,{:received, [{x,y}]})
        gossip(x,y,mates,self())
      false ->
        GenServer.cast(Master,{:hibernated, [{x,y}]})
    end
    {:noreply,[status,count+1 ,sent,size, x , y | mates]}
  end

  #GOSSIP  - SEND Main
  def gossip(x,y,mates,pid) do
    the_one = the_chosen_one(mates)
    GenServer.cast(the_one, {:message_gossip, :_sending})
    # case GenServer.call(the_one,:is_active) do
    #   Active -> GenServer.cast(the_one, {:message_gossip, :_sending})
    #   ina_xy -> GenServer.cast(Master,{:droid_inactive, ina_xy})
    #             new_mate = GenServer.call(Master,:handle_node_failure)
    #             GenServer.cast(self(),{:remove_mate,the_one})
    #             GenServer.cast(self(),{:add_new_mate,new_mate})
    #             GenServer.cast(new_mate,{:add_new_mate,droid_name(x,y)})
    #             GenServer.cast(self(),{:retry_gossip,{pid}})
    # end
  end


  # NETWORK : Creating Network
  def create_network(n ,imperfect \\ false, is_push_sum \\ 0) do
    droids =
      for x <- 1..n, y<- 1..n do
        name = droid_name(x,y)
        GenServer.start_link(Rand2d, [x,y,n, is_push_sum], name: name)
        name
      end
    GenServer.cast(Master,{:droids_update,droids})
    # case imperfect do
    #   true -> randomify_mates( Enum.shuffle(droids) )
    #           "Imperfect Grid: #{inspect droids}"
    #   false -> "2D Grid: #{inspect droids}"
    # end
  end

      # NETWORK : Naming the node
  def droid_name(x,y) do
    a = x|> Integer.to_string |> String.pad_leading(4,"0")
    b = y|> Integer.to_string |> String.pad_leading(4,"0")
    "Elixir.D"<>a<>""<>b
    |>String.to_atom
  end

    # NETWORK : Defining and assigning Neighbors
  def the_chosen_one(neighbors) do
    Enum.random(neighbors)
  end

  def droid_mates(self_x,self_y,n) do   #where n is length of grid / sqrt of size of network


    mates = for x <- 1..n , y <- 1..n do

      distance = :math.sqrt(:math.pow((x-self_x),2) + :math.pow((y-self_y),2))
      #IO.puts (" #{distance} d, x #{x}, y: #{y}, self_x: #{self_x}, self_y = #{self_y} ")
      if distance <= (n/10 && distance !=0) do
        #IO.puts ("x: #{x}, y: #{y}")
        droid_name(x,y)

      end

    end
    # IO.puts Enum.at(mates,0)
    mates


    # [l,r] =
    #     case self_x do
    #       1 -> [n, 2]
    #       ^n -> [n-1, 1]
    #       _ -> [self_x-1, self_x+1]
    #     end
    # [t,b] =
    #     case self_y do
    #       1 -> [n, 2]
    #       ^n -> [n-1, 1]
    #       _ -> [self_y-1, self_y+1]
    #     end
    # [droid_name(l,self_y),droid_name(r,self_y),droid_name(t,self_x),droid_name(b,self_x)]
  end

end
