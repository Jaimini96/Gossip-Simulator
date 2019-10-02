defmodule Randhoneycomb do
  use GenServer

  def getFirstNeighbor(x,elemPerRow) do
    if (x-elemPerRow) >= 1 do
      x-elemPerRow
    end
  end
  def getSecondNeighbor(x,elemPerRow, n) do
    if (x+elemPerRow) <= n do
      x+elemPerRow
    end
  end
  def getThirdNeighbor(x,elemPerRow, n)  do
    isLastElementInRow = rem(x,elemPerRow) == 0

    rowNumber = case isLastElementInRow do
      true -> round(div(x,round(elemPerRow)))-1
      false -> round(div(x,round(elemPerRow)))
    end

    remainder = rem(rowNumber,2)
    isXOdd = rem(x,2)
    neighbor  = cond do
      remainder == 0 && isXOdd == 0 && x > 1 && rem(x,elemPerRow) > 1 ->
        # IO.puts "Came"
        round(x-1)
      remainder == 0 && isXOdd == 1 && x< n ->
        round(x+1)
      remainder == 1 && isXOdd == 1 && x > 1 ->
        round(x-1)
      remainder == 1 && isXOdd == 0 && x< n ->
        round(x+1)
      x == 0 || x==n || rem(x, elemPerRow) <2->
        nil
      end

    # IO.puts neighbor
    neighbor

  end
 #
  def init([x,numberOfNodes, is_push_sum]) do
    neighbors = get_neighbors(x,numberOfNodes)
    # IO.puts Enum.at(neighbors,1)
    case is_push_sum do
      0 -> {:ok, [Active,0,0, numberOfNodes, x | neighbors] } #[ status, rec_count, sent_count, n, self_number_id | neighbors ]
      1 -> {:ok, [Active,0, 0, 0, 0, x, 1, numberOfNodes, x| neighbors] } #[status, rec_count,streak,prev_s_w,to_terminate, s, w, n, self_number_id | neighbors ]
    end
  end

    #
  def handle_cast({:message_gossip, _received}, [status,count,sent,numberOfNodes,x| neighbors ] =state ) do
    [i,j] = get_cordinates(numberOfNodes,x)
    case count < 200 do
      true ->  GenServer.cast(Master,{:received, [{i,j}]})
               gossip(x,neighbors,self(),numberOfNodes,i,j)
      false -> GenServer.cast(Master,{:hibernated, [{i,j}]})
    end
    {:noreply,[status,count+1 ,sent,numberOfNodes, x  | neighbors]}
  end

  def gossip(x,neighbors,pid, n,i,j) do
    the_one = selected_neighbor(neighbors)

    case the_one == node_name(x) do
      true -> gossip(x, neighbors, pid, n, i, j)
      false ->
        case GenServer.call(the_one,:is_active) do
          Active -> GenServer.cast(the_one, {:message_gossip, :_sending})
          inactive_xy -> GenServer.cast(Master,{:neighbors_inactive, inactive_xy})
                    new_neighbor = GenServer.call(Master,:handle_node_failure)
                    rerun_gossip(the_one, new_neighbor, x, pid, i,j)
        end
    end

  end
  def rerun_gossip(the_one, new_neighbor, x, pid, i,j) do
    GenServer.cast(self(),{:remove_neighbor,the_one})
    GenServer.cast(self(),{:add_new_neighbor,new_neighbor})
    GenServer.cast(new_neighbor,{:add_new_neighbor,node_name(x)})
    GenServer.cast(self(),{:retry_gossip,{pid,i,j}})
  end

  def handle_cast({:remove_neighbor, node_tobe_removed}, state ) do
    new_state = List.delete(state,node_tobe_removed)
    {:noreply,new_state}
  end
  def handle_cast({:add_new_neighbor, new_node}, state) do
    {:noreply, state ++ [new_node]}
  end
  def handle_cast({:retry_gossip, {pid,i,j}}, [_status,_count,_sent,n,x| neighbors ] =state ) do
    gossip(x,neighbors,pid, n,i,j)
    {:noreply,state}
  end

  def rerun_pushsum(the_one, new_neighbor, x, s,w,pid, i,j) do
    GenServer.cast(self(),{:remove_neighbor,the_one})
    GenServer.cast(self(),{:add_new_neighbor,new_neighbor})
    GenServer.cast(new_neighbor,{:add_new_neighbor,node_name(x)})
    GenServer.cast(self(),{:retry_push_sum,{x,s,w,pid,i,j}})
  end

  def handle_cast({:retry_push_sum, {x,rec_s, rec_w,pid,i,j} }, [_status,_count,_streak,_prev_s_w,_term, _s ,_w, _n, x | neighbors ] = state ) do
    push_sum(x,rec_s,rec_w,neighbors,pid ,i,j)
    {:noreply,state}
  end

  def handle_call(:is_active , _from, state) do
    {status,n,x} =
      case state do
        [status,_count,_streak,_prev_s_w,0, _s ,_w, n, x | _neighbors ] -> {status,n,x}
        [status,_count,_sent,n,x| _neighbors ] -> {status,n,x}
      end
    case status == Active do
      true -> {:reply, status, state }
      false ->
        [i,j] = get_cordinates(n, x)
        {:reply, [{i,j}], state }
    end
  end

  def handle_cast({:goto_sleep, _},[ status |t ] ) do
    {:noreply,[ Inactive | t]}
  end

        #
  def handle_cast({:message_push_sum, {rec_s, rec_w} }, [status,count,streak,prev_s_w,term, s ,w, n, x | neighbors ] = state ) do
    length = round(Float.ceil(:math.sqrt(n)))
    i = rem(x-1,length) + 1
    j = round(Float.floor(((x-1)/length))) + 1
    GenServer.cast(Master,{:received, [{i,j}]})
      case abs(((s+rec_s)/(w+rec_w))-prev_s_w) < :math.pow(10,-10) do
        false ->push_sum(x,(s+rec_s)/2,(w+rec_w)/2,neighbors,self(),i,j)
                {:noreply,[status,count+1, 0, (s+rec_s)/(w+rec_w), term, (s+rec_s)/2, (w+rec_w)/2, n, x  | neighbors]}
        true ->
          case streak + 1 == 3 do
            true ->  GenServer.cast(Master,{:hibernated, [{i,j}]})
                      {:noreply,[status,count+1, streak+1, (s+rec_s)/(w+rec_w), 1, (s+rec_s), (w+rec_w), n, x  | neighbors]}
            false -> push_sum(x,(s+rec_s)/2, (w+rec_w)/2, neighbors, self(), i, j)
                      {:noreply,[status,count+1, streak+1, (s+rec_s)/(w+rec_w), 0, (s+rec_s)/2, (w+rec_w)/2, n, x  | neighbors]}
          end
      end
  end

  def push_sum(x,s,w,neighbors,pid ,i,j) do
    the_one = selected_neighbor(neighbors)
    case the_one == node_name(x) do
      true -> push_sum(x, s, w, neighbors, pid, i, j)
      false ->
        case GenServer.call(the_one,:is_active) do
          Active -> GenServer.cast(the_one, {:message_push_sum, {s,w}})
          inactive_xy -> GenServer.cast(Master,{:neighbors_inactive, inactive_xy})
                    new_neighbor = GenServer.call(Master,:handle_node_failure)
                    rerun_pushsum(the_one, new_neighbor, x, s, w, pid, i, j)
        end
    end
  end

  def get_cordinates(numberOfNodes,x) do
    length = round(Float.ceil(:math.sqrt(numberOfNodes)))
    i = rem(x-1,length) + 1
    j = round(Float.floor(((x-1)/length))) + 1
    [i,j]
  end

  def get_neighbors(self,n) do
    elementsPerRow = round(:math.sqrt(n))
    neighbors =[:rand.uniform(n),getFirstNeighbor(self,elementsPerRow),getSecondNeighbor(self,elementsPerRow,n), getThirdNeighbor(self,elementsPerRow,n)]
    filteredNeighbors = Enum.filter(neighbors, fn(x) -> x != nil end)
    # IO.puts filteredNeighbors
    neighborIds = Enum.map(filteredNeighbors, fn(x) -> node_name(x) end)
    # IO.inspect Enum.at(neighbors,0)
    neighborIds

  end



  def create_topology(numberOfNodes, is_push_sum \\ 0) do
    all_nodes =
      for x <- 1..numberOfNodes do
        name = node_name(x)
        GenServer.start_link(Randhoneycomb, [x,numberOfNodes, is_push_sum], name: name)
        name
      end
    GenServer.cast(Master,{:all_nodes_update,all_nodes})
  end

  def node_name(x) do
    a = x|> Integer.to_string |> String.pad_leading(7,"0")
    "Elixir.D"<>a
    |>String.to_atom
  end

  def selected_neighbor(neighbors) do
    Enum.random(neighbors)
  end

end
