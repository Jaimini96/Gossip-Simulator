defmodule Rand2d do
  use GenServer

   # DECISION : GOSSIP vs PUSH_SUM
  def init([x,y,n, is_push_sum]) do
    neighbors = get_neighbors(x,y,n)
    case is_push_sum do
      0 -> {:ok, [Active,0, 0, n*n, x, y | neighbors] } #[ rec_count, sent_count, n, self_number_id-x,y | neighbors ]
      1 -> {:ok, [Active,0, 0, 0, 0, x, 1, n*n , x, y| neighbors] } #[ rec_count,streak,prev_s_w,to_terminate, s, w, n, self_number_id-x,y | neighbors ]
    end
  end


  # GOSSIP - RECIEVE Main
  def handle_cast({:message_gossip, _received}, [status,count,sent,size,x,y| neighbors ] = state ) do
    case count < 20 do
      true ->
        GenServer.cast(Master,{:received, [{x,y}]})
        gossip(x,y,neighbors,self())
      false ->
        GenServer.cast(Master,{:hibernated, [{x,y}]})
    end
    {:noreply,[status,count+1 ,sent,size, x , y | neighbors]}
  end

  #GOSSIP  - SEND Main
  def gossip(x,y,neighbors,pid) do
    the_one = selected_neighbor(neighbors)
    # IO.inspect the_one
    case GenServer.call(the_one,:is_active) do
      Active -> GenServer.cast(the_one, {:message_gossip, :_sending})
      inactive_xy -> GenServer.cast(Master,{:neighbors_inactive, inactive_xy})
                new_neighbor = GenServer.call(Master,:handle_node_failure)
                rerun_gossip(the_one, new_neighbor, x,y, pid)
    end
  end

  def rerun_gossip(the_one, new_neighbor, x,y, pid) do
    GenServer.cast(self(),{:remove_neighbor,the_one})
    GenServer.cast(self(),{:add_new_neighbor,new_neighbor})
    GenServer.cast(new_neighbor,{:add_new_neighbor,node_name(x,y)})
    GenServer.cast(self(),{:retry_gossip,{pid}})
  end

  def handle_cast({:remove_neighbor, node_tobe_removed}, state ) do
    new_state = List.delete(state,node_tobe_removed)
    {:noreply,new_state}
  end
  def handle_cast({:add_new_neighbor, new_node}, state) do
    {:noreply, state ++ [new_node]}
  end
  def handle_cast({:retry_gossip, {pid}}, [_status,_count,_sent,n,x,y| neighbors ] =state ) do
    gossip(x,y,neighbors,pid)
    {:noreply,state}
  end

  def rerun_pushsum(the_one, new_neighbor, x,y, s,w,pid) do
    GenServer.cast(self(),{:remove_neighbor,the_one})
    GenServer.cast(self(),{:add_new_neighbor,new_neighbor})
    GenServer.cast(new_neighbor,{:add_new_neighbor,node_name(x,y)})
    GenServer.cast(self(),{:retry_push_sum,{x,y,s,w,pid}})
  end

  def handle_cast({:retry_push_sum, {x,y,rec_s, rec_w,pid} }, [_status,_count,_streak,_prev_s_w,_term, _s ,_w, _n, x,y | neighbors ] = state ) do
    push_sum(rec_s,rec_w,neighbors,pid,x,y )
    {:noreply,state}
  end

  def handle_call(:is_active, _from, state) do
    # IO.puts "came"
    {status,x,y} =
      case state do
        [status,_count,_streak,_prev_s_w,0, _s ,_w, _n, x,y | _neighbors ] -> {status,x,y}
        [status,_count,_sent,_n,x,y | _neighbors ] -> {status,x,y}
      end
    case status == Active do
      true -> {:reply, status, state }
      false -> {:reply, [{x,y}], state }
    end
  end

  def handle_cast({:goto_sleep, _},[ status |t ] ) do
    {:noreply,[ Inactive | t]}
  end
  # PUSHSUM - RECIEVE Main
  def handle_cast({:message_push_sum, {rec_s, rec_w} }, [status,count,streak,prev_s_w,term, s ,w, n, x, y | neighbors ] = state ) do
    length = round(Float.ceil(:math.sqrt(n)))
    GenServer.cast(Master,{:received, [{x,y}]})
      case abs(((s+rec_s)/(w+rec_w))-prev_s_w) < :math.pow(10,-10) do
        false ->push_sum((s+rec_s)/2,(w+rec_w)/2,neighbors,self(),x,y)
                {:noreply,[status,count+1, 0, (s+rec_s)/(w+rec_w), term, (s+rec_s)/2, (w+rec_w)/2, n, x, y  | neighbors]}
        true ->
          case streak + 1 == 3 do
            true ->  GenServer.cast(Master,{:hibernated, [{x,y}]})
                      {:noreply,[status,count+1, streak+1, (s+rec_s)/(w+rec_w), 1, (s+rec_s), (w+rec_w), n, x, y  | neighbors]}
            false -> push_sum((s+rec_s)/2,(w+rec_w)/2,neighbors,self(),x,y)
                      {:noreply,[status,count+1, streak+1, (s+rec_s)/(w+rec_w), 0, (s+rec_s)/2, (w+rec_w)/2, n, x, y  | neighbors]}
          end
        end
  end

  # PUSHSUM  - SEND MAIN
  def push_sum(s,w,neighbors,pid ,x,y) do
    the_one = selected_neighbor(neighbors)
    case GenServer.call(the_one,:is_active) do
      Active -> GenServer.cast(the_one,{:message_push_sum,{ s,w}})
      ina_xy -> GenServer.cast(Master,{:neighbors_inactive, ina_xy})
                new_neighbor = GenServer.call(Master,:handle_node_failure)
                rerun_pushsum(the_one, new_neighbor, x,y,s,w,pid)
    end
  end

  # NETWORK : Creating Network
  def create_topology(n ,imperfect \\ false, is_push_sum \\ 0) do
    all_nodes =
      for x <- 1..n, y<- 1..n do
        name = node_name(x,y)
        GenServer.start_link(Rand2d, [x,y,n, is_push_sum], name: name)
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
  def node_name(x,y) do
    a = x|> Integer.to_string |> String.pad_leading(4,"0")
    b = y|> Integer.to_string |> String.pad_leading(4,"0")
    "Elixir.D"<>a<>""<>b
    |>String.to_atom
  end

    # NETWORK : Defining and assigning Neighbors
  def selected_neighbor(neighbors) do
    Enum.random(neighbors)
  end

  def get_neighbors(self_x,self_y,n) do   #where n is length of grid / sqrt of size of network


    neighbors = for x <- 1..n , y <- 1..n do

      distance = :math.sqrt(:math.pow((x-self_x),2) + :math.pow((y-self_y),2))
      # IO.puts (" #{distance} d, #{n/10}, x #{x}, y: #{y}, self_x: #{self_x}, self_y = #{self_y} ")
      if distance - (n/10) <= 0.0 && distance != 0.0  do
        # IO.puts ("x: #{x}, y: #{y}")
        name = node_name(x,y)
        name
      end

    end
    filtered = Enum.filter(neighbors, fn(x) -> x != nil end)
    #  IO.inspect Enum.at(filtered,1)
    if Enum.at(filtered,0) == nil do
      IO.puts "No Neighbor found"
    end
    filtered

  end

end
