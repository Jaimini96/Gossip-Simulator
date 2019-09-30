defmodule Torus3d do

  use GenServer

    # DECISION : GOSSIP vs PUSH_SUM
  def init([x,y,z, n, is_push_sum]) do
    mates = droid_mates(x,y,z,n)
    case is_push_sum do
      0 -> {:ok, [Active,0, 0, n*n, x, y, z | mates] } #[ rec_count, sent_count, n, self_number_id-x,y | neighbors ]
      1 -> {:ok, [Active,0, 0, 0, 0, x, 1, n*n , x, y, z| mates] } #[ rec_count,streak,prev_s_w,to_terminate, s, w, n, self_number_id-x,y | neighbors ]
    end
  end




  # GOSSIP - RECIEVE Main
  def handle_cast({:message_gossip, _received}, [status,count,sent,size,x,y,z| mates ] = state ) do
    case count < 100 do
      true ->
        GenServer.cast(Master,{:received, [{x,y,z}]})
        gossip(x,y,z,mates,self())
      false ->
        GenServer.cast(Master,{:hibernated, [{x,y,z}]})
    end
    {:noreply,[status,count+1 ,sent,size, x , y, z | mates]}
  end

    #GOSSIP  - SEND Main
  def gossip(x,y,z,mates,pid) do
    the_one = the_chosen_one(mates)
    # IO.puts ("xyz:#{x},#{y},#{z}  one: #{the_one}")
    # IP.puts mates
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
      for x <- 1..n, y<- 1..n, z<- 1..n do
        name = droid_name(x,y,z)
        GenServer.start_link(Torus3d, [x,y,z,n, is_push_sum], name: name)
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
  def droid_name(x,y,z) do
    a = x|> Integer.to_string |> String.pad_leading(4,"0")
    b = y|> Integer.to_string |> String.pad_leading(4,"0")
    c = z|> Integer.to_string |> String.pad_leading(4,"0")
    "Elixir.D"<>a<>""<>b<>""<>c
    |>String.to_atom
  end

    # NETWORK : Defining and assigning Neighbors
  def the_chosen_one(neighbors) do
    Enum.random(neighbors)
  end

  # NETWORK : Choosing a neigbor randomly to send message to
  def droid_mates(self_x,self_y,self_z,n) do   #where n is length of grid / cuberoot of size of network
    [left,right] =
        case self_x do
          1 -> [n, 2]
          ^n -> [n-1, 1]
          _ -> [self_x-1, self_x+1]
        end
    [top,bottom] =
        case self_y do
          1 -> [n, 2]
          ^n -> [n-1, 1]
          _ -> [self_y-1, self_y+1]
        end
    [front,back] =
        case self_z do
          1 -> [n, 2]
          ^n -> [n-1, 1]
          _ -> [self_z-1, self_z+1]
        end
    [droid_name(left,self_y,self_z),droid_name(right,self_y,self_z),droid_name(self_x,top,self_z),droid_name(self_x,bottom,self_z),droid_name(self_x,self_y,front),droid_name(self_x,self_y,back)]
  end
end
