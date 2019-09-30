defmodule Torus3d do

  use GenServer

    # DECISION : GOSSIP vs PUSH_SUM
  def init([x,y,z, n, is_push_sum]) do
    neighbors = get_neighbors(x,y,z,n)
    case is_push_sum do
      0 -> {:ok, [Active,0, 0, n*n, x, y, z | neighbors] } #[ rec_count, sent_count, n, self_number_id-x,y | neighbors ]
      1 -> {:ok, [Active,0, 0, 0, 0, x, 1, n*n , x, y, z| neighbors] } #[ rec_count,streak,prev_s_w,to_terminate, s, w, n, self_number_id-x,y | neighbors ]
    end
  end




  # GOSSIP - RECIEVE Main
  def handle_cast({:message_gossip, _received}, [status,count,sent,size,x,y,z| neighbors ] = state ) do
    case count < 100 do
      true ->
        GenServer.cast(Master,{:received, [{x,y,z}]})
        gossip(x,y,z,neighbors,self())
      false ->
        GenServer.cast(Master,{:hibernated, [{x,y,z}]})
    end
    {:noreply,[status,count+1 ,sent,size, x , y, z | neighbors]}
  end

    #GOSSIP  - SEND Main
  def gossip(x,y,z,neighbors,pid) do
    the_one = selected_neighbor(neighbors)
    # IO.puts ("xyz:#{x},#{y},#{z}  one: #{the_one}")
    # IP.puts neighbors
    GenServer.cast(the_one, {:message_gossip, :_sending})
    # case GenServer.call(the_one,:is_active) do
    #   Active -> GenServer.cast(the_one, {:message_gossip, :_sending})
    #   ina_xy -> GenServer.cast(Master,{:neighbors_inactive, ina_xy})
    #             new_neighbor = GenServer.call(Master,:handle_node_failure)
    #             GenServer.cast(self(),{:remove_neighbor,the_one})
    #             GenServer.cast(self(),{:add_new_neighbor,new_neighbor})
    #             GenServer.cast(new_neighbor,{:add_new_neighbor,node_name(x,y)})
    #             GenServer.cast(self(),{:retry_gossip,{pid}})
    # end
  end

    # PUSHSUM - RECIEVE Main
  def handle_cast({:message_push_sum, {rec_s, rec_w} }, [status,count,streak,prev_s_w,term, s ,w, n, x, y,z | neighbors ] = state ) do
    # length = round(Float.ceil(:math.sqrt(n)))
    GenServer.cast(Master,{:received, [{x,y, z}]})
      case abs(((s+rec_s)/(w+rec_w))-prev_s_w) < :math.pow(10,-10) do
        false ->push_sum((s+rec_s)/2,(w+rec_w)/2,neighbors,self(),x,y,z)
                {:noreply,[status,count+1, 0, (s+rec_s)/(w+rec_w), term, (s+rec_s)/2, (w+rec_w)/2, n, x, y, z  | neighbors]}
        true ->
          case streak + 1 == 3 do
            true ->  GenServer.cast(Master,{:hibernated, [{x,y}]})
                      {:noreply,[status,count+1, streak+1, (s+rec_s)/(w+rec_w), 1, (s+rec_s), (w+rec_w), n, x, y,z   | neighbors]}
            false -> push_sum((s+rec_s)/2,(w+rec_w)/2,neighbors,self(),x,y,z)
                      {:noreply,[status,count+1, streak+1, (s+rec_s)/(w+rec_w), 0, (s+rec_s)/2, (w+rec_w)/2, n, x, y , z | neighbors]}
          end
        end
  end

  # PUSHSUM  - SEND MAIN
  def push_sum(s,w,neighbors,pid ,x,y,z) do
    the_one = selected_neighbor(neighbors)
    GenServer.cast(the_one,{:message_push_sum,{ s,w}})
    # case GenServer.call(the_one,:is_active) do
    #   Active -> GenServer.cast(the_one,{:message_push_sum,{ s,w}})
    #   ina_xy -> GenServer.cast(Master,{:node_inactive, ina_xy})
    #               new_neighbor = GenServer.call(Master,:handle_node_failure)
    #               GenServer.cast(self(),{:remove_neighbor,the_one})
    #               GenServer.cast(self(),{:add_new_neighbor,new_neighbor})
    #               GenServer.cast(new_neighbor,{:add_new_neighbor,node_name(x,y)})
    #               GenServer.cast(self(),{:retry_push_sum,{s,w,pid}})
    # end
  end

    # NETWORK : Creating Network
  def create_topology(n ,imperfect \\ false, is_push_sum \\ 0) do
    all_nodes =
      for x <- 1..n, y<- 1..n, z<- 1..n do
        name = node_name(x,y,z)
        GenServer.start_link(Torus3d, [x,y,z,n, is_push_sum], name: name)
        name
      end
    GenServer.cast(Master,{:all_nodes_update,all_nodes})
    # case imperfect do
    #   true -> randomify_neighbors( Enum.shuffle(all_nodes) )
    #           "Imperfect Grid: #{inspect all_nodes}"
    #   false -> "2D Grid: #{inspect all_nodes}"
    # end
  end

  # NETWORK : Naming the node
  def node_name(x,y,z) do
    a = x|> Integer.to_string |> String.pad_leading(4,"0")
    b = y|> Integer.to_string |> String.pad_leading(4,"0")
    c = z|> Integer.to_string |> String.pad_leading(4,"0")
    "Elixir.D"<>a<>""<>b<>""<>c
    |>String.to_atom
  end

    # NETWORK : Defining and assigning Neighbors
  def selected_neighbor(neighbors) do
    Enum.random(neighbors)
  end

  # NETWORK : Choosing a neigbor randomly to send message to
  def get_neighbors(self_x,self_y,self_z,n) do   #where n is length of grid / cuberoot of size of network
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
    [node_name(left,self_y,self_z),node_name(right,self_y,self_z),node_name(self_x,top,self_z),node_name(self_x,bottom,self_z),node_name(self_x,self_y,front),node_name(self_x,self_y,back)]
  end
end
